import 'package:aerosense_app/core/sensor_validation.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';

/// Computes validated 24-hour statistics from archived `/history` records.
///
/// Only records with a real timestamp inside `[now - 24 h, now]` are counted.
/// Records with null timestamps (the synthetic time axis) are ignored rather
/// than estimated. Invalid readings, including the DHT22 0/0 unplugged
/// signature, are dropped per metric.
HistoryStats24h computeHistoryStats24h({
  required List<HistoryRecord> records,
  required DateTime now,
}) {
  final windowStart = now.subtract(const Duration(hours: 24));

  final temperatures = <double>[];
  final humidities = <double>[];
  final airQualities = <double>[];
  DateTime? earliest;
  var sampleCount = 0;

  for (final record in records) {
    final timestamp = record.timestamp;
    if (timestamp == null) continue;
    if (timestamp.isBefore(windowStart) || timestamp.isAfter(now)) continue;

    final validated = validateSensorReadings(
      temperature: record.temperature,
      humidity: record.humidity,
      airQuality: record.airQuality,
    );

    final temperature = validated.temperature;
    final humidity = validated.humidity;
    final airQuality = validated.airQuality;
    if (temperature == null && humidity == null && airQuality == null) {
      continue;
    }

    sampleCount++;
    if (earliest == null || timestamp.isBefore(earliest)) {
      earliest = timestamp;
    }
    if (temperature != null) temperatures.add(temperature);
    if (humidity != null) humidities.add(humidity);
    if (airQuality != null) airQualities.add(airQuality);
  }

  return HistoryStats24h(
    sampleCount: sampleCount,
    windowStart: earliest,
    temperature: _statsFor(temperatures),
    humidity: _statsFor(humidities),
    airQuality: _statsFor(airQualities),
  );
}

MetricStats? _statsFor(List<double> values) {
  if (values.isEmpty) return null;

  var min = values.first;
  var max = values.first;
  var sum = 0.0;
  for (final value in values) {
    if (value < min) min = value;
    if (value > max) max = value;
    sum += value;
  }
  return MetricStats(min: min, max: max, mean: sum / values.length);
}
