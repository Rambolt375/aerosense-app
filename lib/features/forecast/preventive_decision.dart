import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';

/// Pre-ventilation operational state for UI presentation (FR-7).
enum PreventiveUiState {
  /// User opt-in is disabled in Settings (`allowPreventive == false`).
  off,

  /// Pre-ventilation is enabled and waiting for the planned lead-time window.
  armed,

  /// Pre-ventilation cycle is currently running (`preventiveTrigger == true` or fan on).
  running,

  /// Pre-ventilation cannot run due to gate status, offline status, or safety override.
  unavailable,
}

/// Result of evaluating pre-ventilation decision rules.
class PreventiveDecision {
  const PreventiveDecision({
    required this.canTrigger,
    required this.uiState,
    this.reason,
    this.nextPeakTime,
    this.nextPlannedRunTime,
    this.predictedPeakValue,
  });

  /// Whether the publishing device should fire `/forecast/preventiveTrigger = true`.
  final bool canTrigger;

  /// High-level UI state (Off, Armed, Running, Unavailable).
  final PreventiveUiState uiState;

  /// Explanatory reason when unavailable or armed.
  final String? reason;

  /// Next calculated air-quality peak time.
  final DateTime? nextPeakTime;

  /// Next scheduled run time (typically 15 min before peak).
  final DateTime? nextPlannedRunTime;

  /// Predicted peak air quality value (C + A).
  final double? predictedPeakValue;
}

/// Evaluates pre-ventilation decision rules and returns a [PreventiveDecision].
///
/// Preconditions for [PreventiveDecision.canTrigger] == true:
/// 1. `allowPreventive == true` (team opt-in in Settings).
/// 2. `isDeviceOnline == true` (freshness check).
/// 3. `currentTier != Tier.danger` (safety override: firmware forced fan on).
/// 4. `!isPreventiveTriggerActive && !isManualToggleActive && !isFanRunning`.
/// 5. Air quality forecast gate is `MetricGateStatus.active`.
/// 6. Air quality model has a clear daily pattern (`hasClearDailyPattern == true`, $R^2 \ge 0.3$).
/// 7. Predicted peak value ($C + A$) is $\ge$ `cautionThreshold` (Thresholds.airQualityCautionMin).
/// 8. Current time is within the lead time window ([leadTimeMin] to [leadTimeMax], default 10-20 min) before next peak.
/// 9. At most one trigger per predicted peak and no active cooldown.
PreventiveDecision evaluatePreventiveDecision({
  required bool allowPreventive,
  required MetricGateStatus aqGateStatus,
  required bool hasClearDailyPattern,
  required DiurnalModel? aqModel,
  required double cautionThreshold,
  required bool isDeviceOnline,
  required Tier currentTier,
  required bool isPreventiveTriggerActive,
  required bool isManualToggleActive,
  required bool isFanRunning,
  required DateTime? lastTriggerTime,
  required DateTime? lastTriggeredPeakTime,
  required DateTime Function() clock,
  Duration leadTimeMin = AppConfig.preventiveLeadTimeMin,
  Duration leadTimeMax = AppConfig.preventiveLeadTimeMax,
  Duration targetLeadTime = AppConfig.preventiveLeadTimeTarget,
  Duration cooldown = AppConfig.preventiveCooldown,
}) {
  // 1. Opt-in gate: user must explicitly enable pre-ventilation in Settings
  if (!allowPreventive) {
    return const PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.off,
      reason: 'Disabled in Settings',
    );
  }

  // 2. Freshness gate: device must be reporting telemetry
  if (!isDeviceOnline) {
    return const PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.unavailable,
      reason: 'Device is offline',
    );
  }

  // 3. Safety gate: Danger tier overrides any predictive automation
  if (currentTier == Tier.danger) {
    return const PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.unavailable,
      reason: 'Safety override active: fan is forced on in Danger tier',
    );
  }

  // 4. Concurrency gate: cannot trigger if fan or another cycle is already active
  if (isPreventiveTriggerActive || isManualToggleActive || isFanRunning) {
    return const PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.running,
      reason: 'Pre-ventilation in progress',
    );
  }

  // 5. Air quality forecast gate
  if (aqGateStatus != MetricGateStatus.active) {
    final String gateReason;
    switch (aqGateStatus) {
      case MetricGateStatus.lockedOut:
        gateReason = 'Air quality forecast locked out';
        break;
      case MetricGateStatus.learning:
        gateReason = 'Air quality forecast is learning';
        break;
      case MetricGateStatus.waitingForTimestamps:
        gateReason = 'Waiting for device timestamps';
        break;
      case MetricGateStatus.noClearPattern:
      case MetricGateStatus.active:
        gateReason = 'No clear daily air quality pattern';
        break;
    }
    return PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.unavailable,
      reason: gateReason,
    );
  }

  // 6. Pattern validation
  if (!hasClearDailyPattern ||
      aqModel == null ||
      !aqModel.hasClearDailyPattern) {
    return const PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.unavailable,
      reason: 'No clear daily pattern',
    );
  }

  // 7. Peak value severity check: ventilation is pointless if air will stay clean
  final predictedPeak = aqModel.c + aqModel.amplitude;
  if (predictedPeak < cautionThreshold) {
    return PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.unavailable,
      reason:
          'Predicted peak (${predictedPeak.toStringAsFixed(0)}) below stuffy threshold (${cautionThreshold.toStringAsFixed(0)})',
      predictedPeakValue: predictedPeak,
    );
  }

  // 8. Next peak time calculation with calendar and midnight wrapping
  final now = clock();
  final peakSeconds = aqModel.coefficients.peakSeconds;
  var candidatePeak = DateTime(
    now.year,
    now.month,
    now.day,
  ).add(Duration(seconds: peakSeconds.round()));

  if (candidatePeak.isBefore(now)) {
    candidatePeak = candidatePeak.add(const Duration(days: 1));
  }

  // Check if today's peak was already triggered
  if (lastTriggeredPeakTime != null &&
      candidatePeak.difference(lastTriggeredPeakTime).abs() <
          const Duration(hours: 12)) {
    candidatePeak = candidatePeak.add(const Duration(days: 1));
    return PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.armed,
      reason: "Pre-ventilation completed for today's peak",
      nextPeakTime: candidatePeak,
      nextPlannedRunTime: candidatePeak.subtract(targetLeadTime),
      predictedPeakValue: predictedPeak,
    );
  }

  // 9. Cooldown enforcement
  if (lastTriggerTime != null && now.difference(lastTriggerTime) < cooldown) {
    return PreventiveDecision(
      canTrigger: false,
      uiState: PreventiveUiState.unavailable,
      reason: 'Cooldown active',
      nextPeakTime: candidatePeak,
      nextPlannedRunTime: candidatePeak.subtract(targetLeadTime),
      predictedPeakValue: predictedPeak,
    );
  }

  // 10. Lead time window check
  final timeToPeak = candidatePeak.difference(now);
  final inWindow = timeToPeak >= leadTimeMin && timeToPeak <= leadTimeMax;
  final plannedRunTime = candidatePeak.subtract(targetLeadTime);

  return PreventiveDecision(
    canTrigger: inWindow,
    uiState: PreventiveUiState.armed,
    nextPeakTime: candidatePeak,
    nextPlannedRunTime: plannedRunTime,
    predictedPeakValue: predictedPeak,
  );
}

