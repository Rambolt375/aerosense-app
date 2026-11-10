import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';

/// Single metric history chart card showing temperature, humidity, or air quality.
///
/// Features:
/// - Safe / Medium / Danger horizontal threshold bands at 12% opacity.
/// - 2 px primary line, no area fill, no dots except touched.
/// - Outline-colored grid at 50% opacity.
/// - Legend row (dot + label for Safe, Medium, Danger) and Y-axis threshold labels.
/// - Tooltips on touch and hover.
/// - Break lines across gaps > 15 min using [FlSpot.nullSpot].
/// - Optional [forecastSpots] hook for Phase 5 diurnal prediction series.
/// - Full [Semantics] screen-reader summary label.
class MetricChartCard extends StatelessWidget {
  const MetricChartCard({
    super.key,
    required this.title,
    required this.unit,
    this.caption,
    required this.spots,
    required this.xAxisConfig,
    required this.yBounds,
    required this.semanticsSummary,
    this.fractionDigits = 1,
    this.forecastSpots,
  });

  /// Metric display title (e.g. "Temperature").
  final String title;

  /// Unit string (e.g. "°C", "% RH", "Index").
  final String unit;

  /// Optional caption under title (e.g. "Relative index, uncalibrated").
  final String? caption;

  /// Historical series data points with [FlSpot.nullSpot] for gaps.
  final List<FlSpot> spots;

  /// X-axis time window configuration.
  final XAxisConfig xAxisConfig;

  /// Y-axis limits, threshold boundaries, and step interval.
  final YAxisBounds yBounds;

  /// Screen reader summary for accessibility.
  final String semanticsSummary;

  /// Decimal places for values and tooltips.
  final int fractionDigits;

  /// Optional Phase 5 forecast series hook (dotted line).
  final List<FlSpot>? forecastSpots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColors = context.tierColors;
    final appColors = context.appColors;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    final outlineColor = colorScheme.outline;
    final primaryColor = colorScheme.primary;
    final surfaceAltColor = appColors.surfaceAlt;
    final textSecondary = colorScheme.onSurfaceVariant;
    final textTertiary = appColors.textTertiary;

    final hasData = spots.any((s) => s != FlSpot.nullSpot && !s.y.isNaN);

