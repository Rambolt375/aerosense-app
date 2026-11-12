import 'dart:async';
import 'dart:math' as math;

import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_diurnal_generator.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';

/// Active simulation scenario for Demo Mode.
enum DemoScenario { none, smoke, heat, sensorUnplugged }

/// Fake [SystemRepository] simulating the ESP32 firmware for Demo Mode.
///
/// Features (Phase 6a firmware alignment):
/// - Emits only bare keywords SAFE / CAUTION / DANGER as statusMessage.
/// - manualToggle works ONLY in CAUTION (Medium). Rejects requests in Safe or Danger.
/// - Fixed-length run (default 5 min; persistent against false writes).
/// - Resets manualToggle to false when the run ends.
/// - If tier becomes DANGER, active run is cancelled, fan stays latched ON through Caution until Safe.
/// - Publishes manualEndsAt (epoch seconds UTC) and /config/manualDurationSec as planned firmware contract.
// TODO(confirm): manualEndsAt and /config/manualDurationSec confirmed as planned firmware fields; app works with or without them.
class FakeSystemRepository implements SystemRepository {
  FakeSystemRepository({
    this.tickInterval = const Duration(seconds: 2),
    this.autoResetDuration = AppConfig.defaultManualDuration,
    this.publishManualEndsAt = true,
    this.publishConfig = true,
    this.manualDurationSec = AppConfig.defaultManualDurationSec,
    math.Random? random,
    DateTime Function()? clock,
    double? initialTemperature,
    double? initialHumidity,
    double? initialAirQuality,
  }) : _random = random ?? math.Random(),
       _clock = clock ?? DateTime.now {
    final initialSample = generateDiurnalSample(
      _clock(),
      random: _random,
      addNoise: false,
    );
    _temperature = initialTemperature ?? initialSample.temperature;
    _humidity = initialHumidity ?? initialSample.humidity;
    _airQuality = initialAirQuality ?? initialSample.airQuality;
    _initControllers();
    _recomputeState();
  }

  // --- Constants & Baselines ---
  static const double baselineTemp = 24.5;
  static const double baselineHumidity = 48.0;
  static const double baselineAirQuality = 650.0;

  /// Current diurnal baseline temperature at the current [clock] time.
  double get currentBaselineTemp => generateDiurnalSample(
    _clock(),
    random: _random,
    addNoise: false,
  ).temperature;

  /// Current diurnal baseline air quality at the current [clock] time.
  double get currentBaselineAirQuality => generateDiurnalSample(
    _clock(),
    random: _random,
    addNoise: false,
  ).airQuality;

  // Real firmware status strings: bare keywords per confirmed contract
  static const String statusSafe = 'SAFE';
  static const String statusCaution = 'CAUTION';
  static const String statusDanger = 'DANGER';

  // --- Injected dependencies & planned contract flags ---
  final Duration tickInterval;
  final Duration autoResetDuration;
  final bool publishManualEndsAt;
  final bool publishConfig;
  final int manualDurationSec;
  final math.Random _random;
  final DateTime Function() _clock;

  /// Injected clock for testing.
  DateTime Function() get clock => _clock;

  // --- Simulated state ---
  double? _temperature;
  double? _humidity;
  late double _airQuality;
  bool? _manualToggle; // Omitted in raw JSON until first request
  DateTime? _manualToggleExpiresAt;
  DateTime? _manualEndsAt;
  Timer? _autoResetTimer;
  bool _fanOn = false;
  bool _dangerLatched = false;
  String _statusMessage = statusSafe;

  // --- Scenario state ---
  DemoScenario _scenario = DemoScenario.none;
  int _scenarioStep = 0;
  bool _heatRampingUp = true;

  // --- Stream controllers ---
  late final StreamController<SystemState> _stateController;
  late final StreamController<Object?> _rawController;
  late final StreamController<Map<String, dynamic>?> _configController;
  Timer? _tickerTimer;
  int _listenerCount = 0;
  bool _isDisposed = false;

