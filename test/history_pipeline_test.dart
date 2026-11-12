import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/sensor_validation.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';

void main() {
  group('HistoryRange enum (Requirement 1)', () {
    test('defines exact hardware-matched record counts', () {
      expect(HistoryRange.h1.recordCount, 6);
      expect(HistoryRange.h6.recordCount, 36);
      expect(HistoryRange.h24.recordCount, 144);
      expect(HistoryRange.d7.recordCount, 1008);
    });

    test('defines matching durations', () {
      expect(HistoryRange.h1.duration, const Duration(hours: 1));
      expect(HistoryRange.h6.duration, const Duration(hours: 6));
      expect(HistoryRange.h24.duration, const Duration(hours: 24));
      expect(HistoryRange.d7.duration, const Duration(days: 7));
    });
  });

  group('Timestamp resolution & fallback (Requirement 6 & 7)', () {
    final fixedAnchor = DateTime.utc(2026, 11, 10, 12, 0, 0);

    test('empty list returns empty and not synthetic', () {
      final res = resolveTimestamps([]);
      expect(res.records, isEmpty);
      expect(res.isSynthetic, isFalse);
    });

    test(
      'all-null timestamps triggers synthetic 10-minute spacing fallback',
      () {
        final records = [
          const HistoryRecord(pushKey: '-Nx003', temperature: 25.0),
          const HistoryRecord(pushKey: '-Nx001', temperature: 23.0),
          const HistoryRecord(pushKey: '-Nx002', temperature: 24.0),
        ];

        final res = resolveTimestamps(records, clock: () => fixedAnchor);

        expect(res.isSynthetic, isTrue);
        expect(res.records.length, 3);
        // Lexicographically sorted by pushKey: 001, 002, 003
        expect(res.records[0].pushKey, '-Nx001');
        expect(res.records[1].pushKey, '-Nx002');
        expect(res.records[2].pushKey, '-Nx003');

        // 10-minute spacing ending at fixedAnchor
        expect(res.records[2].timestamp, fixedAnchor);
        expect(
          res.records[1].timestamp,
          fixedAnchor.subtract(const Duration(minutes: 10)),
        );
        expect(
          res.records[0].timestamp,
          fixedAnchor.subtract(const Duration(minutes: 20)),
        );
      },
    );

    test(
      'partially-null timestamps drops null records and never mixes synthetic',
      () {
        final t1 = fixedAnchor.subtract(const Duration(minutes: 20));
        final t2 = fixedAnchor.subtract(const Duration(minutes: 10));

        final records = [
          HistoryRecord(pushKey: '-Nx001', timestamp: t1, temperature: 22.0),
          const HistoryRecord(
            pushKey: '-Nx002',
            timestamp: null,
            temperature: 23.0,
          ),
          HistoryRecord(pushKey: '-Nx003', timestamp: t2, temperature: 24.0),
        ];

        final res = resolveTimestamps(records, clock: () => fixedAnchor);

        expect(res.isSynthetic, isFalse);
        expect(res.records.length, 2);
        expect(res.records.map((r) => r.pushKey), ['-Nx001', '-Nx003']);
        expect(res.records[0].timestamp, t1);
        expect(res.records[1].timestamp, t2);
      },
    );

    test('all valid timestamps preserves real timestamps and sorts chronologically', () {
      final t1 = fixedAnchor.subtract(const Duration(minutes: 30));
      final t2 = fixedAnchor.subtract(const Duration(minutes: 15));
      final t3 = fixedAnchor;

      final records = [
        HistoryRecord(pushKey: '-Nx003', timestamp: t3, temperature: 25.0),
        HistoryRecord(pushKey: '-Nx001', timestamp: t1, temperature: 21.0),
        HistoryRecord(pushKey: '-Nx002', timestamp: t2, temperature: 23.0),
      ];

      final res = resolveTimestamps(records, clock: () => fixedAnchor);

      expect(res.isSynthetic, isFalse);
      expect(res.records.length, 3);
      expect(res.records[0].pushKey, '-Nx001');
      expect(res.records[1].pushKey, '-Nx002');
      expect(res.records[2].pushKey, '-Nx003');
    });
  });

  group('filterByRange (Requirement 1 & 7)', () {
    final anchor = DateTime.utc(2026, 11, 10, 12, 0, 0);

    test('filters 7-day dataset down to exact expected record counts', () {
      // 1008 records, 10-minute spacing ending at anchor
      final all = FakeHistoryRepository.generateHistory(
        anchor: anchor,
        count: 1008,
      );

      final h1Records = filterByRange(
        all,
        HistoryRange.h1,
        clock: () => anchor,
      );
      // 1 h contains records from anchor - 1h to anchor.
      // At 10 min intervals: 60 / 10 = 6 intervals -> 6 or 7 points if inclusive
      expect(h1Records.length, anyOf(6, 7));

      final h6Records = filterByRange(
        all,
        HistoryRange.h6,
        clock: () => anchor,
      );
      expect(h6Records.length, anyOf(36, 37));

      final h24Records = filterByRange(
        all,
        HistoryRange.h24,
        clock: () => anchor,
      );
      expect(h24Records.length, anyOf(144, 145));

      final d7Records = filterByRange(
        all,
        HistoryRange.d7,
        clock: () => anchor,
      );
      expect(d7Records.length, 1008);
    });

    test('returns empty list for empty input', () {
      final res = filterByRange([], HistoryRange.h1, clock: () => anchor);
      expect(res, isEmpty);
    });
  });

  group('splitIntoSegments (Requirement 2)', () {
    final base = DateTime.utc(2026, 11, 10, 10, 0, 0);

    test('contiguous 10-minute records result in a single segment', () {
      final records = List.generate(
        10,
        (i) => HistoryRecord(
          pushKey: 'k-$i',
          timestamp: base.add(Duration(minutes: 10 * i)),
          temperature: 24.0,
        ),
      );

      final segments = splitIntoSegments(records);
      expect(segments.length, 1);
      expect(segments.first.length, 10);
    });

    test(
      'gap exceeding 25 minutes (2.5x threshold) splits into multiple segments',
      () {
        final records = [
          HistoryRecord(pushKey: 'k-1', timestamp: base, temperature: 24.0),
          HistoryRecord(
            pushKey: 'k-2',
            timestamp: base.add(const Duration(minutes: 10)),
            temperature: 24.2,
          ),
          // 40-minute offline gap here (> 25 min)
          HistoryRecord(
            pushKey: 'k-3',
            timestamp: base.add(const Duration(minutes: 50)),
            temperature: 25.0,
          ),
          HistoryRecord(
            pushKey: 'k-4',
            timestamp: base.add(const Duration(minutes: 60)),
            temperature: 25.1,
          ),
        ];

        final segments = splitIntoSegments(records);
        expect(segments.length, 2);
        expect(segments[0].length, 2);
        expect(segments[1].length, 2);
        expect(segments[0].last.pushKey, 'k-2');
        expect(segments[1].first.pushKey, 'k-3');
      },
    );

    test('gap exactly 25 minutes does not split', () {
      final records = [
        HistoryRecord(pushKey: 'k-1', timestamp: base, temperature: 24.0),
        HistoryRecord(
          pushKey: 'k-2',
          timestamp: base.add(const Duration(minutes: 25)),
          temperature: 24.5,
        ),
      ];

      final segments = splitIntoSegments(
        records,
        gapThreshold: const Duration(minutes: 25),
      );
      expect(segments.length, 1);
      expect(segments.first.length, 2);
    });
  });

  group('LTTB downsampling & proportional segment joining (Requirement 2)', () {
    test('LTTB strictly retains first and last points', () {
      final spots = List.generate(
        50,
        (i) => FlSpot(i.toDouble(), (i * 2).toDouble()),
      );

      final downsampled = lttb(spots, 10);
      expect(downsampled.length, 10);
      expect(downsampled.first, spots.first);
      expect(downsampled.last, spots.last);
    });

    test('LTTB retains visual peaks (smoke spike)', () {
      final spots = <FlSpot>[];
      for (var i = 0; i < 100; i++) {
        // Baseline 500 with a prominent spike at index 50 to 2800
        final y = (i == 50) ? 2800.0 : 500.0;
        spots.add(FlSpot(i.toDouble(), y));
      }

      final downsampled = lttb(spots, 15);
      final hasPeak = downsampled.any((s) => s.y >= 2500.0);
      expect(hasPeak, isTrue, reason: 'LTTB must retain significant peaks');
    });

    test('downsampleAndJoinSegments downsamples proportionally and inserts nullSpot between segments', () {
      final seg1 = List.generate(
        100,
        (i) => FlSpot(i.toDouble(), 20.0 + (i % 5)),
      );
      final seg2 = List.generate(
        100,
        (i) => FlSpot((200 + i).toDouble(), 25.0 + (i % 5)),
      );

      final joined = downsampleAndJoinSegments([seg1, seg2], targetTotal: 40);

      // Total valid spots should be approximately targetTotal
      final validSpots = joined.where((s) => s != FlSpot.nullSpot).toList();
      expect(validSpots.length, inInclusiveRange(36, 44));

      // There should be exactly one nullSpot separating the two segments
      final nullSpotCount = joined.where((s) => s == FlSpot.nullSpot).length;
      expect(nullSpotCount, 1);

      // Verify nullSpot is located between segment 1 and segment 2
      final nullIndex = joined.indexOf(FlSpot.nullSpot);
      expect(nullIndex, greaterThan(0));
      expect(nullIndex, lessThan(joined.length - 1));
      expect(joined[nullIndex - 1] != FlSpot.nullSpot, isTrue);
      expect(joined[nullIndex + 1] != FlSpot.nullSpot, isTrue);
    });

    test('downsampleAndJoinSegments skips downsampling when total spots <= targetTotal', () {
      final seg1 = [const FlSpot(1, 20), const FlSpot(2, 21)];
      final seg2 = [const FlSpot(10, 22), const FlSpot(11, 23)];

      final joined = downsampleAndJoinSegments([seg1, seg2], targetTotal: 100);

      expect(joined.length, 5); // 2 + nullSpot + 2
      expect(joined[2], FlSpot.nullSpot);
      expect(joined[0].y, 20);
      expect(joined[4].y, 23);
    });
  });

  group('mergeHistoryRecords (Requirement 3)', () {
    final t1 = DateTime.utc(2026, 11, 10, 10, 0, 0);
    final t2 = DateTime.utc(2026, 11, 10, 10, 5, 0);
    final t3 = DateTime.utc(2026, 11, 10, 10, 10, 0);

    test('deduplicates by pushKey when re-emitted', () {
      final existing = [
        HistoryRecord(pushKey: '-Nx01', timestamp: t1, temperature: 24.0),
        HistoryRecord(pushKey: '-Nx02', timestamp: t2, temperature: 24.5),
      ];

      // Re-emit latest record with same pushKey
      final duplicate = HistoryRecord(
        pushKey: '-Nx02',
        timestamp: t2,
        temperature: 24.8,
      );

      final merged = mergeHistoryRecords(existing, duplicate);

      expect(merged.length, 2);
      expect(merged.last.pushKey, '-Nx02');
      expect(merged.last.temperature, 24.8);
    });

    test('appends new record and keeps chronological order', () {
      final existing = [
        HistoryRecord(pushKey: '-Nx01', timestamp: t1, temperature: 24.0),
        HistoryRecord(pushKey: '-Nx03', timestamp: t3, temperature: 25.0),
      ];

      final outOfOrder = HistoryRecord(
        pushKey: '-Nx02',
        timestamp: t2,
        temperature: 24.5,
      );

      final merged = mergeHistoryRecords(existing, outOfOrder);

      expect(merged.length, 3);
      expect(merged[0].pushKey, '-Nx01');
      expect(merged[1].pushKey, '-Nx02');
      expect(merged[2].pushKey, '-Nx03');
    });

    test('caps at maxRecords dropping oldest records', () {
      final existing = List.generate(
        10,
        (i) => HistoryRecord(
          pushKey: 'k-$i',
          timestamp: t1.add(Duration(minutes: 5 * i)),
          temperature: 20.0 + i,
        ),
      );

      final newRecord = HistoryRecord(
        pushKey: 'k-10',
        timestamp: t1.add(const Duration(minutes: 50)),
        temperature: 30.0,
      );

      final merged = mergeHistoryRecords(existing, newRecord, maxRecords: 5);

      expect(merged.length, 5);
      expect(merged.first.pushKey, 'k-6');
      expect(merged.last.pushKey, 'k-10');
    });
  });

  group('Y-axis bounds calculation (Requirement 4)', () {
    test(
      'calculates bounds so Safe, Medium, and Danger bands are always visible',
      () {
        final spots = [const FlSpot(1, 24.0), const FlSpot(2, 26.0)];

        final bounds = calculateYAxisBounds(
          spots: spots,
          safeMax: Thresholds.tempSafeMax, // 33.5
          dangerMin: Thresholds.tempDangerMin, // 36.0
          padding: 2.0,
          interval: 5.0,
        );

        // minY = min(24, 33.5) - 2 = 22 -> floored to interval 5 = 20.0
        expect(bounds.minY, lessThanOrEqualTo(Thresholds.tempSafeMax));
        // maxY = max(26, 36.0) + 2 = 38 -> ceiled to interval 5 = 40.0
        expect(bounds.maxY, greaterThanOrEqualTo(Thresholds.tempDangerMin));

        expect(bounds.minY, 20.0);
        expect(bounds.maxY, 40.0);
      },
    );

    test('respects absoluteMin and absoluteMax for humidity (0 to 100)', () {
      final spots = [const FlSpot(1, 10.0), const FlSpot(2, 95.0)];

      final bounds = calculateYAxisBounds(
        spots: spots,
        safeMax: Thresholds.humiditySafeMax, // 60.0
        dangerMin: Thresholds.humidityDangerMin, // 75.0
        padding: 5.0,
        absoluteMin: 0.0,
        absoluteMax: 100.0,
        interval: 20.0,
      );

      expect(bounds.minY, greaterThanOrEqualTo(0.0));
      expect(bounds.maxY, lessThanOrEqualTo(100.0));
    });

    test('empty spots still keep threshold lines visible within bounds', () {
      final bounds = calculateYAxisBounds(
        spots: const [],
        safeMax: Thresholds.tempSafeMax, // 33.5
        dangerMin: Thresholds.tempDangerMin, // 36.0
        padding: 2.0,
        interval: 5.0,
      );

      expect(bounds.minY, lessThanOrEqualTo(Thresholds.tempSafeMax));
      expect(bounds.maxY, greaterThanOrEqualTo(Thresholds.tempDangerMin));
    });

    test('pipeline validates sensor failures so chart y-range ignores 0/0 unplugged data', () {
      final badRecords = [
        HistoryRecord(
          pushKey: '-Nx01',
          timestamp: DateTime(2026, 11, 12, 12, 0),
          temperature: 25.0,
          humidity: 50.0,
        ),
        HistoryRecord(
          pushKey: '-Nx02',
          timestamp: DateTime(2026, 11, 12, 12, 10),
          temperature: 0.0, // Unplugged DHT22 artifact
          humidity: 0.0,
        ),
        HistoryRecord(
          pushKey: '-Nx03',
          timestamp: DateTime(2026, 11, 12, 12, 20),
          temperature: 999.0, // Electrical spike
          humidity: 52.0,
        ),
        HistoryRecord(
          pushKey: '-Nx04',
          timestamp: DateTime(2026, 11, 12, 12, 30),
          temperature: 26.0,
          humidity: 51.0,
        ),
      ];

      final validatedRecords = validateHistoryRecords(badRecords);
      final spots = segmentToSpots(validatedRecords, (r) => r.temperature);

      expect(
        spots.length,
        2,
        reason: 'Only the two valid records (25.0 and 26.0) produce spots',
      );
      expect(spots.map((s) => s.y), [25.0, 26.0]);

      final bounds = calculateYAxisBounds(
        spots: spots,
        safeMax: Thresholds.tempSafeMax, // 33.5
        dangerMin: Thresholds.tempDangerMin, // 36.0
        padding: 2.0,
        interval: 5.0,
      );

      // minY = min(25.0, 33.5) - 2.0 = 23.0 -> floor to 5 = 20.0
      // If 0.0 was included, minY would be 0.0 - 2.0 -> -5.0!
      expect(bounds.minY, 20.0);
      // maxY = max(26.0, 36.0) + 2.0 = 38.0 -> ceil to 5 = 40.0
      // If 999.0 was included, maxY would be 1005.0!
      expect(bounds.maxY, 40.0);
      expect(bounds.minY, lessThanOrEqualTo(Thresholds.tempSafeMax));
      expect(bounds.maxY, greaterThanOrEqualTo(Thresholds.tempDangerMin));
    });
  });

  group('X-axis configuration (Requirement 8)', () {
    final anchor = DateTime.utc(2026, 11, 10, 14, 23, 45);

    test('1 h range aligns to round 15-minute boundary and formats HH:mm', () {
      final config = calculateXAxisConfig(HistoryRange.h1, clock: () => anchor);
      expect(config.interval, 15 * 60 * 1000.0);

      final dt = DateTime.fromMillisecondsSinceEpoch(config.baselineX.toInt());
      expect(dt.minute % 15, 0);
      expect(config.formatDate(anchor), '14:23');
    });

    test('24 h range aligns to round 4-hour boundary', () {
      final config = calculateXAxisConfig(
        HistoryRange.h24,
        clock: () => anchor,
      );
      expect(config.interval, 4 * 3600 * 1000.0);

      final dt = DateTime.fromMillisecondsSinceEpoch(config.baselineX.toInt());
      expect(dt.hour % 4, 0);
    });

    test('7 d range formats EEE d (e.g. Tue 10)', () {
      final config = calculateXAxisConfig(HistoryRange.d7, clock: () => anchor);
      expect(config.interval, 24 * 3600 * 1000.0);
      expect(config.formatDate(anchor), 'Tue 10');
    });
  });

  group('Semantics summary generator (Requirement 9)', () {
    test('generates comprehensive accessible description', () {
      final spots = [
        const FlSpot(1, 23.5),
        const FlSpot(2, 28.2),
        const FlSpot(3, 25.0),
      ];

      final summary = generateChartSummary(
        metricName: 'Temperature',
        unit: '°C',
        range: HistoryRange.h24,
        spots: spots,
        safeMax: 28.0,
        dangerMin: 32.0,
      );

      expect(summary, contains('Temperature history over the last 24 h'));
      expect(summary, contains('Current: 25.0 °C'));
      expect(summary, contains('Minimum: 23.5 °C'));
      expect(summary, contains('Maximum: 28.2 °C'));
      expect(summary, contains('Safe below 28.0 °C'));
      expect(summary, contains('Danger above 32.0 °C'));
    });

    test('handles empty spots gracefully', () {
      final summary = generateChartSummary(
        metricName: 'Air quality',
        unit: 'index',
        range: HistoryRange.h1,
        spots: [],
        safeMax: 1000.0,
        dangerMin: 2000.0,
      );

      expect(summary, contains('no readings available'));
    });
  });
}
