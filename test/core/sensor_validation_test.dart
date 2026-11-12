import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/sensor_validation.dart';
import 'package:aerosense_app/data/models/history_record.dart';

void main() {
  group('Sensor validation - single values', () {
    test('validateTemperature accepts valid range -40..80', () {
      expect(validateTemperature(-40.0), -40.0);
      expect(validateTemperature(0.0), 0.0);
      expect(validateTemperature(25.5), 25.5);
      expect(validateTemperature(80.0), 80.0);
    });

    test('validateTemperature rejects values outside -40..80', () {
      expect(validateTemperature(-40.1), isNull);
      expect(validateTemperature(-100.0), isNull);
      expect(validateTemperature(80.1), isNull);
      expect(validateTemperature(999.0), isNull);
      expect(validateTemperature(double.nan), isNull);
      expect(validateTemperature(double.infinity), isNull);
      expect(validateTemperature(null), isNull);
    });

    test('validateHumidity accepts valid range 0..100', () {
      expect(validateHumidity(0.0), 0.0);
      expect(validateHumidity(55.2), 55.2);
      expect(validateHumidity(100.0), 100.0);
    });

    test('validateHumidity rejects values outside 0..100', () {
      expect(validateHumidity(-0.1), isNull);
      expect(validateHumidity(-50.0), isNull);
      expect(validateHumidity(100.1), isNull);
      expect(validateHumidity(150.0), isNull);
      expect(validateHumidity(double.nan), isNull);
      expect(validateHumidity(double.infinity), isNull);
      expect(validateHumidity(null), isNull);
    });

    test('validateAirQuality accepts valid range 0..4095', () {
      expect(validateAirQuality(0.0), 0.0);
      expect(validateAirQuality(1200.0), 1200.0);
      expect(validateAirQuality(4095.0), 4095.0);
    });

    test('validateAirQuality rejects values outside 0..4095', () {
      expect(validateAirQuality(-0.1), isNull);
      expect(validateAirQuality(-10.0), isNull);
      expect(validateAirQuality(4095.1), isNull);
      expect(validateAirQuality(5000.0), isNull);
      expect(validateAirQuality(double.nan), isNull);
      expect(validateAirQuality(double.infinity), isNull);
      expect(validateAirQuality(null), isNull);
    });
  });

  group('Sensor validation - record / tuple validation', () {
    test('normal readings are preserved', () {
      final result = validateSensorReadings(
        temperature: 24.5,
        humidity: 48.0,
        airQuality: 850.0,
      );
      expect(result.temperature, 24.5);
      expect(result.humidity, 48.0);
      expect(result.airQuality, 850.0);
    });

    test('DHT22 unplugged signature: temp == 0 AND hum == 0 nulls both', () {
      final result = validateSensorReadings(
        temperature: 0.0,
        humidity: 0.0,
        airQuality: 900.0,
      );
      expect(result.temperature, isNull);
      expect(result.humidity, isNull);
      expect(result.airQuality, 900.0); // AQ is from separate MQ-135 pin
    });

    test('valid freezing temp (0.0) with non-zero humidity is preserved', () {
      final result = validateSensorReadings(
        temperature: 0.0,
        humidity: 65.0,
        airQuality: 700.0,
      );
      expect(result.temperature, 0.0);
      expect(result.humidity, 65.0);
    });

    test('valid dry humidity (0.0) with non-zero temperature is preserved', () {
      final result = validateSensorReadings(
        temperature: 22.0,
        humidity: 0.0,
        airQuality: 700.0,
      );
      expect(result.temperature, 22.0);
      expect(result.humidity, 0.0);
    });

    test('out-of-range fields are nulled individually', () {
      final result = validateSensorReadings(
        temperature: 95.0, // out of range
        humidity: 50.0, // valid
        airQuality: -10.0, // out of range
      );
      expect(result.temperature, isNull);
      expect(result.humidity, 50.0);
      expect(result.airQuality, isNull);
    });
  });

  group('HistoryRecord validation', () {
    test('validates HistoryRecord and nulls DHT22 unplugged 0/0 failure', () {
      final badRecord = HistoryRecord(
        pushKey: '-NxTest1',
        timestamp: DateTime(2026, 11, 12, 10, 0),
        temperature: 0.0,
        humidity: 0.0,
        airQuality: 800.0,
      );

      final validated = validateHistoryRecord(badRecord);
      expect(validated.pushKey, '-NxTest1');
      expect(validated.timestamp, badRecord.timestamp);
      expect(validated.temperature, isNull);
      expect(validated.humidity, isNull);
      expect(validated.airQuality, 800.0);
    });

    test('validates list of HistoryRecords', () {
      final records = [
        HistoryRecord(
          pushKey: '-Nx1',
          timestamp: DateTime(2026, 11, 12, 10, 0),
          temperature: 24.0,
          humidity: 45.0,
          airQuality: 600.0,
        ),
        HistoryRecord(
          pushKey: '-Nx2',
          timestamp: DateTime(2026, 11, 12, 10, 10),
          temperature: 0.0,
          humidity: 0.0,
          airQuality: 620.0,
        ),
        HistoryRecord(
          pushKey: '-Nx3',
          timestamp: DateTime(2026, 11, 12, 10, 20),
          temperature: 120.0,
          humidity: 150.0,
          airQuality: 5000.0,
        ),
      ];

      final validated = validateHistoryRecords(records);
      expect(validated.length, 3);
      expect(validated[0].temperature, 24.0);
      expect(validated[0].humidity, 45.0);

      expect(validated[1].temperature, isNull);
      expect(validated[1].humidity, isNull);
      expect(validated[1].airQuality, 620.0);

      expect(validated[2].temperature, isNull);
      expect(validated[2].humidity, isNull);
      expect(validated[2].airQuality, isNull);
    });
  });
}