    return Semantics(
      label: semanticsSummary,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header: Title, Unit, and optional Caption
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(title, style: textTheme.titleMedium),
                  const SizedBox(width: 6),
                  Text(
                    '($unit)',
                    style: textTheme.labelSmall?.copyWith(color: textSecondary),
                  ),
                  const Spacer(),
                  // Legend row (dot + label for Safe, Medium, Danger)
                  _buildLegendRow(context, tierColors),
                ],
              ),
              if (caption != null) ...[
                const SizedBox(height: 2),
                Text(
                  caption!,
                  style: textTheme.bodySmall?.copyWith(
                    color: textSecondary,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              // Chart area
              SizedBox(
                height: 180,
                child: hasData
                    ? LineChart(
                        _buildChartData(
                          theme: theme,
                          tierColors: tierColors,
                          outlineColor: outlineColor,
                          primaryColor: primaryColor,
                          surfaceAltColor: surfaceAltColor,
                          textSecondary: textSecondary,
                          textTertiary: textTertiary,
                        ),
                      )
                    : Center(
                        child: Text(
                          'No readings in this range',
                          style: textTheme.bodyMedium?.copyWith(
                            color: textSecondary,
                          ),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLegendRow(BuildContext context, TierColors tierColors) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _legendDot(tierColors.safe),
        const SizedBox(width: 4),
        Text('Safe', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 10),
        _legendDot(tierColors.medium),
        const SizedBox(width: 4),
        Text('Medium', style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(width: 10),
        _legendDot(tierColors.danger),
        const SizedBox(width: 4),
        Text('Danger', style: Theme.of(context).textTheme.labelSmall),
      ],
    );
  }

  Widget _legendDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }

  LineChartData _buildChartData({
    required ThemeData theme,
    required TierColors tierColors,
    required Color outlineColor,
    required Color primaryColor,
    required Color surfaceAltColor,
    required Color textSecondary,
    required Color textTertiary,
  }) {
    return LineChartData(
      minX: xAxisConfig.minX,
      maxX: xAxisConfig.maxX,
      baselineX: xAxisConfig.baselineX,
      minY: yBounds.minY,
      maxY: yBounds.maxY,
      backgroundColor: surfaceAltColor,
      // Grid lines: outline color at 50% opacity
      gridData: FlGridData(
        show: true,
        drawHorizontalLine: true,
        drawVerticalLine: true,
        horizontalInterval: yBounds.interval,
        verticalInterval: xAxisConfig.interval,
        getDrawingHorizontalLine: (value) =>
            FlLine(color: outlineColor.withValues(alpha: 0.5), strokeWidth: 1),
        getDrawingVerticalLine: (value) =>
            FlLine(color: outlineColor.withValues(alpha: 0.5), strokeWidth: 1),
      ),
      // 1 px outline card border
      borderData: FlBorderData(
        show: true,
        border: Border.all(color: outlineColor, width: 1),
      ),
      // Safe, Medium, Danger horizontal threshold bands at 12% opacity
      rangeAnnotations: RangeAnnotations(
        horizontalRangeAnnotations: [
          // Safe band: [minY, safeMax]
          HorizontalRangeAnnotation(
            y1: yBounds.minY,
            y2: yBounds.safeMax,
            color: tierColors.safe.withValues(alpha: 0.12),
          ),
          // Medium band: [safeMax, dangerMin]
          HorizontalRangeAnnotation(
            y1: yBounds.safeMax,
            y2: yBounds.dangerMin,
            color: tierColors.medium.withValues(alpha: 0.12),
          ),
          // Danger band: [dangerMin, maxY]
          HorizontalRangeAnnotation(
            y1: yBounds.dangerMin,
            y2: yBounds.maxY,
            color: tierColors.danger.withValues(alpha: 0.12),
          ),
        ],
      ),
      // Dotted threshold marker lines on the Y-axis (ensures bands are not color-only)
      extraLinesData: ExtraLinesData(
        horizontalLines: [
          HorizontalLine(
            y: yBounds.safeMax,
            color: tierColors.safe.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              style: theme.textTheme.labelSmall?.copyWith(
                color: tierColors.safe,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              labelResolver: (_) =>
                  '${yBounds.safeMax.toStringAsFixed(fractionDigits)} $unit',
            ),
          ),
          HorizontalLine(
            y: yBounds.dangerMin,
            color: tierColors.danger.withValues(alpha: 0.5),
            strokeWidth: 1,
            dashArray: [4, 4],
            label: HorizontalLineLabel(
              show: true,
              alignment: Alignment.topRight,
              padding: const EdgeInsets.only(right: 6, bottom: 2),
              style: theme.textTheme.labelSmall?.copyWith(
                color: tierColors.danger,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
              labelResolver: (_) =>
                  '${yBounds.dangerMin.toStringAsFixed(fractionDigits)} $unit',
            ),
          ),
        ],
      ),
      // Axis titles
      titlesData: FlTitlesData(
        topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        rightTitles: const AxisTitles(
          sideTitles: SideTitles(showTitles: false),
        ),
        bottomTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 26,
            interval: xAxisConfig.interval,
            getTitlesWidget: (value, meta) {
              final dt = DateTime.fromMillisecondsSinceEpoch(value.toInt());
              return SideTitleWidget(
                meta: meta,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(
                  xAxisConfig.formatDate(dt),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textTertiary,
                  ),
                ),
              );
            },
          ),
        ),
        leftTitles: AxisTitles(
          sideTitles: SideTitles(
            showTitles: true,
            reservedSize: 44,
            interval: yBounds.interval,
            getTitlesWidget: (value, meta) {
              return SideTitleWidget(
                meta: meta,
                fitInside: SideTitleFitInsideData.fromTitleMeta(meta),
                child: Text(
                  value.toStringAsFixed(fractionDigits),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: textTertiary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
              );
            },
          ),
        ),
      ),
      // Tooltips on touch and hover
      lineTouchData: LineTouchData(
        enabled: true,
        handleBuiltInTouches: true,
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (_) => theme.colorScheme.surface,
          tooltipBorder: BorderSide(color: outlineColor, width: 1),
          tooltipPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          fitInsideHorizontally: true,
          fitInsideVertically: true,
          getTooltipItems: (touchedSpots) {
            return touchedSpots.map((barSpot) {
              if (barSpot.isNull() || barSpot.y.isNaN) {
                return null;
              }
              final time = DateTime.fromMillisecondsSinceEpoch(
                barSpot.x.toInt(),
              );
              final timeStr = DateFormat('HH:mm:ss').format(time);
              final valStr = barSpot.y.toStringAsFixed(fractionDigits);
              return LineTooltipItem(
                '$valStr $unit\n',
                theme.textTheme.bodyMedium!.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.onSurface,
                ),
                children: [
                  TextSpan(
                    text: timeStr,
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: textSecondary,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        ),
      ),
      // Line series: 2 px primary line, no area fill
      lineBarsData: [
        LineChartBarData(
          spots: spots,
          isCurved: false,
          barWidth: 2,
          color: primaryColor,
          dotData: const FlDotData(show: false),
          belowBarData: BarAreaData(show: false),
        ),
        // Phase 5 Forecast hook: optional dotted series
        if (forecastSpots != null && forecastSpots!.isNotEmpty)
          LineChartBarData(
            spots: forecastSpots!,
            isCurved: true,
            barWidth: 2,
            color: textSecondary,
            dashArray: [4, 4],
            dotData: const FlDotData(show: false),
            belowBarData: BarAreaData(show: false),
          ),
      ],
    );
  }
}
