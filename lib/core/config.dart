/// Application configuration flags and default parameters.
class AppConfig {
  AppConfig._();

  /// Whether user self-signup is permitted in the UI.
  /// Accounts are managed in Firebase Console by default.
  static const bool allowSignUp = false;

  /// Regional Realtime Database URL for asia-southeast1.
  static const String databaseUrl =
      'https://aerosense-502de-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Minimum historical records required for diurnal forecast (~3 days at 5-min intervals).
  static const int minForecastPoints = 864;

  /// Minimum records required in Demo mode or when short-history forecast is enabled (~3 hours).
  static const int demoForecastPoints = 36;

  /// Standard deviation multiplier (k) for the forecast residual gate (FR-6).
  static const double forecastSigmaMultiplier = 3.0;

  /// Hysteresis count: consecutive valid samples needed to return from CHAOTIC to PREDICTABLE.
  static const int forecastHysteresisSamples = 3;
}
