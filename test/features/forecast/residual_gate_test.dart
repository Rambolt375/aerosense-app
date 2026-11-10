import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';
import 'package:aerosense_app/features/forecast/sinusoidal_fit.dart';

void main() {
  group('ResidualGate - Hysteresis, per-metric state, tolerance floors', () {
    late DiurnalModel tempModel;
    late DiurnalModel aqModel;

    setUp(() {
      // Model with C = 25.0, a = 0, b = 0 (flat 25.0 for predictable test math)
      tempModel = DiurnalModel(
        coefficients: const DiurnalCoefficients(
          a: 0.0,
          b: 0.0,
          c: 25.0,
          amplitude: 0.0,
          phase: 0.0,
          peakSeconds: 0.0,
        ),
        residualStdDev: 0.1, // 3 * 0.1 = 0.3, but floor is 0.5 C -> effective threshold = 0.5 C
        effectiveThreshold: 0.5,
        hasClearDailyPattern: true,
      );

      // AQ model with C = 600, residualStdDev = 5.0 -> 3 * 5 = 15, floor is 30 -> effective = 30
      aqModel = DiurnalModel(
        coefficients: const DiurnalCoefficients(
          a: 0.0,
          b: 0.0,
          c: 600.0,
          amplitude: 0.0,
          phase: 0.0,
          peakSeconds: 0.0,
        ),
        residualStdDev: 5.0,
        effectiveThreshold: 30.0,
        hasClearDailyPattern: true,
      );
    });

    test('initial state after a fit appears is lockedOut with 0 consecutive samples', () {
      final gate = ForecastGate(tempModel: tempModel, aqModel: aqModel);

      expect(gate.status, equals(ForecastGateStatus.lockedOut));
      expect(gate.tempGate.status, equals(MetricGateStatus.lockedOut));
      expect(gate.tempGate.consecutiveInTolerance, equals(0));
      expect(gate.aqGate.status, equals(MetricGateStatus.lockedOut));
      expect(gate.aqGate.consecutiveInTolerance, equals(0));
    });

    test('hysteresis: requires 3 consecutive in-tolerance samples to become Active', () {
      final gate = ForecastGate(tempModel: tempModel, aqModel: aqModel);
      final t = DateTime(2026, 11, 10, 12, 0);

      // Sample 1: in tolerance (E_temp = 0.2 <= 0.5, E_aq = 10 <= 30)
      gate.processSample(temperature: 25.2, airQuality: 610.0, time: t);
      expect(gate.tempGate.consecutiveInTolerance, equals(1));
      expect(gate.tempGate.status, equals(MetricGateStatus.lockedOut));
      expect(gate.status, equals(ForecastGateStatus.lockedOut));

      // Sample 2: in tolerance
      gate.processSample(temperature: 25.3, airQuality: 605.0, time: t);
      expect(gate.tempGate.consecutiveInTolerance, equals(2));
      expect(gate.tempGate.status, equals(MetricGateStatus.lockedOut));
      expect(gate.status, equals(ForecastGateStatus.lockedOut));

      // Sample 3: in tolerance -> transitions to Active!
      gate.processSample(temperature: 24.9, airQuality: 595.0, time: t);
      expect(gate.tempGate.consecutiveInTolerance, equals(3));
      expect(gate.tempGate.status, equals(MetricGateStatus.active));
      expect(gate.aqGate.status, equals(MetricGateStatus.active));
      expect(gate.status, equals(ForecastGateStatus.active));
    });

    test('immediate lockout on spike, and re-spike resets consecutive counter to 0', () {
      final gate = ForecastGate(tempModel: tempModel, aqModel: aqModel);
      final t = DateTime(2026, 11, 10, 12, 0);

      // Reach active state first (3 good samples)
      gate.processSample(temperature: 25.1, airQuality: 600.0, time: t);
      gate.processSample(temperature: 25.1, airQuality: 600.0, time: t);
      gate.processSample(temperature: 25.1, airQuality: 600.0, time: t);
      expect(gate.status, equals(ForecastGateStatus.active));

      // Sudden smoke spike in air quality (AQ = 800 -> E = 200 > 30)
      gate.processSample(temperature: 25.1, airQuality: 800.0, time: t);
      expect(gate.aqGate.status, equals(MetricGateStatus.lockedOut));
      expect(gate.tempGate.status, equals(MetricGateStatus.active));
      // Overall gate is lockedOut because worst state wins
      expect(gate.status, equals(ForecastGateStatus.lockedOut));
      expect(gate.aqGate.consecutiveInTolerance, equals(0));

      // 2 good samples
      gate.processSample(temperature: 25.1, airQuality: 610.0, time: t);
      expect(gate.aqGate.consecutiveInTolerance, equals(1));
      gate.processSample(temperature: 25.1, airQuality: 610.0, time: t);
      expect(gate.aqGate.consecutiveInTolerance, equals(2));
      expect(gate.aqGate.status, equals(MetricGateStatus.lockedOut));

      // An out-of-tolerance sample resets counter to 0
      gate.processSample(temperature: 25.1, airQuality: 650.0, time: t);
      expect(gate.aqGate.consecutiveInTolerance, equals(0));
      expect(gate.aqGate.status, equals(MetricGateStatus.lockedOut));
    });

    test('skips live samples with null values without changing state', () {
      final gate = ForecastGate(tempModel: tempModel, aqModel: aqModel);
      final t = DateTime(2026, 11, 10, 12, 0);

      gate.processSample(temperature: 25.1, airQuality: 600.0, time: t);
      expect(gate.tempGate.consecutiveInTolerance, equals(1));

      // Live sample with null temperature
      gate.processSample(temperature: null, airQuality: 600.0, time: t);
      expect(gate.tempGate.consecutiveInTolerance, equals(1));
      expect(gate.aqGate.consecutiveInTolerance, equals(2));

      // Live sample with null airQuality
      gate.processSample(temperature: 25.1, airQuality: null, time: t);
      expect(gate.tempGate.consecutiveInTolerance, equals(2));
      expect(gate.aqGate.consecutiveInTolerance, equals(2));
    });

    test('respects DHT22 0.5 C floor and AQ floor in effectiveThreshold', () {
      // Temp model with tiny stddev (0.01 C)
      final tinyTempModel = DiurnalModel(
        coefficients: const DiurnalCoefficients(
          a: 0.0,
          b: 0.0,
          c: 25.0,
          amplitude: 0.0,
          phase: 0.0,
          peakSeconds: 0.0,
        ),
        residualStdDev: 0.01,
        effectiveThreshold: 0.5, // Floor enforced
        hasClearDailyPattern: true,
      );

      final gate = ForecastGate(tempModel: tinyTempModel, aqModel: aqModel);
      final t = DateTime(2026, 11, 10, 12, 0);

      // An error of 0.4 C is greater than 3*0.01 = 0.03, but within floor 0.5 C
      gate.processSample(temperature: 25.4, airQuality: 600.0, time: t);
      expect(gate.tempGate.consecutiveInTolerance, equals(1));
    });

    test(
      'refit with near-identical model keeps Active and preserves counter',
      () {
        final gate = ForecastGate(tempModel: tempModel, aqModel: aqModel);
        final t = DateTime(2026, 11, 10, 12, 0);

        // Transition to Active with 3 samples
        for (var i = 0; i < 3; i++) {
          gate.processSample(temperature: 25.1, airQuality: 600.0, time: t);
        }
        expect(gate.tempGate.status, equals(MetricGateStatus.active));
        expect(gate.tempGate.consecutiveInTolerance, equals(3));

        // Near-identical model: C changes from 25.0 to 25.1
        // Diff at t is |25.1 - 25.0| = 0.1 <= 0.5 * 0.5 = 0.25
        final nearIdenticalTemp = DiurnalModel(
          coefficients: const DiurnalCoefficients(
            a: 0.0,
            b: 0.0,
            c: 25.1,
            amplitude: 0.0,
            phase: 0.0,
            peakSeconds: 0.0,
          ),
          residualStdDev: 0.1,
          effectiveThreshold: 0.5,
          hasClearDailyPattern: true,
        );

        gate.tempGate.updateModel(nearIdenticalTemp, now: t);
        expect(gate.tempGate.status, equals(MetricGateStatus.active));
        expect(gate.tempGate.consecutiveInTolerance, equals(3));
        expect(gate.tempGate.model, equals(nearIdenticalTemp));
      },
    );

    test(
      'refit with materially different model locks out and resets counter',
      () {
        final gate = ForecastGate(tempModel: tempModel, aqModel: aqModel);
        final t = DateTime(2026, 11, 10, 12, 0);

        // Transition to Active with 3 samples
        for (var i = 0; i < 3; i++) {
          gate.processSample(temperature: 25.1, airQuality: 600.0, time: t);
        }
        expect(gate.tempGate.status, equals(MetricGateStatus.active));
        expect(gate.tempGate.consecutiveInTolerance, equals(3));

        // Materially different model: C changes from 25.0 to 25.6
        // Diff at t is |25.6 - 25.0| = 0.6 > 0.5 * 0.5 = 0.25
        final materiallyDifferentTemp = DiurnalModel(
          coefficients: const DiurnalCoefficients(
            a: 0.0,
            b: 0.0,
            c: 25.6,
            amplitude: 0.0,
            phase: 0.0,
            peakSeconds: 0.0,
          ),
          residualStdDev: 0.1,
          effectiveThreshold: 0.5,
          hasClearDailyPattern: true,
        );

        gate.tempGate.updateModel(materiallyDifferentTemp, now: t);
        expect(gate.tempGate.status, equals(MetricGateStatus.lockedOut));
        expect(gate.tempGate.consecutiveInTolerance, equals(0));
        expect(gate.tempGate.model, equals(materiallyDifferentTemp));
      },
    );

    test(
      'noClearPattern state is not active and ignores hysteresis transitions',
      () {
        final noiseModel = DiurnalModel(
          coefficients: const DiurnalCoefficients(
            a: 0.0,
            b: 0.0,
            c: 25.0,
            amplitude: 0.0,
            phase: 0.0,
            peakSeconds: 0.0,
          ),
          residualStdDev: 2.0,
          effectiveThreshold: 6.0,
          hasClearDailyPattern: false, // R^2 < minR2Pattern
        );

        final gate = ForecastGate(tempModel: noiseModel, aqModel: aqModel);
        expect(gate.tempGate.status, equals(MetricGateStatus.noClearPattern));
        expect(gate.status, equals(ForecastGateStatus.lockedOut));

        final t = DateTime(2026, 11, 10, 12, 0);
        // Even with 5 in-tolerance samples, remains noClearPattern
        for (var i = 0; i < 5; i++) {
          gate.processSample(temperature: 25.0, airQuality: 600.0, time: t);
        }

        expect(gate.tempGate.status, equals(MetricGateStatus.noClearPattern));
        expect(gate.tempGate.consecutiveInTolerance, equals(0));
        expect(gate.status, equals(ForecastGateStatus.lockedOut));
      },
    );
  });
}
