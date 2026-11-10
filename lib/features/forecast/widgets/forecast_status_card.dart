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
    final gate = ref.watch(forecastGateNotifierProvider);
    final fitState = ref.watch(diurnalFitProvider);

    final theme = Theme.of(context);
    final tierColors = context.tierColors;
    final appColors = context.appColors;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final overallStatus = gate.status;
    final explanation = gate.statusExplanation;

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

            // Per-metric status pills row
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _buildMetricPill(
                  context: context,
                  tracker: gate.tempGate,
                  fitResult: fitState.temperatureResult,
                  tierColors: tierColors,
                  appColors: appColors,
                ),
                _buildMetricPill(
                  context: context,
                  tracker: gate.aqGate,
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
    required MetricGateTracker tracker,
    required DiurnalFitResult fitResult,
    required TierColors tierColors,
    required AppColors appColors,
  }) {
    final Color dotColor;
    final String statusText;

    switch (tracker.status) {
      case MetricGateStatus.active:
        dotColor = tierColors.safe;
        statusText = 'Active';
        break;
      case MetricGateStatus.lockedOut:
        dotColor = tierColors.medium;
        final h = tracker.consecutiveInTolerance;
        statusText = 'Locked out ($h/3)';
        break;
      case MetricGateStatus.learning:
        dotColor = appColors.textTertiary;
        statusText = 'Learning (${fitResult.learningPercentage}%)';
        break;
      case MetricGateStatus.waitingForTimestamps:
        dotColor = tierColors.medium;
        statusText = 'No timestamps';
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
            '${tracker.metricName}: $statusText',
            style: Theme.of(context).textTheme.labelSmall
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictedPeaks({
    required BuildContext context,
    required DiurnalFitState fitState,
    required ColorScheme colorScheme,
    required TextTheme textTheme,
  }) {
    final tempModel = fitState.temperatureResult.model;
    final aqModel = fitState.airQualityResult.model;

    final String tempText;
    if (tempModel == null) {
      tempText = 'Temperature: accumulating data...';
    } else if (!tempModel.hasClearDailyPattern ||
        tempModel.formattedPeakTime == null) {
      tempText = 'Temperature: no clear daily pattern';
    } else {
      final peakVal = (tempModel.c + tempModel.amplitude).toStringAsFixed(1);
      tempText =
          'Predicted temperature peak: ~${tempModel.formattedPeakTime} ($peakVal °C)';
    }

    final String aqText;
    if (aqModel == null) {
      aqText = 'Air quality: accumulating data...';
    } else if (!aqModel.hasClearDailyPattern ||
        aqModel.formattedPeakTime == null) {
      aqText = 'Air quality: no clear daily pattern';
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
