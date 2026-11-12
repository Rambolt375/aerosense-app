import 'package:aerosense_app/data/models/history_record.dart';

/// Hardware validation limits for AeroSense sensors:
/// - DHT22 Temperature range: -40.0 °C to 80.0 °C
/// - DHT22 Humidity range: 0.0 % RH to 100.0 % RH
/// - MQ-135 12-bit ADC raw range: 0 to 4095
const double minValidTemperature = -40.0;
const double maxValidTemperature = 80.0;
const double minValidHumidity = 0.0;
const double maxValidHumidity = 100.0;
const double minValidAirQuality = 0.0;
const double maxValidAirQuality = 4095.0;

/// Validates a temperature reading against physical hardware limits (-40..80 °C).
/// Returns null if null, non-finite, or outside the valid range.
double? validateTemperature(double? temp) {
  if (temp == null || !temp.isFinite) return null;
  if (temp < minValidTemperature || temp > maxValidTemperature) return null;
  return temp;
}

/// Validates a relative humidity reading against physical hardware limits (0..100 % RH).
/// Returns null if null, non-finite, or outside the valid range.
double? validateHumidity(double? hum) {
  if (hum == null || !hum.isFinite) return null;
  if (hum < minValidHumidity || hum > maxValidHumidity) return null;
  return hum;
}

/// Validates an air quality 12-bit ADC reading against hardware limits (0..4095).
/// Returns null if null, non-finite, or outside the valid range.
double? validateAirQuality(double? aq) {
  if (aq == null || !aq.isFinite) return null;
  if (aq < minValidAirQuality || aq > maxValidAirQuality) return null;
  return aq;
}

/// Result of validating a complete set of sensor readings.
typedef ValidatedReadings = ({
  double? temperature,
  double? humidity,
  double? airQuality,
});

/// Validates raw sensor readings according to hardware physical bounds and failure signatures:
/// 1. Temperature must be within -40..80 °C.
/// 2. Humidity must be within 0..100 % RH.
/// 3. Air quality must be within 0..4095 ADC index.
/// 4. DHT22 unplugged failure signature: when both temperature == 0 and humidity == 0,
///    both are treated as null (sensor disconnected or communications bus grounded).
ValidatedReadings validateSensorReadings({
  double? temperature,
  double? humidity,
  double? airQuality,
}) {
  var t = validateTemperature(temperature);
  var h = validateHumidity(humidity);
  final a = validateAirQuality(airQuality);

  if (t == 0.0 && h == 0.0) {
    t = null;
    h = null;
  }

  return (temperature: t, humidity: h, airQuality: a);
}

/// Validates a [HistoryRecord], nulling out any out-of-range sensor fields
/// or DHT22 unplugged 0/0 failure signatures.
HistoryRecord validateHistoryRecord(HistoryRecord record) {
  final validated = validateSensorReadings(
    temperature: record.temperature,
    humidity: record.humidity,
    airQuality: record.airQuality,
  );

  return HistoryRecord(
    pushKey: record.pushKey,
    timestamp: record.timestamp,
    temperature: validated.temperature,
    humidity: validated.humidity,
    airQuality: validated.airQuality,
  );
}

/// Validates an entire list of [HistoryRecord]s in place of raw readings.
List<HistoryRecord> validateHistoryRecords(List<HistoryRecord> records) {
  return records.map(validateHistoryRecord).toList();
}
