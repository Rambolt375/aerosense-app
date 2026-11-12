/// System threshold constants and presets for the AeroSense ventilation system.
///
/// NON-NEGOTIABLE: The firmware owns safety. The ESP32 decides the tier and
/// the fan state. The app uses these constants for fallback tier calculation,
/// threshold bands on history charts, and read-only display in settings.
///
/// Never hard-code these values directly in widgets.
class ThresholdPreset {
  const ThresholdPreset({
    required this.name,
    required this.tempCautionMin,
    required this.tempDangerMin,
    required this.airQualityCautionMin,
    required this.airQualityDangerMin,
    required this.airQualityRecovery,
    required this.humidityCautionMin,
    required this.humidityDangerMin,
    this.airQualityAdcMax = 4095.0,
    this.useHumidity = true,
  });

  final String name;

  /// Temperature (°C) lower boundary for Caution (>= tempCautionMin).
  final double tempCautionMin;

  /// Temperature (°C) lower boundary for Danger (>= tempDangerMin).
  final double tempDangerMin;

  /// Air quality raw ADC index lower boundary for Caution (>= airQualityCautionMin).
  final double airQualityCautionMin;

  /// Air quality raw ADC index lower boundary for Danger (>= airQualityDangerMin).
  final double airQualityDangerMin;

  /// Air quality recovery (clear) level. Firmware returns to Normal only below this level.
  final double airQualityRecovery;

  /// Relative humidity (% RH) lower boundary for Caution.
  // TODO(confirm): unconfirmed whether firmware uses humidity in tier determination.
  final double humidityCautionMin;

  /// Relative humidity (% RH) lower boundary for Danger.
  // TODO(confirm): unconfirmed whether firmware uses humidity in tier determination.
  final double humidityDangerMin;

  /// Hardware maximum for a 12-bit ADC reading (0–4095).
  final double airQualityAdcMax;

  /// Whether humidity is evaluated in fallback tier determination and charts.
  // TODO(confirm): set false if firmware confirms humidity is not used.
  final bool useHumidity;

  /// Confirmed firmware thresholds.
  static const ThresholdPreset firmware = ThresholdPreset(
    name: 'firmware',
    tempCautionMin: 33.5,
    tempDangerMin: 36.0,
    airQualityCautionMin: 1400.0,
    airQualityDangerMin: 2000.0,
    airQualityRecovery: 1250.0,
    humidityCautionMin: 60.0, // TODO(confirm)
    humidityDangerMin: 75.0, // TODO(confirm)
    useHumidity: true,
  );

  /// Demo slot with earlier PRD / testing values.
  static const ThresholdPreset demo = ThresholdPreset(
    name: 'demo',
    tempCautionMin: 28.0, // TODO(confirm)
    tempDangerMin: 32.0, // TODO(confirm)
    airQualityCautionMin: 1000.0, // TODO(confirm)
    airQualityDangerMin: 2000.0, // TODO(confirm)
    airQualityRecovery: 1000.0, // TODO(confirm)
    humidityCautionMin: 60.0, // TODO(confirm)
    humidityDangerMin: 75.0, // TODO(confirm)
    useHumidity: true,
  );

  /// Defensively parses `/config/thresholds` JSON from RTDB, falling back to firmware preset.
  factory ThresholdPreset.fromJson(Map<dynamic, dynamic>? json) {
    if (json == null) return firmware;

    double? parseD(dynamic v) {
      if (v is num && v.isFinite) return v.toDouble();
      if (v is String) {
        final d = double.tryParse(v);
        if (d != null && d.isFinite) return d;
      }
      return null;
    }

    final tc =
        parseD(json['tempCaution']) ??
        parseD(json['tempCautionMin']) ??
        parseD(json['temperatureCaution']) ??
        firmware.tempCautionMin;

    final td =
        parseD(json['tempDanger']) ??
        parseD(json['tempDangerMin']) ??
        parseD(json['temperatureDanger']) ??
        firmware.tempDangerMin;

    final aqc =
        parseD(json['airQualityCaution']) ??
        parseD(json['airQualityCautionMin']) ??
        firmware.airQualityCautionMin;

    final aqd =
        parseD(json['airQualityDanger']) ??
        parseD(json['airQualityDangerMin']) ??
        firmware.airQualityDangerMin;

    final aqr =
        parseD(json['airQualityRecovery']) ?? firmware.airQualityRecovery;

    final hc =
        parseD(json['humidityCaution']) ??
        parseD(json['humidityCautionMin']) ??
        firmware.humidityCautionMin;

    final hd =
        parseD(json['humidityDanger']) ??
        parseD(json['humidityDangerMin']) ??
        firmware.humidityDangerMin;

    final useHum = (json['useHumidity'] as bool?) ?? firmware.useHumidity;

    return ThresholdPreset(
      name: (json['name'] as String?) ?? 'custom',
      tempCautionMin: tc,
      tempDangerMin: td,
      airQualityCautionMin: aqc,
      airQualityDangerMin: aqd,
      airQualityRecovery: aqr,
      humidityCautionMin: hc,
      humidityDangerMin: hd,
      useHumidity: useHum,
    );
  }
}

/// Central system thresholds accessor.
///
/// Any change to [current] updates fallback calculation, charts, and demo generation.
class Thresholds {
  Thresholds._();

  /// The active threshold preset. Defaults to [ThresholdPreset.firmware].
  static ThresholdPreset current = ThresholdPreset.firmware;

  // --- Temperature (°C) ---
  /// Lower boundary for Caution (Medium) temperature. Values >= [tempSafeMax] are Medium.
  static double get tempSafeMax => current.tempCautionMin;
  static double get tempCautionMin => current.tempCautionMin;

  /// Lower boundary for Danger temperature. Values >= [tempDangerMin] are Danger.
  static double get tempDangerMin => current.tempDangerMin;

  // --- Relative Humidity (% RH) ---
  /// Lower boundary for Caution (Medium) humidity.
  // TODO(confirm): firmware owner hasn't confirmed humidity use.
  static double get humiditySafeMax => current.humidityCautionMin;
  static double get humidityCautionMin => current.humidityCautionMin;

  /// Lower boundary for Danger humidity.
  // TODO(confirm): firmware owner hasn't confirmed humidity use.
  static double get humidityDangerMin => current.humidityDangerMin;

  // --- Air Quality (raw 12-bit ADC index, 0–4095) ---
  // NOTE: This is an uncalibrated relative index from the MQ-135 sensor, NOT ppm.
  /// Lower boundary for Caution (Medium) air quality. Values >= [airQualitySafeMax] are Medium.
  static double get airQualitySafeMax => current.airQualityCautionMin;
  static double get airQualityCautionMin => current.airQualityCautionMin;

  /// Lower boundary for Danger air quality. Values >= [airQualityDangerMin] are Danger.
  static double get airQualityDangerMin => current.airQualityDangerMin;

  /// Air quality recovery level (1250 in firmware).
  static double get airQualityRecovery => current.airQualityRecovery;

  /// Hardware maximum for a 12-bit ADC reading (0–4095).
  static double get airQualityAdcMax => current.airQualityAdcMax;

  /// Whether humidity is evaluated in fallback tier determination.
  static bool get useHumidity => current.useHumidity;
}
