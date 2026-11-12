/// Application configuration flags and default parameters.
class AppConfig {
  AppConfig._();

  /// Application version string matching pubspec.yaml.
  static const String appVersion = '1.0.0+1';

  /// Whether user self-signup is permitted in the UI.
  /// Accounts are managed in Firebase Console by default.
  static const bool allowSignUp = false;

  /// Regional Realtime Database URL for asia-southeast1.
  static const String databaseUrl =
      'https://aerosense-502de-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Expected interval at which firmware writes to `/history` (10 minutes).
  static const Duration expectedLogInterval = Duration(minutes: 10);

  /// Device offline threshold: 2 missed cycles = 2 * 10 min = 20 minutes.
  static const Duration offlineThreshold = Duration(minutes: 20);

  /// Cadence for evaluating device offline status (30 seconds).
  static const Duration freshnessEvaluationInterval = Duration(seconds: 30);

  /// Multiplier relative to log interval to detect chart gaps (2.5x = 25 minutes).
  static const double gapThresholdMultiplier = 2.5;

  /// Minimum historical time span required for diurnal fitting (48 hours).
  static const int minForecastSpanHours = 48;

  /// Minimum number of distinct hourly bins (0..23) required for time-of-day coverage.
  static const int minHourlyBins = 20;

  /// Standard deviation multiplier (k) for the forecast residual gate (FR-6).
  static const double forecastSigmaMultiplier = 3.0;

  /// Hysteresis count: consecutive valid samples needed to return from LOCKED_OUT to ACTIVE.
  static const int forecastHysteresisSamples = 3;

  /// Minimum temperature residual tolerance floor derived from DHT22 sensor accuracy (±0.5 °C).
  static const double minTempTolerance = 0.5;

  /// Minimum air quality residual tolerance floor for raw ADC noise.
  static const double minAqTolerance = 30.0;

  /// Minimum variance explained (R^2) required to declare a clear daily pattern.
  static const double minR2Pattern = 0.3;

  /// Default duration for a manual ventilation run (5 minutes).
  static const Duration defaultManualDuration = Duration(minutes: 5);

  /// Default duration in seconds for manual ventilation (300 seconds).
  static const int defaultManualDurationSec = 300;

  /// Confirmation timeout waiting for firmware to echo manualToggle (5 seconds).
  static const Duration manualToggleConfirmTimeout = Duration(seconds: 5);
}
