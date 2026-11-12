/// Pure Dart chart label collision detection and layout utilities.
///
/// Contains zero Flutter widget dependencies to allow direct pure Dart testing.
library;

/// Calculates vertical pixel distance between two Y values in the given visual domain.
double calculatePixelDistanceY({
  required double y1,
  required double y2,
  required double minY,
  required double maxY,
  double chartHeightPx = 154.0,
}) {
  final span = maxY - minY;
  if (span <= 0) return 0.0;
  return ((y1 - y2).abs() / span) * chartHeightPx;
}

/// Filters candidate Y-axis tick values to avoid visual collisions:
/// 1. Ticks within [minSpacingPx] (~14 px) of ANY threshold line are dropped
///    (the threshold label is preserved as it indicates safety limits).
/// 2. Ticks within [minSpacingPx] (~14 px) of an adjacent visible tick are dropped.
List<double> filterVisibleYAxisTicks({
  required List<double> candidateTicks,
  required List<double> thresholds,
  required double minY,
  required double maxY,
  double chartHeightPx = 154.0,
  double minSpacingPx = 14.0,
}) {
  if (maxY <= minY || candidateTicks.isEmpty) return const [];

  final sortedTicks = List<double>.from(candidateTicks)..sort();
  final visible = <double>[];

  for (final tick in sortedTicks) {
    // Check distance to any threshold label
    var collidesWithThreshold = false;
    for (final th in thresholds) {
      final distPx = calculatePixelDistanceY(
        y1: tick,
        y2: th,
        minY: minY,
        maxY: maxY,
        chartHeightPx: chartHeightPx,
      );
      if (distPx < minSpacingPx) {
        collidesWithThreshold = true;
        break;
      }
    }
    if (collidesWithThreshold) continue;

    // Check distance to previously accepted tick
    if (visible.isNotEmpty) {
      final distPrevPx = calculatePixelDistanceY(
        y1: tick,
        y2: visible.last,
        minY: minY,
        maxY: maxY,
        chartHeightPx: chartHeightPx,
      );
      if (distPrevPx < minSpacingPx) {
        continue;
      }
    }

    visible.add(tick);
  }

  return visible;
}

/// Placement for a threshold line label relative to its horizontal line.
enum ThresholdLabelVerticalPosition { aboveLine, belowLine }

/// Configuration for drawing a single threshold line's label.
class ThresholdLineLabelConfig {
  const ThresholdLineLabelConfig({
    required this.verticalPosition,
    this.horizontalOffsetPx = 6.0,
  });

  final ThresholdLabelVerticalPosition verticalPosition;
  final double horizontalOffsetPx;
}

/// Result of layout resolution for Safe and Danger threshold line labels.
class ThresholdLabelsLayout {
  const ThresholdLabelsLayout({
    required this.safeMaxConfig,
    required this.dangerMinConfig,
    required this.isStackedOrOffset,
    required this.pixelDistance,
  });

  final ThresholdLineLabelConfig safeMaxConfig;
  final ThresholdLineLabelConfig dangerMinConfig;
  final bool isStackedOrOffset;
  final double pixelDistance;
}

/// Resolves threshold label placement to prevent overlapping when threshold lines
/// are closer than [minSpacingPx] (~14 px) apart (e.g. temperature 33.5 and 36.0).
///
/// When closer than [minSpacingPx]:
/// - Danger label sits above the line.
/// - Safe label sits below the line.
/// This vertically stacks the labels with the full line separation between them.
ThresholdLabelsLayout resolveThresholdLabelsLayout({
  required double safeMax,
  required double dangerMin,
  required double minY,
  required double maxY,
  double chartHeightPx = 154.0,
  double minSpacingPx = 14.0,
}) {
  final distPx = calculatePixelDistanceY(
    y1: safeMax,
    y2: dangerMin,
    minY: minY,
    maxY: maxY,
    chartHeightPx: chartHeightPx,
  );

  if (distPx < minSpacingPx) {
    return ThresholdLabelsLayout(
      safeMaxConfig: const ThresholdLineLabelConfig(
        verticalPosition: ThresholdLabelVerticalPosition.belowLine,
        horizontalOffsetPx: 6.0,
      ),
      dangerMinConfig: const ThresholdLineLabelConfig(
        verticalPosition: ThresholdLabelVerticalPosition.aboveLine,
        horizontalOffsetPx: 6.0,
      ),
      isStackedOrOffset: true,
      pixelDistance: distPx,
    );
  }

  return ThresholdLabelsLayout(
    safeMaxConfig: const ThresholdLineLabelConfig(
      verticalPosition: ThresholdLabelVerticalPosition.aboveLine,
      horizontalOffsetPx: 6.0,
    ),
    dangerMinConfig: const ThresholdLineLabelConfig(
      verticalPosition: ThresholdLabelVerticalPosition.aboveLine,
      horizontalOffsetPx: 6.0,
    ),
    isStackedOrOffset: false,
    pixelDistance: distPx,
  );
}

/// Selected X-axis tick with formatted string and visual pixel coordinate.
class XAxisSelectedTick {
  const XAxisSelectedTick({
    required this.value,
    required this.label,
    required this.pixelX,
  });

  final double value;
  final String label;
  final double pixelX;
}

/// Selects and deduplicates X-axis ticks to prevent visual collisions.
///
/// Rules:
/// 1. Dedupes identical formatted labels (e.g. "Thu 12" formatted twice).
/// 2. Drops the last tick if it is within [labelWidthPx] of the previous tick.
/// 3. Drops any candidate tick that is closer than [labelWidthPx] to the previous tick.
List<XAxisSelectedTick> selectXAxisTicks({
  required List<double> candidateTicks,
  required double minX,
  required double maxX,
  required String Function(DateTime) formatDate,
  double chartWidthPx = 350.0,
  double labelWidthPx = 45.0,
}) {
  if (maxX <= minX || candidateTicks.isEmpty) return const [];

  final sorted = List<double>.from(candidateTicks)..sort();
  final result = <XAxisSelectedTick>[];

  for (final tick in sorted) {
    if (tick < minX - 1.0 || tick > maxX + 1.0) continue;

    final dt = DateTime.fromMillisecondsSinceEpoch(tick.toInt());
    final label = formatDate(dt);
    final px = ((tick - minX) / (maxX - minX)) * chartWidthPx;

    // Rule 1: Dedupe identical labels
    if (result.isNotEmpty && result.last.label == label) {
      continue;
    }

    // Rule 2 & 3: Distance from previous accepted tick
    if (result.isNotEmpty) {
      final distPrev = px - result.last.pixelX;
      if (distPrev < labelWidthPx) {
        continue;
      }
    }

    result.add(XAxisSelectedTick(value: tick, label: label, pixelX: px));
  }

  // Safety check on last element vs second to last
  if (result.length >= 2) {
    final last = result.last;
    final secondLast = result[result.length - 2];
    if ((last.pixelX - secondLast.pixelX) < labelWidthPx) {
      result.removeLast();
    }
  }

  return result;
}
