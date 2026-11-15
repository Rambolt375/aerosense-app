import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/forecast/preventive_decision.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';
import 'package:aerosense_app/features/forecast/sinusoidal_fit.dart';

DiurnalModel _createModel({
  double peakSeconds = 14 * 3600.0, // 14:00
  double amplitude = 500.0,
  double c = 1000.0, // Peak = 1500 (>= caution threshold 1400)
  bool hasClearDailyPattern = true,
  double effectiveThreshold = 30.0,
}) {
  return DiurnalModel(
    coefficients: DiurnalCoefficients(
      a: amplitude,
      b: 0.0,
      c: c,
      amplitude: amplitude,
      phase: 0.0,
      peakSeconds: peakSeconds,
    ),
    residualStdDev: 10.0,
    effectiveThreshold: effectiveThreshold,
    hasClearDailyPattern: hasClearDailyPattern,
    rSquared: 0.6,
  );
}

void main() {
  group('shouldTriggerPreventive & evaluatePreventiveDecision', () {
    final defaultModel = _createModel();
    final defaultClock = DateTime(2026, 11, 15, 13, 45); // 15 min before 14:00

    test('returns off state when allowPreventive is false', () {
      final decision = evaluatePreventiveDecision(
        allowPreventive: false,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: defaultModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: null,
        lastTriggeredPeakTime: null,
        clock: () => defaultClock,
      );

      expect(decision.canTrigger, isFalse);
      expect(decision.uiState, equals(PreventiveUiState.off));
      expect(
        shouldTriggerPreventive(
          allowPreventive: false,
          aqGateStatus: MetricGateStatus.active,
          hasClearDailyPattern: true,
          aqModel: defaultModel,
          cautionThreshold: Thresholds.airQualityCautionMin,
          isDeviceOnline: true,
          currentTier: Tier.safe,
          isPreventiveTriggerActive: false,
          isManualToggleActive: false,
          isFanRunning: false,
          lastTriggerTime: null,
          lastTriggeredPeakTime: null,
          clock: () => defaultClock,
        ),
        isFalse,
      );
    });

    test('returns unavailable when device is offline', () {
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: defaultModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: false,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: null,
        lastTriggeredPeakTime: null,
        clock: () => defaultClock,
      );

      expect(decision.canTrigger, isFalse);
      expect(decision.uiState, equals(PreventiveUiState.unavailable));
      expect(decision.reason, contains('offline'));
    });

    test('returns unavailable when current tier is Danger', () {
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: defaultModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.danger,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: null,
        lastTriggeredPeakTime: null,
        clock: () => defaultClock,
      );

      expect(decision.canTrigger, isFalse);
      expect(decision.uiState, equals(PreventiveUiState.unavailable));
      expect(decision.reason, contains('Safety override active'));
    });

    test(
      'returns running state when a trigger, manual run, or fan is active',
      () {
        for (final activeState in [
          (trigger: true, manual: false, fan: false),
          (trigger: false, manual: true, fan: false),
          (trigger: false, manual: false, fan: true),
        ]) {
          final decision = evaluatePreventiveDecision(
            allowPreventive: true,
            aqGateStatus: MetricGateStatus.active,
            hasClearDailyPattern: true,
            aqModel: defaultModel,
            cautionThreshold: Thresholds.airQualityCautionMin,
            isDeviceOnline: true,
            currentTier: Tier.safe,
            isPreventiveTriggerActive: activeState.trigger,
            isManualToggleActive: activeState.manual,
            isFanRunning: activeState.fan,
            lastTriggerTime: null,
            lastTriggeredPeakTime: null,
            clock: () => defaultClock,
          );

          expect(decision.canTrigger, isFalse);
          expect(decision.uiState, equals(PreventiveUiState.running));
        }
      },
    );

    test('returns unavailable when air quality gate is not Active', () {
      final gateStatuses = [
        (MetricGateStatus.lockedOut, 'locked out'),
        (MetricGateStatus.learning, 'learning'),
        (MetricGateStatus.waitingForTimestamps, 'timestamps'),
        (MetricGateStatus.noClearPattern, 'pattern'),
      ];

      for (final (status, reasonKeyword) in gateStatuses) {
        final decision = evaluatePreventiveDecision(
          allowPreventive: true,
          aqGateStatus: status,
          hasClearDailyPattern: status != MetricGateStatus.noClearPattern,
          aqModel: defaultModel,
          cautionThreshold: Thresholds.airQualityCautionMin,
          isDeviceOnline: true,
          currentTier: Tier.safe,
          isPreventiveTriggerActive: false,
          isManualToggleActive: false,
          isFanRunning: false,
          lastTriggerTime: null,
          lastTriggeredPeakTime: null,
          clock: () => defaultClock,
        );

        expect(decision.canTrigger, isFalse);
        expect(decision.uiState, equals(PreventiveUiState.unavailable));
        expect(decision.reason?.toLowerCase(), contains(reasonKeyword));
      }
    });

    test('returns unavailable when hasClearDailyPattern is false', () {
      final modelWithoutPattern = _createModel(hasClearDailyPattern: false);
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: false,
        aqModel: modelWithoutPattern,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: null,
        lastTriggeredPeakTime: null,
        clock: () => defaultClock,
      );

      expect(decision.canTrigger, isFalse);
      expect(decision.uiState, equals(PreventiveUiState.unavailable));
      expect(decision.reason, contains('No clear daily pattern'));
    });

    test(
      'returns unavailable when predicted peak is below Caution threshold',
      () {
        // Peak = C + A = 600 + 100 = 700 (< 1400)
        final lowPeakModel = _createModel(c: 600.0, amplitude: 100.0);
        final decision = evaluatePreventiveDecision(
          allowPreventive: true,
          aqGateStatus: MetricGateStatus.active,
          hasClearDailyPattern: true,
          aqModel: lowPeakModel,
          cautionThreshold: Thresholds.airQualityCautionMin,
          isDeviceOnline: true,
          currentTier: Tier.safe,
          isPreventiveTriggerActive: false,
          isManualToggleActive: false,
          isFanRunning: false,
          lastTriggerTime: null,
          lastTriggeredPeakTime: null,
          clock: () => defaultClock,
        );

        expect(decision.canTrigger, isFalse);
        expect(decision.uiState, equals(PreventiveUiState.unavailable));
        expect(decision.reason, contains('below stuffy threshold'));
      },
    );

    test('arms and triggers when 10 to 20 minutes before predicted peak', () {
      // Peak is 14:00. Test at 13:45 (15 min before) -> in window
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: defaultModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: null,
        lastTriggeredPeakTime: null,
        clock: () => DateTime(2026, 11, 15, 13, 45),
      );

      expect(decision.canTrigger, isTrue);
      expect(decision.uiState, equals(PreventiveUiState.armed));
      expect(decision.nextPeakTime, equals(DateTime(2026, 11, 15, 14, 0)));
      expect(
        decision.nextPlannedRunTime,
        equals(DateTime(2026, 11, 15, 13, 45)),
      );
    });

    test('arms without triggering when outside 10-20 min window', () {
      // Peak is 14:00. At 13:20 (40 min before) -> armed, but cannot trigger yet
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: defaultModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: null,
        lastTriggeredPeakTime: null,
        clock: () => DateTime(2026, 11, 15, 13, 20),
      );

      expect(decision.canTrigger, isFalse);
      expect(decision.uiState, equals(PreventiveUiState.armed));
      expect(
        decision.nextPlannedRunTime,
        equals(DateTime(2026, 11, 15, 13, 45)),
      );
    });

    test('prevents duplicate trigger for the same peak', () {
      final peakTime = DateTime(2026, 11, 15, 14, 0);
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: defaultModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: DateTime(2026, 11, 15, 13, 45),
        lastTriggeredPeakTime: peakTime,
        clock: () =>
            DateTime(2026, 11, 15, 13, 48), // 3 min later, still in window
      );

      expect(decision.canTrigger, isFalse);
      // Next planned run should advance to tomorrow's peak
      expect(decision.nextPeakTime, equals(DateTime(2026, 11, 16, 14, 0)));
      expect(decision.uiState, equals(PreventiveUiState.armed));
    });

    test('enforces cooldown between triggers', () {
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: defaultModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: DateTime(
          2026,
          11,
          15,
          12,
          0,
        ), // 1h 45m ago (< 6h cooldown)
        lastTriggeredPeakTime: DateTime(
          2026,
          11,
          14,
          14,
          0,
        ), // Yesterday's peak
        clock: () => DateTime(2026, 11, 15, 13, 45),
      );

      expect(decision.canTrigger, isFalse);
      expect(decision.uiState, equals(PreventiveUiState.unavailable));
      expect(decision.reason, contains('Cooldown'));
    });

    test('handles midnight wrapping correctly', () {
      // Peak at 00:15. Now is 23:59 on previous day (16 min before peak)
      final midnightModel = _createModel(peakSeconds: 15 * 60.0); // 00:15
      final decision = evaluatePreventiveDecision(
        allowPreventive: true,
        aqGateStatus: MetricGateStatus.active,
        hasClearDailyPattern: true,
        aqModel: midnightModel,
        cautionThreshold: Thresholds.airQualityCautionMin,
        isDeviceOnline: true,
        currentTier: Tier.safe,
        isPreventiveTriggerActive: false,
        isManualToggleActive: false,
        isFanRunning: false,
        lastTriggerTime: null,
        lastTriggeredPeakTime: null,
        clock: () => DateTime(2026, 11, 15, 23, 59),
      );

      expect(decision.canTrigger, isTrue);
      expect(decision.uiState, equals(PreventiveUiState.armed));
      expect(decision.nextPeakTime, equals(DateTime(2026, 11, 16, 0, 15)));
    });
  });
}