/// Pure decision function returning boolean whether a preventive trigger should fire.
bool shouldTriggerPreventive({
  required bool allowPreventive,
  required MetricGateStatus aqGateStatus,
  required bool hasClearDailyPattern,
  required DiurnalModel? aqModel,
  required double cautionThreshold,
  required bool isDeviceOnline,
  required Tier currentTier,
  required bool isPreventiveTriggerActive,
  required bool isManualToggleActive,
  required bool isFanRunning,
  required DateTime? lastTriggerTime,
  required DateTime? lastTriggeredPeakTime,
  required DateTime Function() clock,
  Duration leadTimeMin = AppConfig.preventiveLeadTimeMin,
  Duration leadTimeMax = AppConfig.preventiveLeadTimeMax,
  Duration targetLeadTime = AppConfig.preventiveLeadTimeTarget,
  Duration cooldown = AppConfig.preventiveCooldown,
}) {
  return evaluatePreventiveDecision(
    allowPreventive: allowPreventive,
    aqGateStatus: aqGateStatus,
    hasClearDailyPattern: hasClearDailyPattern,
    aqModel: aqModel,
    cautionThreshold: cautionThreshold,
    isDeviceOnline: isDeviceOnline,
    currentTier: currentTier,
    isPreventiveTriggerActive: isPreventiveTriggerActive,
    isManualToggleActive: isManualToggleActive,
    isFanRunning: isFanRunning,
    lastTriggerTime: lastTriggerTime,
    lastTriggeredPeakTime: lastTriggeredPeakTime,
    clock: clock,
    leadTimeMin: leadTimeMin,
    leadTimeMax: leadTimeMax,
    targetLeadTime: targetLeadTime,
    cooldown: cooldown,
  ).canTrigger;
}