  /// Whether an active timer is currently running.
  bool get hasActiveTimers => _tickerTimer?.isActive ?? false;

  /// The active scenario.
  DemoScenario get currentScenario => _scenario;

  // Current values (for testing and assertions)
  double? get currentTemperature => _temperature;
  double? get currentHumidity => _humidity;
  double get currentAirQuality => _airQuality;
  bool? get rawManualToggle => _manualToggle;
  DateTime? get currentManualEndsAt => _manualEndsAt;
  bool get currentFanOn => _fanOn;
  bool get currentDangerLatched => _dangerLatched;
  String get currentStatusMessage => _statusMessage;
  Tier get currentTier => _tier;

  void _initControllers() {
    _stateController = StreamController<SystemState>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
    _rawController = StreamController<Object?>.broadcast(
      onListen: _onListen,
      onCancel: _onCancel,
    );
    _configController = StreamController<Map<String, dynamic>?>.broadcast();
  }

  void _onListen() {
    _listenerCount++;
    if (_listenerCount == 1 && !_isDisposed) {
      _startTicker();
    }
  }

  void _onCancel() {
    _listenerCount--;
    if (_listenerCount <= 0) {
      _listenerCount = 0;
      _stopTicker();
    }
  }

  void _startTicker() {
    if (_isDisposed || _tickerTimer != null) return;
    _tickerTimer = Timer.periodic(tickInterval, (_) => _onTick());
  }

  void _stopTicker() {
    _tickerTimer?.cancel();
    _tickerTimer = null;
  }

  Tier _tier = Tier.safe;

  void _recomputeState() {
    _tier = Tier.fromValues(
      temperature: _temperature,
      humidity: _humidity,
      airQuality: _airQuality,
    );

    // Safety rule: if tier reaches Danger, cancel active run and latch the fan ON
    if (_tier == Tier.danger) {
      _dangerLatched = true;
      _manualToggle = false;
      _manualToggleExpiresAt = null;
      _manualEndsAt = null;
      _autoResetTimer?.cancel();
      _autoResetTimer = null;
    } else if (_tier == Tier.safe) {
      // Danger latch clears strictly when room returns all the way to Safe
      _dangerLatched = false;
    }

    switch (_tier) {
      case Tier.danger:
        _fanOn = true;
        _statusMessage = statusDanger;
        break;
      case Tier.medium:
        if (_dangerLatched) {
          _fanOn = true;
        } else {
          _fanOn = _manualToggle ?? false;
        }
        _statusMessage = statusCaution;
        break;
      case Tier.safe:
        _fanOn = false;
        _statusMessage = statusSafe;
        break;
    }
  }

  void _emitCurrentState() {
    if (_isDisposed) return;

    if (_stateController.hasListener) {
      _stateController.add(
        SystemState(
          temperature: _temperature != null
              ? double.parse(_temperature!.toStringAsFixed(1))
              : null,
          humidity: _humidity != null
              ? double.parse(_humidity!.toStringAsFixed(1))
              : null,
          airQuality: double.parse(_airQuality.toStringAsFixed(0)),
          fanOn: _fanOn,
          manualToggle: _manualToggle ?? false,
          statusMessage: _statusMessage,
          tier: _tier,
          manualEndsAt: _manualEndsAt,
        ),
      );
    }

    if (_rawController.hasListener) {
      final raw = <String, dynamic>{
        'temperature': _temperature != null
            ? double.parse(_temperature!.toStringAsFixed(1))
            : null,
        'humidity': _humidity != null
            ? double.parse(_humidity!.toStringAsFixed(1))
            : null,
        'airQuality': _airQuality.round(),
        'fanStatus': _fanOn ? 'ON' : 'OFF',
        'statusMessage': _statusMessage,
      };
      if (_manualToggle != null) {
        raw['manualToggle'] = _manualToggle!;
      }
      if (_manualEndsAt != null) {
        // Output epoch seconds UTC per planned firmware contract
        raw['manualEndsAt'] =
            _manualEndsAt!.toUtc().millisecondsSinceEpoch ~/ 1000;
      }
      _rawController.add(raw);
    }
  }

