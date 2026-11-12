import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:aerosense_app/features/history/chart_label_utils.dart';

void main() {
  group('Requirement 3a: Y-axis tick selection and collision avoidance', () {
    test('drops ticks within ~14 px of a threshold label (temperature 35 vs 33.5 & 36.0)', () {
      // Temperature range: 20 to 40 °C (span 20 °C)
      // Chart height: 154 px -> 7.7 px / °C
      // Thresholds: safeMax = 33.5, dangerMin = 36.0
      // Distance of 35.0 to 36.0 is 1.0 °C = 7.7 px (< 14 px) -> COLLISION!
      // Distance of 35.0 to 33.5 is 1.5 °C = 11.55 px (< 14 px) -> COLLISION!
      final candidateTicks = [20.0, 25.0, 30.0, 35.0, 40.0];
      final thresholds = [33.5, 36.0];

      final visible = filterVisibleYAxisTicks(
        candidateTicks: candidateTicks,
        thresholds: thresholds,
        minY: 20.0,
        maxY: 40.0,
        chartHeightPx: 154.0,
        minSpacingPx: 14.0,
      );

      // Tick 35.0 must be dropped; 20, 25, 30, 40 kept
      expect(
        visible.contains(35.0),
        isFalse,
        reason: 'Tick 35.0 must be dropped due to proximity to 36.0 and 33.5',
      );
      expect(visible, [20.0, 25.0, 30.0, 40.0]);
    });

    test('drops ticks within ~14 px of each other', () {
      // Ticks at 20.0, 21.0, 35.0 on a 0..100 range with 150 px height (1.5 px / unit)
      // 21.0 is 1.5 px from 20.0 (< 14 px) -> dropped
      // 35.0 is 22.5 px from 20.0 (> 14 px) -> kept
      final candidateTicks = [20.0, 21.0, 35.0];
      final visible = filterVisibleYAxisTicks(
        candidateTicks: candidateTicks,
        thresholds: const [],
        minY: 0.0,
        maxY: 100.0,
        chartHeightPx: 150.0,
        minSpacingPx: 14.0,
      );

      expect(visible, [20.0, 35.0]);
    });

    test(
      'keeps all ticks when sufficiently spaced and far from thresholds',
      () {
        final candidateTicks = [0.0, 20.0, 40.0, 80.0, 100.0];
        final thresholds = [60.0]; // 60.0 is 20 units away = 30 px > 14 px

        final visible = filterVisibleYAxisTicks(
          candidateTicks: candidateTicks,
          thresholds: thresholds,
          minY: 0.0,
          maxY: 100.0,
          chartHeightPx: 150.0,
          minSpacingPx: 14.0,
        );

        expect(visible, candidateTicks);
      },
    );
  });

  group('Requirement 3b: Threshold label layout stacking and offset', () {
    test('stacks threshold labels when closer than ~14 px (temperature 33.5 and 36.0)', () {
      // Temperature range: 20 to 45 °C (span 25 °C)
      // Chart height: 154 px -> 6.16 px / °C
      // Distance between 33.5 and 36.0: 2.5 °C * 6.16 px/°C = 15.4 px
      // In a span of 30 °C (e.g. 15 to 45): 2.5 * (154/30) = 12.8 px (< 14 px!)
      final layout = resolveThresholdLabelsLayout(
        safeMax: 33.5,
        dangerMin: 36.0,
        minY: 15.0,
        maxY: 45.0,
        chartHeightPx: 154.0,
        minSpacingPx: 14.0,
      );

      expect(layout.isStackedOrOffset, isTrue);
      // Higher line (dangerMin) is positioned above line
      expect(
        layout.dangerMinConfig.verticalPosition,
        ThresholdLabelVerticalPosition.aboveLine,
      );
      // Lower line (safeMax) is stacked below line
      expect(
        layout.safeMaxConfig.verticalPosition,
        ThresholdLabelVerticalPosition.belowLine,
      );
    });

    test('does not stack threshold labels when sufficiently spaced (humidity 60 and 75)', () {
      // Humidity range: 0 to 100 % RH
      // Chart height: 154 px
      // Distance between 60 and 75: 15 * 1.54 = 23.1 px (> 14 px)
      final layout = resolveThresholdLabelsLayout(
        safeMax: 60.0,
        dangerMin: 75.0,
        minY: 0.0,
        maxY: 100.0,
        chartHeightPx: 154.0,
        minSpacingPx: 14.0,
      );

      expect(layout.isStackedOrOffset, isFalse);
      expect(
        layout.dangerMinConfig.verticalPosition,
        ThresholdLabelVerticalPosition.aboveLine,
      );
      expect(
        layout.safeMaxConfig.verticalPosition,
        ThresholdLabelVerticalPosition.aboveLine,
      );
    });
  });

  group('Requirement 3c: X-axis label deduplication and tick dropping', () {
    final dayFormat = DateFormat('EEE d');

    test(
      'deduplicates identical formatted labels ("Thu 12" printed twice)',
      () {
        // Two ticks on the same day: 00:00 and 14:00
        final t1 = DateTime(
          2026,
          11,
          12,
          0,
          0,
        ).millisecondsSinceEpoch.toDouble();
        final t2 = DateTime(
          2026,
          11,
          12,
          14,
          0,
        ).millisecondsSinceEpoch.toDouble();
        final t3 = DateTime(
          2026,
          11,
          13,
          0,
          0,
        ).millisecondsSinceEpoch.toDouble();

        final ticks = [t1, t2, t3];
        final minX = t1;
        final maxX = t3;

        final selected = selectXAxisTicks(
          candidateTicks: ticks,
          minX: minX,
          maxX: maxX,
          formatDate: (dt) => dayFormat.format(dt),
          chartWidthPx: 350.0,
          labelWidthPx: 45.0,
        );

        final labels = selected.map((s) => s.label).toList();
        // Should not contain duplicate "Thu 12"
        expect(labels.where((l) => l == 'Thu 12').length, 1);
        expect(labels, ['Thu 12', 'Fri 13']);
      },
    );

    test(
      'drops the last tick if it is within a label width of the previous one',
      () {
        // 7-day range: 7 days of midnight ticks, plus maxX at 04:00 on the last day
        final start = DateTime(2026, 11, 5, 0, 0);
        final candidateTicks = <double>[];
        for (var d = 0; d < 7; d++) {
          candidateTicks.add(
            start.add(Duration(days: d)).millisecondsSinceEpoch.toDouble(),
          );
        }
        // Add a trailing tick only 2 hours after the previous tick (within label width)
        final lastMidnight = candidateTicks.last;
        final trailingTick = lastMidnight + (2 * 60 * 60 * 1000.0);
        candidateTicks.add(trailingTick);

        final minX = candidateTicks.first;
        final maxX = trailingTick;

        final selected = selectXAxisTicks(
          candidateTicks: candidateTicks,
          minX: minX,
          maxX: maxX,
          formatDate: (dt) => dayFormat.format(dt),
          chartWidthPx: 350.0,
          labelWidthPx: 45.0,
        );

        // Trailing tick must be dropped
        expect(selected.map((s) => s.value).contains(trailingTick), isFalse);
        expect(selected.length, 7);
      },
    );
  });
}
