/// System threshold constants for the AeroSense ventilation system.
///
/// NON-NEGOTIABLE: The firmware owns safety. The ESP32 decides the tier and
/// the fan state. The app uses these constants for fallback tier calculation,
/// threshold bands on history charts, and read-only display in settings.
///
/// Never hard-code these values directly in widgets.
class Thresholds {
  Thresholds._();

  // --- Temperature (°C) ---
  /// Upper boundary for Safe temperature. Values in [tempSafeMax, tempDangerMin] are Medium.
  static const double tempSafeMax = 28.0;

  /// Lower boundary for Danger temperature. Values > [tempDangerMin] are Danger.
  static const double tempDangerMin = 32.0;

  // --- Relative Humidity (% RH) ---
  /// Upper boundary for Safe humidity. Values in [humiditySafeMax, humidityDangerMin] are Medium.
  static const double humiditySafeMax = 60.0;

  /// Lower boundary for Danger humidity. Values > [humidityDangerMin] are Danger.
  static const double humidityDangerMin = 75.0;

  // --- Air Quality (raw 12-bit ADC index, 0–4095) ---
  // NOTE: This is an uncalibrated relative index from the MQ-135 sensor, NOT ppm.
  /// Upper boundary for Safe air quality. Values in [airQualitySafeMax, airQualityDangerMin] are Medium.
  static const double airQualitySafeMax = 1000.0;

  /// Lower boundary for Danger air quality. Values > [airQualityDangerMin] are Danger.
  static const double airQualityDangerMin = 2000.0;

  /// Hardware maximum for a 12-bit ADC reading (0–4095).
  static const double airQualityAdcMax = 4095.0;
}
