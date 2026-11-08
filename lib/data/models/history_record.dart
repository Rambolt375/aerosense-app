import 'package:aerosense_app/core/time_utils.dart';

/// Single archived telemetry record from a `/history` push-key child.
///
/// Parsed defensively. [pushKey] is preserved for chronological ordering
/// when [timestamp] cannot be resolved (e.g. millis-since-boot values).
///
/// Note: /history does not exist in real data yet. This model is exercised
/// by unit tests with synthetic maps only.
// TODO(confirm): timestamp format in /history — test with real data once available.
class HistoryRecord {
  const HistoryRecord({
    required this.pushKey,
    this.timestamp,
    this.temperature,
    this.humidity,
    this.airQuality,
  });

  /// The RTDB auto-generated push key (e.g. "-NxK2…"). Sorts chronologically.
  final String pushKey;

  /// Wall-clock time of the record. Null when timestamp cannot be parsed
  /// or appears to be millis()-since-boot; fall back to [pushKey] ordering.
  final DateTime? timestamp;

  /// Temperature in °C. Null on parse failure or missing field.
  final double? temperature;

  /// Relative humidity in % RH. Null on parse failure or missing field.
  final double? humidity;

  /// Air quality raw ADC index. NOT ppm. Null on parse failure or missing.
  final double? airQuality;

  /// Parses a [HistoryRecord] from a child snapshot of `/history`.
  ///
  /// [key] is the RTDB push key; [value] is the snapshot's raw value.
  factory HistoryRecord.fromSnapshot(String key, Object? value) {
    final json = (value is Map) ? value : <dynamic, dynamic>{};

    return HistoryRecord(
      pushKey: key,
      timestamp: parseTimestamp(json['timestamp']),
      temperature: parseSensorDouble(json['temperature']),
      humidity: parseSensorDouble(json['humidity']),
      airQuality: parseSensorDouble(json['airQuality']),
    );
  }
}
