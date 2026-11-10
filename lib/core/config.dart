/// Application configuration flags and default parameters.
class AppConfig {
  AppConfig._();

  /// Whether user self-signup is permitted in the UI.
  /// Accounts are managed in Firebase Console by default.
  static const bool allowSignUp = false;

  /// Regional Realtime Database URL for asia-southeast1.
  static const String databaseUrl =
      'https://aerosense-502de-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Minimum historical records required for diurnal forecast (2 days at 5-min intervals = 576 points).
  ///
  /// A single 24-hour cycle (288 points) is insufficient evidence on its own because
  /// transient atypical room usage, weather anomalies, or sensor shifts can easily be
  /// misinterpreted as a recurring wave. Requiring at least 2 full days ensures periodicity
  /// repeats across multiple days before trusting the predictive model.
  static const int minForecastPoints = 576;

  /// Minimum records required in Demo mode or when short-history forecast is enabled (~3 hours).
  static const int demoForecastPoints = 36;

  /// Standard deviation multiplier (k) for the forecast residual gate (FR-6).
  ///
  /// NOTE: This constant is NOT tuned on fake data and must be recalibrated
  /// against real 24 h+ physical hardware logs once available.
  static const double forecastSigmaMultiplier = 3.0;

  /// Hysteresis count: consecutive valid samples needed to return from LOCKED_OUT to ACTIVE.
  static const int forecastHysteresisSamples = 3;

  /// Minimum historical time span required for diurnal fitting in production (FR-6 requirement).
  ///
  /// NOTE: NOT tuned on fake data; recalibrate on real logs.
  static const int minForecastSpanHours = 24;

  /// Minimum number of distinct hourly bins (0..23) required for time-of-day coverage.
  /// Ensures records are well distributed across the 24-hour cycle before fitting.
  ///
  /// NOTE: NOT tuned on fake data; recalibrate on real logs.
  static const int minHourlyBins = 20;

  /// Minimum temperature residual tolerance floor derived from DHT22 sensor accuracy (±0.5 °C).
  /// Prevents artificially tiny tolerance bands in low-noise environments.
  ///
  /// NOTE: NOT tuned on fake data; recalibrate on real logs.
  static const double minTempTolerance = 0.5;

  /// Minimum air quality residual tolerance floor for raw ADC noise.
  ///
  /// NOTE: NOT tuned on fake data; recalibrate on real logs.
  static const double minAqTolerance = 30.0;

  /// Minimum variance explained (R^2) required to declare a clear daily pattern.
  /// If R^2 < 0.3, the diurnal sinusoid accounts for less than 30% of total variance,
  /// indicating pure noise or a non-periodic environment without a clear daily cycle.
  ///
  /// NOTE: NOT tuned on fake data; recalibrate on real logs.
  static const double minR2Pattern = 0.3;
}
