import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';

void main() {
  group('SystemState.fromJson', () {
    // --- exact DATA_SAMPLE.json /system object ---
    test('parses DATA_SAMPLE.json /system snapshot correctly', () {
      final json = {
        'airQuality': 1128,
        'fanStatus': 'OFF',
        'humidity': 40,
        'statusMessage':
            'MEDIUM: Environment is stuffy. Manual toggle available.',
        'temperature': 24,
      };
      final state = SystemState.fromJson(json);

      expect(state.airQuality, 1128.0);
      expect(state.fanOn, isFalse);
      expect(state.humidity, 40.0);
      expect(
        state.statusMessage,
        'MEDIUM: Environment is stuffy. Manual toggle available.',
      );
      expect(state.temperature, 24.0);
      expect(state.tier, Tier.medium);
      expect(state.manualToggle, isFalse); // absent → false
    });

    // --- empty / null input ---
    test('null input → SystemState.empty()', () {
      final state = SystemState.fromJson(null);
      expect(state.temperature, isNull);
      expect(state.humidity, isNull);
      expect(state.airQuality, isNull);
      expect(state.fanOn, isFalse);
      expect(state.manualToggle, isFalse);
      expect(state.tier, Tier.safe);
    });

    test('non-Map input → SystemState.empty()', () {
      expect(SystemState.fromJson(42).temperature, isNull);
      expect(SystemState.fromJson('string').temperature, isNull);
      expect(SystemState.fromJson([1, 2]).temperature, isNull);
    });

    // --- int sensor values (confirmed from DATA_SAMPLE) ---
    test('int temperature and humidity are coerced to double', () {
      final state = SystemState.fromJson({'temperature': 24, 'humidity': 40});
      expect(state.temperature, isA<double>());
      expect(state.humidity, isA<double>());
      expect(state.temperature, 24.0);
      expect(state.humidity, 40.0);
    });

    // --- NaN handling ---
    test('double NaN temperature → null', () {
      final state = SystemState.fromJson({
        'temperature': double.nan,
        'humidity': 50.0,
      });
      expect(state.temperature, isNull);
      expect(state.humidity, 50.0);
    });

    // --- fanStatus variants ---
    test('fanStatus "ON" → fanOn true', () {
      expect(SystemState.fromJson({'fanStatus': 'ON'}).fanOn, isTrue);
    });
    test('fanStatus "OFF" → fanOn false', () {
      expect(SystemState.fromJson({'fanStatus': 'OFF'}).fanOn, isFalse);
    });
    test('fanStatus "on" (lowercase) → fanOn true (toUpperCase tolerant)', () {
      expect(SystemState.fromJson({'fanStatus': 'on'}).fanOn, isTrue);
    });
    test('fanStatus bool true → fanOn true (tolerant fallback)', () {
      expect(SystemState.fromJson({'fanStatus': true}).fanOn, isTrue);
    });
    test('fanStatus bool false → fanOn false', () {
      expect(SystemState.fromJson({'fanStatus': false}).fanOn, isFalse);
    });
    test('fanStatus null → fanOn false', () {
      expect(SystemState.fromJson({'fanStatus': null}).fanOn, isFalse);
    });
    test('fanStatus absent → fanOn false', () {
      expect(SystemState.fromJson(<String, dynamic>{}).fanOn, isFalse);
    });

    // --- manualToggle ---
    test('manualToggle absent → false', () {
      expect(SystemState.fromJson({'temperature': 25.0}).manualToggle, isFalse);
    });
    test('manualToggle true is preserved', () {
      expect(SystemState.fromJson({'manualToggle': true}).manualToggle, isTrue);
    });

    // --- unknown keys silently ignored ---
    test('extra unknown fields do not crash parsing', () {
      final state = SystemState.fromJson({
        'temperature': 25.0,
        'newFirmwareField': 'someValue',
        'anotherField': 42,
      });
      expect(state.temperature, 25.0);
    });

    // --- tier resolution from statusMessage ---
    test('DANGER statusMessage → tier danger regardless of safe values', () {
      final state = SystemState.fromJson({
        'temperature': 20.0,
        'humidity': 40.0,
        'airQuality': 100.0,
        'statusMessage':
            'DANGER: High thresholds breached! Auto-fan activated.',
      });
      expect(state.tier, Tier.danger);
    });
  });
}
