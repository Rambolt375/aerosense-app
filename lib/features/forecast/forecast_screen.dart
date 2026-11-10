import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
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
    final gate = ref.watch(forecastGateNotifierProvider);
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

                  // 2. Metric Details Cards
                  _buildMetricDetailCard(
                    context: context,
                    title: 'Temperature model',
                    unit: '°C',
                    icon: Icons.thermostat_outlined,
                    model: fitState.temperatureResult.model,
                    tracker: gate.tempGate,
                    fractionDigits: 1,
                  ),
                  const SizedBox(height: 16),
                  _buildMetricDetailCard(
                    context: context,
                    title: 'Air quality model',
                    unit: 'index',
                    icon: Icons.air_outlined,
                    model: fitState.airQualityResult.model,
                    tracker: gate.aqGate,
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
    required dynamic model,
    required dynamic tracker,
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
    final double? lastErr = tracker.lastError;
    final double? liveVal = tracker.lastLiveValue;
    final double? predVal = tracker.lastPredictedValue;

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
                Text(
                  'ŷ = A·sin(ωt+φ) + C',
                  style: textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                  ),
                ),
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

            // Live Diagnostics
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: appColors.surfaceAlt,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Text(
                    'Residual error (E): ',
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    lastErr != null
                        ? '${lastErr.toStringAsFixed(fractionDigits)} $unit'
                        : '--',
                    style: textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  if (liveVal != null && predVal != null)
                    Text(
                      'Live ${liveVal.toStringAsFixed(fractionDigits)} / Pred ${predVal.toStringAsFixed(fractionDigits)} $unit',
                      style: textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
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
