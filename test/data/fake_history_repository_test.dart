import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';

void main() {
  group('FakeHistoryRepository - Deterministic 7-day generator', () {
    final fixedAnchor = DateTime.utc(2026, 11, 10, 14, 37, 22);

    test('rounds anchor to nearest 10-minute boundary', () {
      final rounded = FakeHistoryRepository.roundToTenMinutes(fixedAnchor);
      // 14:37:22 -> rounds down to 14:30:00
      expect(rounded.minute, equals(30));
      expect(rounded.second, equals(0));
      expect(rounded.millisecond, equals(0));
    });

    test('generates exactly 1008 records with 10-minute spacing', () {
      final history = FakeHistoryRepository.generateHistory(
        anchor: fixedAnchor,
        count: 1008,
      );

      expect(history.length, equals(1008));

      // Oldest record at index 0, newest record at index 1007
      final roundedAnchor = FakeHistoryRepository.roundToTenMinutes(
        fixedAnchor,
      );
      expect(history.last.timestamp, equals(roundedAnchor));

      // Verify exact 10-minute spacing (600 seconds) between every consecutive pair
      for (var i = 0; i < history.length - 1; i++) {
        final current = history[i].timestamp!;
        final next = history[i + 1].timestamp!;
        final delta = next.difference(current);
        expect(
          delta.inSeconds,
          equals(600),
          reason: 'Delta between record $i and ${i + 1} must be 600 s',
        );
      }
    });

    test('generation is deterministic with fixed seed', () {
      final run1 = FakeHistoryRepository.generateHistory(
        anchor: fixedAnchor,
        seed: 42,
      );
      final run2 = FakeHistoryRepository.generateHistory(
        anchor: fixedAnchor,
        seed: 42,
      );

      expect(run1.length, equals(run2.length));
      for (var i = 0; i < run1.length; i++) {
        expect(run1[i].temperature, equals(run2[i].temperature));
        expect(run1[i].humidity, equals(run2[i].humidity));
        expect(run1[i].airQuality, equals(run2[i].airQuality));
        expect(run1[i].timestamp, equals(run2[i].timestamp));
      }
    });

    test(
      'includeAnomalies: false keeps values strictly within normal bounds',
      () {
        final history = FakeHistoryRepository.generateHistory(
          anchor: fixedAnchor,
          includeAnomalies: false,
          seed: 42,
        );

        for (final r in history) {
          expect(
            r.airQuality!,
            lessThan(Thresholds.airQualityDangerMin),
            reason:
                'Clean wave should never breach Danger air quality threshold',
          );
          expect(
            r.temperature!,
            lessThan(Thresholds.tempDangerMin),
            reason:
                'Clean wave should never breach Danger temperature threshold',
          );
        }
      },
    );

    test(
      'includeAnomalies: true contains smoke spike and heat spike anomalies',
      () {
        final history = FakeHistoryRepository.generateHistory(
          anchor: fixedAnchor,
          includeAnomalies: true,
          seed: 42,
        );

        final hasSmokeAnomaly = history.any(
          (r) =>
              r.airQuality != null &&
              r.airQuality! > Thresholds.airQualityDangerMin,
        );
        final hasHeatAnomaly = history.any(
          (r) =>
              r.temperature != null &&
              r.temperature! > Thresholds.tempDangerMin,
        );

        expect(
          hasSmokeAnomaly,
          isTrue,
          reason: 'Smoke anomaly must exceed 2000 AQ',
        );
        expect(
          hasHeatAnomaly,
          isTrue,
          reason: 'Heat anomaly must exceed 36.0 °C',
        );
      },
    );

    test('all values stay within physical bounds', () {
      final history = FakeHistoryRepository.generateHistory(
        anchor: fixedAnchor,
        includeAnomalies: true,
        seed: 42,
      );

      for (final r in history) {
        expect(r.temperature, inInclusiveRange(15.0, 45.0));
        expect(r.humidity, inInclusiveRange(10.0, 95.0));
        expect(
          r.airQuality,
          inInclusiveRange(100.0, Thresholds.airQualityAdcMax),
        );
      }
    });

    test('fetchHistory respects limit parameter', () async {
      final repo = FakeHistoryRepository(anchor: fixedAnchor);

      final records24h = await repo.fetchHistory(limit: 144);
      expect(records24h.length, equals(144));

      final recordsAll = await repo.fetchHistory(limit: 3000);
      expect(recordsAll.length, equals(1008));
    });

    test(
      'air quality exhibits diurnal variation with dominant 24-hour wave',
      () {
        final history = FakeHistoryRepository.generateHistory(
          anchor: fixedAnchor,
          includeAnomalies: false,
          seed: 42,
        );

        // Group records by hour of day (0..23) to examine the diurnal shape
        final hourlyAverages = <int, List<double>>{};
        for (final r in history) {
          if (r.timestamp != null && r.airQuality != null) {
            hourlyAverages
                .putIfAbsent(r.timestamp!.hour, () => [])
                .add(r.airQuality!);
          }
        }

        final meanByHour = hourlyAverages.map(
          (hour, values) =>
              MapEntry(hour, values.reduce((a, b) => a + b) / values.length),
        );

        // Evening (18:00 - 20:00) should be noticeably higher than early morning (04:00 - 06:00)
        final eveningMean = meanByHour[19]!;
        final morningMean = meanByHour[5]!;

        expect(
          eveningMean,
          greaterThan(morningMean + 150.0),
          reason: 'Air quality diurnal curve must have dominant evening peak over morning trough',
        );
      },
    );
  });
}
