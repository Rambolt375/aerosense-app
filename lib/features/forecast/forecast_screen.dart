import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';
import 'package:aerosense_app/features/forecast/widgets/forecast_status_card.dart';

/// Diurnal forecasting screen (PRD §FR-6).
///
/// Displays:
/// - [ForecastStatusCard] with overall confidence status, per-metric pills,
///   and predicted daily peak times.
/// - Detailed model parameter cards (mean C, amplitude A, phase phi, residual stddev, live error E).
class ForecastScreen extends ConsumerWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Uses select so widgets do not repaint every 2 s (Review fix 3)
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

    return Scaffold(
      appBar: AppBar(title: const Text('Diurnal Forecast')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1200 : double.infinity,
              ),
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                children: [
                  // 1. Forecast Status Card
                  const ForecastStatusCard(),
                  const SizedBox(height: 16),

                  // 2. Metric Details Cards using each metric's own gate status
                  _buildMetricDetailCard(
                    context: context,
                    title: 'Temperature model',
                    unit: '°C',
                    icon: Icons.thermostat_outlined,
                    model: fitState.temperatureResult.model,
                    status: tempStatus,
                    consecutive: tempConsecutive,
                    fractionDigits: 1,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricDetailCard(
                    context: context,
                    title: 'Air quality model',
                    unit: 'index',
                    icon: Icons.air_outlined,
                    model: fitState.airQualityResult.model,
                    status: aqStatus,
                    consecutive: aqConsecutive,
                    fractionDigits: 0,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMetricDetailCard({
    required BuildContext context,
    required String title,
    required String unit,
    required IconData icon,
    required DiurnalModel? model,
    required MetricGateStatus status,
    required int consecutive,
    required int fractionDigits,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final appColors = context.appColors;
    final colorScheme = theme.colorScheme;

    if (model == null) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Text(title, style: textTheme.titleMedium),
                  const Spacer(),
                  _buildMetricBadge(context, status, consecutive),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Awaiting sufficient history data to fit 24-hour diurnal sinusoidal wave.',
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      );
    }

    final double c = model.c;
    final double amp = model.amplitude;
    final double thresh = model.effectiveThreshold;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: 8),
                Text(title, style: textTheme.titleMedium),
                const Spacer(),
                _buildMetricBadge(context, status, consecutive),
              ],
            ),
            const SizedBox(height: 16),

            // Parameters Table
            Row(
              children: [
                Expanded(
                  child: _buildParameterTile(
                    label: 'Mean (C)',
                    value: '${c.toStringAsFixed(fractionDigits)} $unit',
                    textTheme: textTheme,
                    appColors: appColors,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildParameterTile(
                    label: 'Amplitude (A)',
                    value: '±${amp.toStringAsFixed(fractionDigits)} $unit',
                    textTheme: textTheme,
                    appColors: appColors,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildParameterTile(
                    label: 'Tolerance (3σ)',
                    value: '±${thresh.toStringAsFixed(fractionDigits)} $unit',
                    textTheme: textTheme,
                    appColors: appColors,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Model Formula & Variance Explained
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: appColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'ŷ = A·sin(ωt+φ) + C',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    'Variance explained (R²): ${(model.rSquared * 100).toStringAsFixed(1)}%',
                    style: textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetricBadge(
    BuildContext context,
    MetricGateStatus status,
    int consecutive,
  ) {
    final tierColors = context.tierColors;
    final appColors = context.appColors;
    final Color color;
    final String label;

    switch (status) {
      case MetricGateStatus.active:
        color = tierColors.safe;
        label = 'Active';
        break;
      case MetricGateStatus.lockedOut:
        color = tierColors.medium;
        label = 'Locked out ($consecutive/3)';
        break;
      case MetricGateStatus.learning:
        color = appColors.textTertiary;
        label = 'Learning';
        break;
      case MetricGateStatus.waitingForTimestamps:
        color = tierColors.medium;
        label = 'No timestamps';
        break;
      case MetricGateStatus.noClearPattern:
        color = appColors.textTertiary;
        label = 'No daily pattern';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: appColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildParameterTile({
    required String label,
    required String value,
    required TextTheme textTheme,
    required AppColors appColors,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: appColors.surfaceAlt,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: textTheme.labelSmall?.copyWith(
              color: appColors.textTertiary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