  void _emitConfig() {
    if (_isDisposed) return;
    if (publishConfig) {
      _configController.add({'manualDurationSec': manualDurationSec});
    } else {
      _configController.add(null);
    }
  }

  /// Visible for testing: manually trigger a simulation tick.
  void onTickForTesting() => _onTick();

  void _onTick() {
    if (_isDisposed) return;

    // Check manual toggle timed auto-reset
    if (_manualToggle == true &&
        _manualToggleExpiresAt != null &&
        !_clock().isBefore(_manualToggleExpiresAt!)) {
      _manualToggle = false;
      _manualToggleExpiresAt = null;
      _manualEndsAt = null;
    }

    switch (_scenario) {
      case DemoScenario.smoke:
        _stepSmokeScenario();
        break;
      case DemoScenario.heat:
        _stepHeatScenario();
        break;
      case DemoScenario.sensorUnplugged:
        _stepSensorUnpluggedScenario();
        break;
      case DemoScenario.none:
        _stepDrift();
        break;
    }

    _recomputeState();
    _emitCurrentState();
  }

  void _stepDrift() {
    final sample = generateDiurnalSample(
      _clock(),
      random: _random,
      addNoise: true,
    );
    _temperature = sample.temperature;
    _humidity = sample.humidity;
    _airQuality = sample.airQuality;
  }

  void _stepSmokeScenario() {
    _scenarioStep++;
    // Hold Danger tier (>= airQualityDangerMin) for 3 ticks
    if (_scenarioStep <= 3) {
      _airQuality = Thresholds.airQualityDangerMin + 350.0;
    }
    // Step down to Medium (Caution) for 3 ticks (fan remains latched ON!)
    else if (_scenarioStep <= 6) {
      _airQuality = Thresholds.airQualityCautionMin + 450.0;
    }
    // Step down to lower Medium for 3 ticks (fan remains latched ON!)
    else if (_scenarioStep <= 9) {
      _airQuality = Thresholds.airQualityCautionMin + 50.0;
    }
    // Recover to diurnal baseline (< airQualityRecovery): Safe tier clears latch!
    else {
      final sample = generateDiurnalSample(
        _clock(),
        random: _random,
        addNoise: true,
      );
      _airQuality = math.min(
        sample.airQuality,
        Thresholds.airQualityRecovery - 50.0,
      );
      _scenario = DemoScenario.none;
      _scenarioStep = 0;
    }
  }

  void _stepHeatScenario() {
    final dangerTarget = Thresholds.tempDangerMin + 0.5;

    if (_heatRampingUp) {
      // Ramp +0.5 C per tick up through Caution into Danger tier
      _temperature = (_temperature ?? (Thresholds.tempSafeMax - 1.0)) + 0.5;
      if (_temperature! >= dangerTarget) {
        _temperature = dangerTarget;
        _heatRampingUp = false;
        _scenarioStep = 0; // Hold counter
      }
    } else if (_scenarioStep < 3) {
      // Hold briefly at Danger target for 3 ticks
      _scenarioStep++;
    } else {
      // Recover: ramp down -0.5 C per tick to diurnal baseline
      final baseline = generateDiurnalSample(
        _clock(),
        random: _random,
        addNoise: false,
      );
      final target = baseline.temperature;
      if (_temperature! > target) {
        _temperature = _temperature! - 0.5;
      } else {
        _temperature = target;
        _scenario = DemoScenario.none;
        _scenarioStep = 0;
        _heatRampingUp = true;
      }
    }
  }

  void _stepSensorUnpluggedScenario() {
    _scenarioStep++;
    if (_scenarioStep <= 5) {
      _temperature = null;
      _humidity = null;
    } else {
      final sample = generateDiurnalSample(
        _clock(),
        random: _random,
        addNoise: false,
      );
      _temperature = sample.temperature;
      _humidity = sample.humidity;
      _scenario = DemoScenario.none;
      _scenarioStep = 0;
    }
  }

  // --- Simulation Triggers ---

