import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';

/// Forecast Status Card displaying diurnal model confidence, per-metric status
/// pills, predicted daily peak times, and live residual errors.
///
/// Follows DESIGN.md §5:
/// - 0 elevation, 1 px outline border.
/// - Overall status pill (Active / Locked out / Learning / Waiting for timestamps).
/// - Exact explanation text for locked out state.
/// - Metric status pills for Temperature and Air Quality.
/// - Plain text predicted daily peak times (or "No clear daily pattern").
class ForecastStatusCard extends ConsumerWidget {
  const ForecastStatusCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Uses select so this card doesn't repaint unless status or counters change (Review fix 3)
    final overallStatus = ref.watch(
      forecastGateNotifierProvider.select((g) => g.status),
    );
    final explanation = ref.watch(
      forecastGateNotifierProvider.select((g) => g.statusExplanation),
    );
    final tempStatus = ref.watch(
      forecastGateNotifierProvider.select((g) => g.tempGate.status),
    );
    final tempConsecutive = ref.watch(
      forecastGateNotifierProvider.select(
        (g) => g.tempGate.consecutiveInTolerance,
      ),
    );
    final aqStatus = ref.watch(
      forecastGateNotifierProvider.select((g) => g.aqGate.status),
    );
    final aqConsecutive = ref.watch(
      forecastGateNotifierProvider.select(
        (g) => g.aqGate.consecutiveInTolerance,
      ),
    );
    final fitState = ref.watch(diurnalFitProvider);

    final theme = Theme.of(context);
    final tierColors = context.tierColors;
    final appColors = context.appColors;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Overall Status Pill
            Row(
              children: [
                Text('Forecast status', style: textTheme.titleMedium),
                const Spacer(),
                _buildOverallPill(context, overallStatus, fitState, tierColors),
              ],
            ),
            const SizedBox(height: 8),

            // One line of explanation
            Text(
              explanation,
              style: textTheme.bodyMedium?.copyWith(
                color: overallStatus == ForecastGateStatus.lockedOut
                    ? tierColors.medium
                    : colorScheme.onSurfaceVariant,
                fontWeight: overallStatus == ForecastGateStatus.lockedOut
                    ? FontWeight.w500
                    : FontWeight.w400,
              ),
            ),
            const SizedBox(height: 12),

            // Per-metric status pills row using each metric's own gate status
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricPill(
                  context: context,
                  metricName: 'Temperature',
                  status: tempStatus,
                  consecutiveInTolerance: tempConsecutive,
                  fitResult: fitState.temperatureResult,
                  tierColors: tierColors,
                  appColors: appColors,
                ),
                _buildMetricPill(
                  context: context,
                  metricName: 'Air Quality',
                  status: aqStatus,
                  consecutiveInTolerance: aqConsecutive,
                  fitResult: fitState.airQualityResult,
                  tierColors: tierColors,
                  appColors: appColors,
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(height: 1),
            const SizedBox(height: 12),

            // Predicted Daily Peak Times Section
            _buildPredictedPeaks(
              context: context,
              tempStatus: tempStatus,
              aqStatus: aqStatus,
              fitState: fitState,
              colorScheme: colorScheme,
              textTheme: textTheme,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallPill(
    BuildContext context,
    ForecastGateStatus status,
    DiurnalFitState fitState,
    TierColors tierColors,
  ) {
    final Color bgColor;
    final Color fgColor;
    final IconData icon;
    final String label;

    switch (status) {
      case ForecastGateStatus.active:
        bgColor = tierColors.safeContainer;
        fgColor = tierColors.safe;
        icon = Icons.check_circle_outline;
        label = 'Active';
        break;
      case ForecastGateStatus.lockedOut:
        bgColor = tierColors.mediumContainer;
        fgColor = tierColors.medium;
        icon = Icons.warning_amber_rounded;
        label = 'Locked out';
        break;
      case ForecastGateStatus.learning:
        bgColor = Theme.of(context).colorScheme.surfaceContainerHighest;
        fgColor = Theme.of(context).colorScheme.onSurfaceVariant;
        icon = Icons.hourglass_empty_rounded;
        final pct = fitState.temperatureResult.learningPercentage;
        label = 'Learning ($pct%)';
        break;
      case ForecastGateStatus.waitingForTimestamps:
        bgColor = tierColors.mediumContainer;
        fgColor = tierColors.medium;
        icon = Icons.access_time_rounded;
        label = 'Waiting for timestamps';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: fgColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: fgColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: fgColor,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricPill({
    required BuildContext context,
    required String metricName,
    required MetricGateStatus status,
    required int consecutiveInTolerance,
    required DiurnalFitResult fitResult,
    required TierColors tierColors,
    required AppColors appColors,
  }) {
    final Color dotColor;
    final String statusText;

    switch (status) {
      case MetricGateStatus.active:
        dotColor = tierColors.safe;
        statusText = 'Active';
        break;
      case MetricGateStatus.lockedOut:
        dotColor = tierColors.medium;
        statusText = 'Locked out ($consecutiveInTolerance/3)';
        break;
      case MetricGateStatus.learning:
        dotColor = appColors.textTertiary;
        statusText = 'Learning (${fitResult.learningPercentage}%)';
        break;
      case MetricGateStatus.waitingForTimestamps:
        dotColor = tierColors.medium;
        statusText = 'No timestamps';
        break;
      case MetricGateStatus.noClearPattern:
        dotColor = appColors.textTertiary;
        statusText = 'No daily pattern';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: appColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: dotColor, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            '$metricName: $statusText',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictedPeaks({
    required BuildContext context,
    required MetricGateStatus tempStatus,
    required MetricGateStatus aqStatus,
    required DiurnalFitState fitState,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final tempModel = fitState.temperatureResult.model;
    final aqModel = fitState.airQualityResult.model;

    final String tempText;
    if (tempStatus == MetricGateStatus.noClearPattern ||
        tempModel == null ||
        !tempModel.hasClearDailyPattern ||
        tempModel.formattedPeakTime == null) {
      if (tempStatus == MetricGateStatus.noClearPattern ||
          (tempModel != null && !tempModel.hasClearDailyPattern)) {
        tempText = 'Temperature: no clear daily pattern';
      } else if (tempStatus == MetricGateStatus.waitingForTimestamps) {
        tempText = 'Temperature: waiting for timestamps';
      } else {
        tempText = 'Temperature: accumulating data...';
      }
    } else {
      final peakVal = (tempModel.c + tempModel.amplitude).toStringAsFixed(1);
      tempText =
          'Predicted temperature peak: ~${tempModel.formattedPeakTime} ($peakVal °C)';
    }

    final String aqText;
    if (aqStatus == MetricGateStatus.noClearPattern ||
        aqModel == null ||
        !aqModel.hasClearDailyPattern ||
        aqModel.formattedPeakTime == null) {
      if (aqStatus == MetricGateStatus.noClearPattern ||
          (aqModel != null && !aqModel.hasClearDailyPattern)) {
        aqText = 'Air quality: no clear daily pattern';
      } else if (aqStatus == MetricGateStatus.waitingForTimestamps) {
        aqText = 'Air quality: waiting for timestamps';
      } else {
        aqText = 'Air quality: accumulating data...';
      }
    } else {
      final peakVal = (aqModel.c + aqModel.amplitude).round();
      aqText =
          'Predicted air quality peak: ~${aqModel.formattedPeakTime} (index $peakVal)';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.thermostat_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                tempText,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Icon(
              Icons.air_outlined,
              size: 16,
              color: colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                aqText,
                style: textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
