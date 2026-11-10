import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/tier.dart';

/// Computes the tier for a single metric from its raw sensor value.
///
/// Used by metric tiles to show individual Safe/Medium/Danger badges.
/// Returns [Tier.safe] when [value] is null (missing sensor data).
/// Comparisons are inclusive (>=) matching the ESP32 firmware logic.
class MetricTier {
  MetricTier._();

  /// Derives the tier for temperature in °C.
  static Tier forTemperature(double? value) {
    if (value == null) return Tier.safe;
    if (value >= Thresholds.tempDangerMin) return Tier.danger;
    if (value >= Thresholds.tempSafeMax) return Tier.medium;
    return Tier.safe;
  }

  /// Derives the tier for relative humidity in % RH.
  static Tier forHumidity(double? value) {
    if (value == null || !Thresholds.useHumidity) return Tier.safe;
    if (value >= Thresholds.humidityDangerMin) return Tier.danger;
    if (value >= Thresholds.humiditySafeMax) return Tier.medium;
    return Tier.safe;
  }

  /// Derives the tier for air quality (raw 12-bit ADC index, 0–4095).
  static Tier forAirQuality(double? value) {
    if (value == null) return Tier.safe;
    if (value >= Thresholds.airQualityDangerMin) return Tier.danger;
    if (value >= Thresholds.airQualitySafeMax) return Tier.medium;
    return Tier.safe;
  }
}
