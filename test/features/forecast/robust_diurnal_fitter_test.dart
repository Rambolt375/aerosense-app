import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';

void main() {
  group('RobustDiurnalFitter - 1.4826*MAD filtering & data gate', () {
    test('outlier cluster test: 1.4826*MAD rejects a large outlier cluster (day-long event)', () {
      const trueA = 4.0;
      const trueC = 25.0;
      const truePhi = -0.75 * math.pi;
      const omega = 2 * math.pi / 86400.0;

      final rand = math.Random(101);
      final records = <HistoryRecord>[];
      final start = DateTime(2026, 11, 1, 0, 0);

      // 7 days = 2016 records (every 5 minutes)
      // Day 3 (indices 576 to 864, 288 samples = 24-hour day-long anomaly)
      // has a massive spike of +20.0 degrees (e.g. sensor placed near heater)
      for (var i = 0; i < 2016; i++) {
        final dt = start.add(Duration(minutes: 5 * i));
        final sec = dt.hour * 3600.0 + dt.minute * 60.0 + dt.second;
        final noise = (rand.nextDouble() - 0.5) * 0.4;
        var y = trueA * math.sin(omega * sec + truePhi) + trueC + noise;

        if (i >= 576 && i < 864) {
          // Day-long outlier cluster
          y += 20.0;
        }

        records.add(
          HistoryRecord(
            pushKey: 'key-$i',
            timestamp: dt,
            temperature: y,
            airQuality: 500.0,
          ),
        );
      }

      final result = fitRobustDiurnal(
        records: records,
        extractor: (r) => r.temperature,
        noiseFloor: AppConfig.minTempTolerance,
      );

      expect(result.status, equals(DiurnalFitStatus.ready));
      expect(result.model, isNotNull);
      final model = result.model!;

      // Wave parameters should match true values despite the day-long anomaly
      expect(model.amplitude, closeTo(trueA, 0.25));
      expect(model.c, closeTo(trueC, 0.25));
      expect(model.phase, closeTo(truePhi, 0.1));

      // Residual stddev should reflect the true noise floor (~0.12 C), not the +20 C anomaly
      expect(model.residualStdDev, lessThan(0.5));
    });

    test(
      'refuses to fit synthetic timestamps: returns waitingForTimestamps',
      () {
        final records = <HistoryRecord>[
          for (var i = 0; i < 300; i++)
            HistoryRecord(
              pushKey: 'key-$i',
              timestamp: null, // Forces synthetic resolution
              temperature: 24.0,
            ),
        ];

        final result = fitRobustDiurnal(
          records: records,
          extractor: (r) => r.temperature,
          noiseFloor: AppConfig.minTempTolerance,
        );

        expect(result.status, equals(DiurnalFitStatus.waitingForTimestamps));
        expect(result.model, isNull);
      },
    );

    test('learning status when span < 24 h or coverage < 20 hourly bins', () {
      final start = DateTime(2026, 11, 1, 10, 0);

      // Only 3 hours of data (36 samples)
      final shortRecords = <HistoryRecord>[
        for (var i = 0; i < 36; i++)
          HistoryRecord(
            pushKey: 'key-$i',
            timestamp: start.add(Duration(minutes: 5 * i)),
            temperature: 24.0 + i * 0.1,
          ),
      ];

      // In production mode (isDemo = false): requires 24 h span and 20 hourly bins
      final resultProd = fitRobustDiurnal(
        records: shortRecords,
        extractor: (r) => r.temperature,
        noiseFloor: AppConfig.minTempTolerance,
        isDemo: false,
      );
      expect(resultProd.status, equals(DiurnalFitStatus.learning));
      expect(resultProd.learningPercentage, inInclusiveRange(0, 99));

      // But in demo mode (isDemo = true), short-history threshold (36 points) is permitted
      final resultDemo = fitRobustDiurnal(
        records: shortRecords,
        extractor: (r) => r.temperature,
        noiseFloor: AppConfig.minTempTolerance,
        isDemo: true,
      );
      expect(resultDemo.status, isNot(DiurnalFitStatus.learning));
    });

    test('pure noise yields noClearPattern (R^2 < minR2Pattern)', () {
      final rand = math.Random(42);
      final start = DateTime(2026, 11, 1, 0, 0);

      // Pure uniform white noise across 576 points (2 full days)
      final records = <HistoryRecord>[
        for (var i = 0; i < AppConfig.minForecastPoints; i++)
          HistoryRecord(
            pushKey: 'key-$i',
            timestamp: start.add(Duration(minutes: 5 * i)),
            temperature: 25.0 + (rand.nextDouble() - 0.5) * 4.0,
          ),
      ];

      final result = fitRobustDiurnal(
        records: records,
        extractor: (r) => r.temperature,
        noiseFloor: AppConfig.minTempTolerance,
        isDemo: false,
      );

      expect(result.status, equals(DiurnalFitStatus.ready));
      expect(result.model, isNotNull);
      expect(result.model!.hasClearDailyPattern, isFalse);
      expect(result.model!.rSquared, lessThan(AppConfig.minR2Pattern));
      expect(result.model!.formattedPeakTime, isNull);
    });

    test(
      'strong diurnal wave yields clear daily pattern (R^2 >= minR2Pattern)',
      () {
        const trueA = 3.0;
        const trueC = 25.0;
        const truePhi = -0.5 * math.pi;
        const omega = 2 * math.pi / 86400.0;

        final rand = math.Random(42);
        final start = DateTime(2026, 11, 1, 0, 0);

        final records = <HistoryRecord>[
          for (var i = 0; i < AppConfig.minForecastPoints; i++) ...[
            () {
              final dt = start.add(Duration(minutes: 5 * i));
              final sec = dt.hour * 3600.0 + dt.minute * 60.0 + dt.second;
              final noise = (rand.nextDouble() - 0.5) * 0.2;
              final y = trueA * math.sin(omega * sec + truePhi) + trueC + noise;
              return HistoryRecord(
                pushKey: 'key-$i',
                timestamp: dt,
                temperature: y,
              );
            }(),
          ],
        ];

        final result = fitRobustDiurnal(
          records: records,
          extractor: (r) => r.temperature,
          noiseFloor: AppConfig.minTempTolerance,
          isDemo: false,
        );

        expect(result.status, equals(DiurnalFitStatus.ready));
        expect(result.model, isNotNull);
        expect(result.model!.hasClearDailyPattern, isTrue);
        expect(
          result.model!.rSquared,
          greaterThanOrEqualTo(AppConfig.minR2Pattern),
        );
        expect(result.model!.formattedPeakTime, isNotNull);
      },
    );
  });
}
