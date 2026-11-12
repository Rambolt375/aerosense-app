import 'package:aerosense_app/core/sensor_validation.dart';
import 'package:aerosense_app/core/time_utils.dart';
import 'package:aerosense_app/data/models/tier.dart';

/// Parses the ESP32 fanStatus field into a bool.
///
/// Primary type is String "ON"/"OFF" (confirmed from DATA_SAMPLE.json).
/// Tolerant of bool in case a future firmware change sends a boolean.
// TODO(confirm): fanStatus confirmed as String "ON"/"OFF"; bool fallback kept.
bool _parseFanStatus(dynamic v) {
  if (v is bool) return v;
  if (v is String) return v.toUpperCase() == 'ON';
  return false;
}

/// Snapshot of live telemetry from the `/system` RTDB node.
///
/// Parsed defensively: null/NaN/missing fields produce null values that
/// render as "--" in the UI. Unknown JSON keys are silently ignored.
class SystemState {
  const SystemState({
    this.temperature,
    this.humidity,
    this.airQuality,
    this.fanOn = false,
    this.manualToggle = false,
    this.statusMessage = '',
    this.tier = Tier.safe,
    this.manualEndsAt,
  });

  /// Returns an empty SystemState used before the first RTDB event arrives.
  const SystemState.empty()
    : temperature = null,
      humidity = null,
      airQuality = null,
      fanOn = false,
      manualToggle = false,
      statusMessage = '',
      tier = Tier.safe,
      manualEndsAt = null;

  /// Temperature in °C. Null on DHT22 read failure or missing field.
  final double? temperature;

  /// Relative humidity in % RH. Null on DHT22 read failure or missing field.
  final double? humidity;

  /// Air quality as a raw 12-bit ADC index (0–4095). NOT ppm.
  /// Null on missing field.
  final double? airQuality;

  /// True when the fan is running (derived from firmware fanStatus field).
  // fanStatus is String "ON"/"OFF" per firmware; tolerant of bool.
  final bool fanOn;

  /// The app-written manual toggle. Missing from /system means false;
  /// the app's first write creates the field.
  final bool manualToggle;

  /// Raw status message from the firmware, displayed verbatim in the UI.
  final String statusMessage;

  /// Resolved tier (primary: statusMessage prefix; fallback: sensor values).
  final Tier tier;

  /// Optional epoch timestamp indicating when the manual ventilation run ends.
  /// Parsed defensively from /system/manualEndsAt.
  // TODO(confirm): manualEndsAt confirmed as planned firmware field; app works with or without it.
  final DateTime? manualEndsAt;

  /// Parses a [SystemState] from the raw RTDB snapshot [value].
  ///
  /// [value] should be the `DataSnapshot.value` from the `/system` node —
  /// typed as `Object?` by firebase_database; we expect a `Map` at runtime.
  factory SystemState.fromJson(Object? value) {
    if (value == null || value is! Map) return const SystemState.empty();
    final json = value;

    final rawTemp = parseSensorDouble(json['temperature']);
    final rawHum = parseSensorDouble(json['humidity']);
    final rawAq = parseSensorDouble(json['airQuality']);

    final validated = validateSensorReadings(
      temperature: rawTemp,
      humidity: rawHum,
      airQuality: rawAq,
    );

    final temperature = validated.temperature;
    final humidity = validated.humidity;
    final airQuality = validated.airQuality;

    final fanOn = _parseFanStatus(json['fanStatus']);
    final manualToggle = (json['manualToggle'] as bool?) ?? false;
    final statusMessage = (json['statusMessage'] as String?) ?? '';
    final manualEndsAt = parseTimestamp(json['manualEndsAt']);

    final tier = Tier.resolve(
      statusMessage,
      temperature: temperature,
      humidity: humidity,
      airQuality: airQuality,
    );

    return SystemState(
      temperature: temperature,
      humidity: humidity,
      airQuality: airQuality,
      fanOn: fanOn,
      manualToggle: manualToggle,
      statusMessage: statusMessage,
      tier: tier,
      manualEndsAt: manualEndsAt,
    );
  }
}