  /// Simulates a kitchen-smoke event: immediate spike of air quality to Danger
  /// (>= airQualityDangerMin), holding briefly, then recovering through Medium (latched) to Safe.
  void simulateKitchenSmoke() {
    _scenario = DemoScenario.smoke;
    _scenarioStep = 0;
    _airQuality = Thresholds.airQualityDangerMin + 350.0;
    _recomputeState();
    _emitCurrentState();
  }

  /// Simulates a heat spike: ramps temperature +0.5 C per tick up through Caution
  /// into Danger tier, holds briefly, then recovers through Caution (latched) to Safe.
  void simulateHeatSpike() {
    _scenario = DemoScenario.heat;
    _scenarioStep = 0;
    _heatRampingUp = true;
    _stepHeatScenario();
    _recomputeState();
    _emitCurrentState();
  }

  /// Simulates unplugging the DHT22 sensor: nulls temperature and humidity for
  /// several ticks, rendering "--" in the UI, then cleanly recovers back to diurnal baseline.
  void simulateSensorUnplugged() {
    _scenario = DemoScenario.sensorUnplugged;
    _scenarioStep = 0;
    _temperature = null;
    _humidity = null;
    _recomputeState();
    _emitCurrentState();
  }

  /// Resets simulated sensor telemetry back to clean diurnal baselines.
  void resetToBaseline() {
    _scenario = DemoScenario.none;
    _scenarioStep = 0;
    _heatRampingUp = true;
    _dangerLatched = false;
    _manualToggle = false;
    _manualEndsAt = null;
    _manualToggleExpiresAt = null;
    _autoResetTimer?.cancel();
    _autoResetTimer = null;
    final sample = generateDiurnalSample(
      _clock(),
      random: _random,
      addNoise: false,
    );
    _temperature = sample.temperature;
    _humidity = sample.humidity;
    _airQuality = sample.airQuality;
    _recomputeState();
    _emitCurrentState();
  }

  // --- SystemRepository overrides ---

  @override
  Stream<SystemState> watchSystemState() {
    scheduleMicrotask(_emitCurrentState);
    return _stateController.stream;
  }

  @override
  Stream<Object?> watchRawSystem() {
    scheduleMicrotask(_emitCurrentState);
    return _rawController.stream;
  }

  @override
  Stream<Map<String, dynamic>?> watchConfig() {
    scheduleMicrotask(_emitConfig);
    return _configController.stream;
  }

  @override
  Future<void> requestManualVentilation() async {
    // Firmware rejection: manualToggle works ONLY in Caution (Medium)
    if (_tier != Tier.medium) {
      _manualToggle = false;
      _manualToggleExpiresAt = null;
      _manualEndsAt = null;
      _recomputeState();
      _emitCurrentState();
      return;
    }

    _manualToggle = true;
    _manualToggleExpiresAt = _clock().add(autoResetDuration);
    _manualEndsAt = publishManualEndsAt ? _manualToggleExpiresAt : null;
    _autoResetTimer?.cancel();
    _autoResetTimer = Timer(autoResetDuration, () {
      if (_manualToggle == true && !_isDisposed) {
        _manualToggle = false;
        _manualToggleExpiresAt = null;
        _manualEndsAt = null;
        _recomputeState();
        _emitCurrentState();
      }
    });
    _recomputeState();
    _emitCurrentState();
  }

  /// Defensive implementation for backward compatibility and tests.
  ///
  /// Per confirmed firmware behavior, manual run is persistent against `false`:
  /// writing false will never cancel an active run.
  Future<void> setManualToggle(bool value) async {
    if (!value) {
      // Persistent against false: writing false will NOT stop it
      return;
    }
    return requestManualVentilation();
  }

  @override
  Stream<bool> watchConnected() => Stream.value(true);

  /// Disposes resources, cancels timers, and closes stream controllers.
  void dispose() {
    _isDisposed = true;
    _stopTicker();
    _autoResetTimer?.cancel();
    _stateController.close();
    _rawController.close();
    _configController.close();
  }
}
