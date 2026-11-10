import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/features/forecast/sinusoidal_fit.dart';

void main() {
  group('SinusoidalFit - Pure Dart least-squares solver', () {
    test(
      'recovers known A, C, phi from synthetic wave with noise (seeded)',
      () {
        const trueA = 3.5;
        const trueC = 27.0;
        const truePhi = 1.15; // radians
        const omega = 2 * math.pi / 86400.0;

        final rand = math.Random(42);
        final times = <double>[];
        final values = <double>[];

        // 288 samples (every 5 min over 24 h)
        for (var i = 0; i < 288; i++) {
          final t = i * 300.0; // seconds
          final noise = (rand.nextDouble() - 0.5) * 0.4; // +/- 0.2
          final y = trueA * math.sin(omega * t + truePhi) + trueC + noise;
          times.add(t);
          values.add(y);
        }

        final fit = fitSinusoid(times, values);
        expect(fit, isNotNull);
        expect(fit!.amplitude, closeTo(trueA, 0.15));
        expect(fit.c, closeTo(trueC, 0.15));
        expect(fit.phase, closeTo(truePhi, 0.08));
      },
    );

    test('peak time is correct for known sinusoidal wave', () {
      // Wave with peak at 15:00 (15 * 3600 = 54000 seconds)
      // omega * t + phi = pi/2 at t = 54000
      // 2*pi/86400 * 54000 = 1.25 pi
      // 1.25 pi + phi = 0.5 pi -> phi = -0.75 pi
      const omega = 2 * math.pi / 86400.0;
      final truePhi = -0.75 * math.pi;
      const trueA = 5.0;
      const trueC = 25.0;

      final times = <double>[];
      final values = <double>[];
      for (var i = 0; i < 288; i++) {
        final t = i * 300.0;
        final y = trueA * math.sin(omega * t + truePhi) + trueC;
        times.add(t);
        values.add(y);
      }

      final fit = fitSinusoid(times, values);
      expect(fit, isNotNull);
      expect(fit!.peakSeconds, closeTo(54000.0, 1.0));
      expect(fit.formattedPeakTime, equals('15:00'));
    });

    test('wrap-around peak test: peak just after midnight (00:30, t=1800s, negative phi)', () {
      // Peak at 00:30 -> t = 1800 s
      // omega * 1800 = 2*pi * 1800 / 86400 = pi / 24
      // pi/24 + phi = pi/2 -> phi = 11*pi / 24
      const omega = 2 * math.pi / 86400.0;
      final truePhi = 11 * math.pi / 24.0;
      const trueA = 4.0;
      const trueC = 20.0;

      final times = <double>[];
      final values = <double>[];
      for (var i = 0; i < 288; i++) {
        final t = i * 300.0;
        final y = trueA * math.sin(omega * t + truePhi) + trueC;
        times.add(t);
        values.add(y);
      }

      final fit = fitSinusoid(times, values);
      expect(fit, isNotNull);
      expect(fit!.peakSeconds, closeTo(1800.0, 1.0));
      expect(fit.formattedPeakTime, equals('00:30'));
    });

    test(
      'wrap-around peak test: peak just before midnight (23:45, t=85500s)',
      () {
        // Peak at 23:45 -> t = 85500 s
        const omega = 2 * math.pi / 86400.0;
        // omega * 85500 = 2*pi * 85500/86400 = 1.9791667 pi
        // 1.9791667 pi + phi = 0.5 pi -> phi = -1.4791667 pi -> +0.5208333 pi
        final times = <double>[];
        final values = <double>[];
        for (var i = 0; i < 288; i++) {
          final t = i * 300.0;
          final y = 2.0 * math.sin(omega * (t - 85500.0) + math.pi / 2) + 22.0;
          times.add(t);
          values.add(y);
        }

        final fit = fitSinusoid(times, values);
        expect(fit, isNotNull);
        expect(fit!.peakSeconds, closeTo(85500.0, 1.0));
        expect(fit.formattedPeakTime, equals('23:45'));
      },
    );

    test(
      'singular / ill-conditioned input handled safely without throwing',
      () {
        // 1. Fewer than 3 points
        expect(fitSinusoid([100.0, 200.0], [20.0, 21.0]), isNull);

        // 2. All points at exact same time of day
        expect(
          fitSinusoid([500.0, 500.0, 500.0, 500.0], [20.0, 21.0, 22.0, 23.0]),
          isNull,
        );

        // 3. Constant flat line: a ~ 0, b ~ 0, A < 1e-4 -> handles without throwing
        final flatFit = fitSinusoid(
          [0.0, 28800.0, 57600.0],
          [24.0, 24.0, 24.0],
        );
        expect(flatFit, isNotNull);
        expect(flatFit!.amplitude, closeTo(0.0, 1e-6));
        expect(flatFit.c, closeTo(24.0, 1e-6));

        // 4. Empty input
        expect(fitSinusoid([], []), isNull);
      },
    );

    test('relative singular threshold rejects near-degenerate systems', () {
      // Points clustered within 1 microsecond of each other
      final fit = fitSinusoid(
        [100.0, 100.000000001, 100.000000002],
        [20.0, 21.0, 22.0],
        relativeSingularThreshold: 1e-6,
      );
      expect(fit, isNull);
    });

    test(
      'secondsSinceMidnight uses DateTime own fields independent of timezone',
      () {
        final dt = DateTime(2026, 11, 10, 14, 30, 45, 500);
        final sec = secondsSinceMidnight(dt);
        expect(sec, equals(14 * 3600 + 30 * 60 + 45 + 0.5));
      },
    );
  });
}
