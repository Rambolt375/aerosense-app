import 'dart:async';
import 'dart:math' as math;

import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_diurnal_generator.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';

/// Active simulation scenario for Demo Mode.
enum DemoScenario { none, smoke, heat }

/// Fake [SystemRepository] simulating the ESP32 firmware for Demo Mode.
///
/// Features:
/// - Computes ventilation tier using [Thresholds] directly.
/// - Fan forced ON in Danger tier (safety override).
/// - Honors `manualToggle` in Safe and Medium tiers.
/// - Baseline follows [generateDiurnalSample] at the current [clock] time,
///   ensuring live demo readings match the historical training distribution
///   and prevent persistent residual gate lockout.
/// - Scripted smoke/heat scenarios layered on top of the diurnal baseline.
/// - Emits exact firmware strings from PRD Table III and DATA_SAMPLE.json.
/// - In raw snapshot: omits `manualToggle` until first write, omits `lastSeen`.
/// - Fully testable with injected [tickInterval], [random], and [clock].
class FakeSystemRepository implements SystemRepository {
  FakeSystemRepository({
    this.tickInterval = const Duration(seconds: 2),
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

  // Real firmware status strings from PRD Table III and DATA_SAMPLE.json
  static const String statusSafeIdle = 'System Safe';
  static const String statusSafeManual = 'SAFE: Fan manually overridden ON.';
  static const String statusMediumIdle =
      'MEDIUM: Environment is stuffy. Manual toggle available.';
  static const String statusMediumManual =
      'MEDIUM: Fan manually turned ON by user.';
  static const String statusDanger =
      'DANGER: High thresholds breached! Auto-fan activated.';

  // --- Injected dependencies ---
  final Duration tickInterval;
  final math.Random _random;
  final DateTime Function() _clock;

  /// Injected clock for testing.
  DateTime Function() get clock => _clock;

  // --- Simulated state ---
  late double _temperature;
  late double _humidity;
  late double _airQuality;
  bool? _manualToggle; // Omitted in raw JSON until first write
  bool _fanOn = false;
  String _statusMessage = statusSafeIdle;

  // --- Scenario state ---
  DemoScenario _scenario = DemoScenario.none;
  int _scenarioStep = 0;
  bool _heatRampingUp = true;

  // --- Stream controllers ---
  late final StreamController<SystemState> _stateController;
  late final StreamController<Object?> _rawController;
  Timer? _tickerTimer;
  int _listenerCount = 0;
  bool _isDisposed = false;

  /// Whether an active timer is currently running.
  bool get hasActiveTimers => _tickerTimer?.isActive ?? false;

  /// The active scenario.
  DemoScenario get currentScenario => _scenario;

  // Current values (for testing and assertions)
  double get currentTemperature => _temperature;
  double get currentHumidity => _humidity;
  double get currentAirQuality => _airQuality;
  bool? get rawManualToggle => _manualToggle;
  bool get currentFanOn => _fanOn;
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

    final manualActive = _manualToggle ?? false;

    switch (_tier) {
      case Tier.danger:
        _fanOn = true; // Firm safety rule: fan forced ON
        _statusMessage = statusDanger;
        break;
      case Tier.medium:
        _fanOn = manualActive;
        _statusMessage = manualActive ? statusMediumManual : statusMediumIdle;
        break;
      case Tier.safe:
        _fanOn = manualActive;
        _statusMessage = manualActive ? statusSafeManual : statusSafeIdle;
        break;
    }
  }

  void _emitCurrentState() {
    if (_isDisposed) return;

    if (_stateController.hasListener) {
      _stateController.add(
        SystemState(
          temperature: double.parse(_temperature.toStringAsFixed(1)),
          humidity: double.parse(_humidity.toStringAsFixed(1)),
          airQuality: double.parse(_airQuality.toStringAsFixed(0)),
          fanOn: _fanOn,
          manualToggle: _manualToggle ?? false,
          statusMessage: _statusMessage,
          tier: _tier,
        ),
      );
    }

    if (_rawController.hasListener) {
      final raw = <String, dynamic>{
        'temperature': double.parse(_temperature.toStringAsFixed(1)),
        'humidity': double.parse(_humidity.toStringAsFixed(1)),
        'airQuality': _airQuality.round(),
        'fanStatus': _fanOn ? 'ON' : 'OFF',
        'statusMessage': _statusMessage,
      };
      if (_manualToggle != null) {
        raw['manualToggle'] = _manualToggle!;
      }
      _rawController.add(raw);
    }
  }

  void _onTick() {
    if (_isDisposed) return;

    switch (_scenario) {
      case DemoScenario.smoke:
        _stepSmokeScenario();
        break;
      case DemoScenario.heat:
        _stepHeatScenario();
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
    // Hold Danger tier (> 2000) for 3 ticks
    if (_scenarioStep <= 3) {
      _airQuality = 2350.0;
    }
    // Step down to Medium (1850) for 3 ticks
    else if (_scenarioStep <= 6) {
      _airQuality = 1850.0;
    }
    // Step down to Medium (1200) for 3 ticks
    else if (_scenarioStep <= 9) {
      _airQuality = 1200.0;
    }
    // Recover to diurnal baseline
    else {
      final sample = generateDiurnalSample(
        _clock(),
        random: _random,
        addNoise: true,
      );
      _airQuality = sample.airQuality;
      _scenario = DemoScenario.none;
      _scenarioStep = 0;
    }
  }

  void _stepHeatScenario() {
    if (_heatRampingUp) {
      // Ramp +0.5 C per tick up to ~33 C
      _temperature += 0.5;
      if (_temperature >= 33.0) {
        _temperature = 33.0;
        _heatRampingUp = false;
        _scenarioStep = 0; // Hold counter
      }
    } else if (_scenarioStep < 3) {
      // Hold briefly at 33 C for 3 ticks
      _scenarioStep++;
    } else {
      // Recover: ramp down -0.5 C per tick to diurnal baseline
      final baseline = generateDiurnalSample(
        _clock(),
        random: _random,
        addNoise: false,
      ).temperature;
      _temperature -= 0.5;
      if (_temperature <= baseline) {
        _temperature = baseline;
        _scenario = DemoScenario.none;
        _scenarioStep = 0;
        _heatRampingUp = true;
      }
    }
  }

  // --- Simulation Triggers ---

  /// Simulates a kitchen-smoke event: immediate spike of air quality to Danger
  /// (> 2000), holding briefly, then recovering through Medium to Safe.
  void simulateKitchenSmoke() {
    _scenario = DemoScenario.smoke;
    _scenarioStep = 0;
    _airQuality = 2350.0;
    _recomputeState();
    _emitCurrentState();
  }

  /// Simulates a heat spike: ramps temperature +0.5 C per tick up to ~33 C,
  /// enters Danger tier (> 32 C), holds briefly, then recovers.
  void simulateHeatSpike() {
    _scenario = DemoScenario.heat;
    _scenarioStep = 0;
    _heatRampingUp = true;
    _temperature += 0.5;
    _recomputeState();
    _emitCurrentState();
  }

  /// Resets simulated sensor telemetry back to clean diurnal baselines.
  void resetToBaseline() {
    _scenario = DemoScenario.none;
    _scenarioStep = 0;
    _heatRampingUp = true;
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
    // Deliver initial state immediately on listen
    scheduleMicrotask(_emitCurrentState);
    return _stateController.stream;
  }

  @override
  Stream<Object?> watchRawSystem() {
    scheduleMicrotask(_emitCurrentState);
    return _rawController.stream;
  }

  @override
  Future<void> setManualToggle(bool value) async {
    _manualToggle = value;
    _recomputeState();
    _emitCurrentState();
  }

  @override
  Stream<bool> watchConnected() => Stream.value(true);

  /// Disposes resources, cancels timers, and closes stream controllers.
  void dispose() {
    _isDisposed = true;
    _stopTicker();
    _stateController.close();
    _rawController.close();
  }
}
