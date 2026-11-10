import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/features/forecast/widgets/forecast_status_card.dart';
import 'package:aerosense_app/features/history/history_notifier.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';
import 'package:aerosense_app/features/history/widgets/chart_skeleton.dart';
import 'package:aerosense_app/features/history/widgets/history_error_card.dart';
import 'package:aerosense_app/features/history/widgets/metric_chart_card.dart';
import 'package:aerosense_app/features/history/widgets/range_selector.dart';
import 'package:aerosense_app/shared/empty_state.dart';

/// Historical telemetry charts screen (PRD §FR-5).
///
/// Shows three synchronized line charts (temperature, humidity, air quality)
/// with Safe / Medium / Danger threshold bands, 1h / 6h / 24h / 7d range selection,
/// gap detection (> 15 min), and LTTB downsampling for 7d view.
class HistoryScreen extends ConsumerWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chartDataAsync = ref.watch(historyChartDataProvider);
    final selectedRange = ref.watch(selectedRangeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final isWide = constraints.maxWidth >= 900;
          return Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: isWide ? 1200 : double.infinity,
              ),
              child: RefreshIndicator(
                onRefresh: () =>
                    ref.read(historyNotifierProvider.notifier).retry(),
                child: chartDataAsync.when(
                  loading: () => _buildLoadingState(selectedRange),
                  error: (error, _) => HistoryErrorCard(
                    onRetry: () =>
                        ref.read(historyNotifierProvider.notifier).retry(),
                  ),
                  data: (data) => _buildDataState(context, ref, data),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildLoadingState(HistoryRange selectedRange) {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        Center(
          child: RangeSelector(selected: selectedRange, onSelected: (_) {}),
        ),
        const SizedBox(height: 16),
        const ChartSkeleton(),
        const SizedBox(height: 16),
        const ChartSkeleton(),
        const SizedBox(height: 16),
        const ChartSkeleton(),
      ],
    );
  }

  Widget _buildDataState(
    BuildContext context,
    WidgetRef ref,
    HistoryChartData data,
  ) {
    // 1. If repository has 0 records total
    if (!data.hasAnyHistory) {
      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 32),
        children: const [
          EmptyState(
            icon: Icons.history_toggle_off_outlined,
            title: 'No history yet',
            subtitle: 'The device logs every 5 minutes.',
          ),
        ],
      );
    }

    final tierColors = context.tierColors;
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      children: [
        // Range selector
        Center(
          child: RangeSelector(
            selected: data.selectedRange,
            onSelected: (range) =>
                ref.read(selectedRangeProvider.notifier).select(range),
          ),
        ),
        const SizedBox(height: 16),

        // Synthetic timestamp banner (when timestamps were missing from firmware)
        if (data.isSynthetic) ...[
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: tierColors.mediumContainer,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: tierColors.medium, width: 1),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  size: 20,
                  color: tierColors.medium,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    "Time axis is estimated: the device isn't sending timestamps.",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: tierColors.medium,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // 2. If current filtered window has 0 readings
        if (!data.hasRangeReadings) ...[
          const SizedBox(height: 32),
          const EmptyState(
            icon: Icons.filter_alt_off_outlined,
            title: 'No readings in this range',
            subtitle: 'Try selecting a wider time range.',
          ),
        ] else ...[
          // Diurnal forecast confidence & status card
          const ForecastStatusCard(),
          const SizedBox(height: 16),

          // Three synchronized metric charts
          MetricChartCard(
            title: 'Temperature',
            unit: '°C',
            spots: data.temperatureSpots,
            forecastSpots: data.temperatureForecastSpots,
            xAxisConfig: data.xAxisConfig,
            yBounds: data.temperatureYBounds,
            semanticsSummary: data.temperatureSummary,
            fractionDigits: 1,
          ),
          const SizedBox(height: 16),
          MetricChartCard(
            title: 'Humidity',
            unit: '% RH',
            spots: data.humiditySpots,
            xAxisConfig: data.xAxisConfig,
            yBounds: data.humidityYBounds,
            semanticsSummary: data.humiditySummary,
            fractionDigits: 1,
          ),
          const SizedBox(height: 16),
          MetricChartCard(
            title: 'Air quality',
            unit: 'index',
            caption: 'Relative index, uncalibrated',
            spots: data.airQualitySpots,
            forecastSpots: data.airQualityForecastSpots,
            xAxisConfig: data.xAxisConfig,
            yBounds: data.airQualityYBounds,
            semanticsSummary: data.airQualitySummary,
            fractionDigits: 0,
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}
