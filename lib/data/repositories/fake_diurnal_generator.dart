import 'dart:math' as math;

/// Single synthetic telemetry point along the 24-hour diurnal cycle.
class DiurnalSample {
  const DiurnalSample({
    required this.temperature,
    required this.humidity,
    required this.airQuality,
  });

  final double temperature;
  final double humidity;
  final double airQuality;
}

/// Generates a synthetic telemetry sample along a 24-hour diurnal cycle.
///
/// Used by both [FakeHistoryRepository] and [FakeSystemRepository] to ensure
/// the live demo baseline matches the historical training distribution at the
/// current clock time (preventing persistent demo residual gate lockout).
///
/// Uses [time.hour], [time.minute], and [time.second] directly so the values
/// are independent of host timezone shifts.
DiurnalSample generateDiurnalSample(
  DateTime time, {
  math.Random? random,
  bool addNoise = true,
}) {
  final secondsSinceMidnight =
      time.hour * 3600 + time.minute * 60 + time.second;
  final theta = 2 * math.pi * (secondsSinceMidnight / 86400.0);
  final hourOfDay = secondsSinceMidnight / 3600.0;

  // 1. Temperature: Peak at ~15:00 (~29.5 °C), trough at ~03:00 (~20.5 °C)
  // Phase angle: theta_15:00 = 1.25 pi -> sin(theta - 0.75 pi) = 1 at 15:00
  final tempNoise = (addNoise && random != null)
      ? (random.nextDouble() - 0.5) * 0.5
      : 0.0;
  var temp = 25.0 + 4.5 * math.sin(theta - 0.75 * math.pi) + tempNoise;

  // 2. Humidity: Inverse diurnal cycle (peaks at night, drops in afternoon heat)
  final humNoise = (addNoise && random != null)
      ? (random.nextDouble() - 0.5) * 1.5
      : 0.0;
  var hum = 55.0 - 12.0 * math.sin(theta - 0.75 * math.pi) + humNoise;

  // 3. Air Quality:
  // Dominant 24-hour sinusoidal component peaking in the evening (~18:00):
  // theta_18:00 = 1.5 pi -> sin(theta - pi) = 1 at 18:00
  final aqSinWave = 750.0 + 180.0 * math.sin(theta - math.pi);
  final morningBump = 100.0 * math.exp(-math.pow(hourOfDay - 8.5, 2) / 2.0);
  final eveningBump = 140.0 * math.exp(-math.pow(hourOfDay - 19.5, 2) / 2.0);
  final aqNoise = (addNoise && random != null)
      ? (random.nextDouble() - 0.5) * 30.0
      : 0.0;

  var aq = aqSinWave + morningBump + eveningBump + aqNoise;

  temp = temp.clamp(15.0, 42.0);
  hum = hum.clamp(10.0, 95.0);
  aq = aq.clamp(100.0, 4095.0);

  return DiurnalSample(
    temperature: double.parse(temp.toStringAsFixed(1)),
    humidity: double.parse(hum.toStringAsFixed(1)),
    airQuality: double.parse(aq.toStringAsFixed(0)),
  );
}
