import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/features/summary/history_stats.dart';

void main() {
  final now = DateTime(2026, 11, 15, 14, 0);

  HistoryRecord record(
    String key,
    DateTime? timestamp, {
    double? temperature,
    double? humidity,
    double? airQuality,
  }) {
    return HistoryRecord(
      pushKey: key,
      timestamp: timestamp,
      temperature: temperature,
      humidity: humidity,
      airQuality: airQuality,
    );
  }

  group('computeHistoryStats24h', () {
    test('computes min, max and mean inside the window', () {
      final stats = computeHistoryStats24h(
        records: [
          record('a', now.subtract(const Duration(hours: 2)), temperature: 20),
          record('b', now.subtract(const Duration(hours: 1)), temperature: 30),
          record('c', now, temperature: 40),
        ],
        now: now,
      );

      expect(stats.sampleCount, 3);
      expect(stats.temperature!.min, 20);
      expect(stats.temperature!.max, 40);
      expect(stats.temperature!.mean, 30);
      expect(stats.isEmpty, isFalse);
      expect(stats.isSparse, isTrue); // fewer than 6 readings
    });

    test('excludes records older than 24 hours', () {
      final stats = computeHistoryStats24h(
        records: [
          record(
            'old',
            now.subtract(const Duration(hours: 25)),
            temperature: 99,
          ),
          record(
            'new',
            now.subtract(const Duration(hours: 1)),
            temperature: 25,
          ),
        ],
        now: now,
      );

      expect(stats.sampleCount, 1);
      expect(stats.temperature!.max, 25);
    });

    test('excludes future timestamps', () {
      final stats = computeHistoryStats24h(
        records: [
          record('future', now.add(const Duration(hours: 1)), temperature: 99),
          record('now', now, temperature: 25),
        ],
        now: now,
      );

      expect(stats.sampleCount, 1);
      expect(stats.temperature!.max, 25);
    });

    test('ignores records without timestamps (synthetic time axis)', () {
      final stats = computeHistoryStats24h(
        records: [
          record('a', null, temperature: 30),
          record('b', now.subtract(const Duration(hours: 1)), temperature: 25),
        ],
        now: now,
      );

      expect(stats.sampleCount, 1);
      expect(stats.temperature!.mean, 25);
    });

    test('ignores invalid readings and keeps valid metrics', () {
      final stats = computeHistoryStats24h(
        records: [
          // DHT22 unplugged signature: 0 / 0, air quality still plausible.
          record(
            'unplugged',
            now.subtract(const Duration(hours: 1)),
            temperature: 0,
            humidity: 0,
            airQuality: 800,
          ),
          // Out of hardware range.
          record(
            'hot',
            now.subtract(const Duration(hours: 2)),
            temperature: 99,
            humidity: 50,
            airQuality: 900,
          ),
        ],
        now: now,
      );

      expect(stats.sampleCount, 2);
      expect(stats.temperature, isNull);
      expect(stats.humidity!.mean, 50);
      expect(stats.airQuality!.min, 800);
      expect(stats.airQuality!.max, 900);
    });

    test('reports an empty window without inventing values', () {
      final stats = computeHistoryStats24h(records: const [], now: now);

      expect(stats.sampleCount, 0);
      expect(stats.isEmpty, isTrue);
      expect(stats.isSparse, isFalse);
      expect(stats.temperature, isNull);
      expect(stats.humidity, isNull);
      expect(stats.airQuality, isNull);
      expect(stats.windowStart, isNull);
    });

    test('records the earliest timestamp in the window', () {
      final earliest = now.subtract(const Duration(hours: 5));
      final stats = computeHistoryStats24h(
        records: [
          record('a', now.subtract(const Duration(hours: 2)), temperature: 20),
          record('b', earliest, temperature: 21),
          record('c', now, temperature: 22),
        ],
        now: now,
      );

      expect(stats.windowStart, earliest);
    });

    test('is sparse only for a small non-empty window', () {
      final six = computeHistoryStats24h(
        records: List.generate(
          6,
          (i) => record(
            'r$i',
            now.subtract(Duration(minutes: i * 10)),
            temperature: 25,
          ),
        ),
        now: now,
      );

      expect(six.isSparse, isFalse);
      expect(six.sampleCount, 6);
    });
  });
}
