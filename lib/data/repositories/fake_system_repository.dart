import 'dart:async';
import 'dart:math' as math;

import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';

/// Active simulation scenario for Demo Mode.
enum DemoScenario { none, smoke, heat }

/// Fake [SystemRepository] simulating the ESP32 firmware for Demo Mode.
///
/// Features:
/// - Computes ventilation tier using [Thresholds] directly.
/// - Fan forced ON in Danger tier (safety override).
/// - Honors `manualToggle` in Safe and Medium tiers.
/// - Drift loop with mean-reversion every [tickInterval].
/// - Emits exact firmware strings from PRD Table III and DATA_SAMPLE.json.
/// - In raw snapshot: omits `manualToggle` until first write, omits `lastSeen`.
/// - Fully testable with injected [tickInterval], [random], and [clock].
class FakeSystemRepository implements SystemRepository {
  FakeSystemRepository({
    this.tickInterval = const Duration(seconds: 2),
    math.Random? random,
    DateTime Function()? clock,
    double initialTemperature = baselineTemp,
    double initialHumidity = baselineHumidity,
    double initialAirQuality = baselineAirQuality,
  }) : _random = random ?? math.Random(),
       _clock = clock ?? DateTime.now,
       _temperature = initialTemperature,
       _humidity = initialHumidity,
       _airQuality = initialAirQuality {
    _initControllers();
    _recomputeState();
  }

  // --- Constants & Baselines ---
  static const double baselineTemp = 24.5;
  static const double baselineHumidity = 48.0;
  static const double baselineAirQuality = 650.0;

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
  double _temperature;
  double _humidity;
  double _airQuality;
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
    // Subtle mean-reverting drift
    final tempDelta =
        (_random.nextDouble() - 0.5) * 0.3 -
        (_temperature - baselineTemp) * 0.1;
    _temperature = (_temperature + tempDelta).clamp(18.0, 38.0);

    final humDelta =
        (_random.nextDouble() - 0.5) * 0.8 -
        (_humidity - baselineHumidity) * 0.1;
    _humidity = (_humidity + humDelta).clamp(20.0, 90.0);

    final aqDelta =
        (_random.nextDouble() - 0.5) * 24.0 -
        (_airQuality - baselineAirQuality) * 0.1;
    _airQuality = (_airQuality + aqDelta).clamp(200.0, 4000.0);
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
    // Recover to Safe baseline
    else {
      _airQuality = baselineAirQuality;
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
      // Recover: ramp down -0.5 C per tick to baseline
      _temperature -= 0.5;
      if (_temperature <= baselineTemp) {
        _temperature = baselineTemp;
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

  /// Resets simulated sensor telemetry back to clean Safe baselines.
  void resetToBaseline() {
    _scenario = DemoScenario.none;
    _scenarioStep = 0;
    _heatRampingUp = true;
    _temperature = baselineTemp;
    _humidity = baselineHumidity;
    _airQuality = baselineAirQuality;
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
