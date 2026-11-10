import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:aerosense_app/data/models/history_record.dart';

// ---------------------------------------------------------------------------
// HistoryRange enum
// ---------------------------------------------------------------------------

/// Supported time ranges for historical telemetry visualization.
///
/// Hardware sampling rate is 1 record per 5 minutes.
/// - 1 h = 12 records
/// - 6 h = 72 records
/// - 24 h = 288 records (default)
/// - 7 d = 2016 records
enum HistoryRange {
  h1(label: '1 h', duration: Duration(hours: 1), recordCount: 12),
  h6(label: '6 h', duration: Duration(hours: 6), recordCount: 72),
  h24(label: '24 h', duration: Duration(hours: 24), recordCount: 288),
  d7(label: '7 d', duration: Duration(days: 7), recordCount: 2016);

  const HistoryRange({
    required this.label,
    required this.duration,
    required this.recordCount,
  });

  final String label;
  final Duration duration;
  final int recordCount;
}

// ---------------------------------------------------------------------------
// Timestamp resolution and fallback
// ---------------------------------------------------------------------------

/// Result of resolving timestamps across a list of [HistoryRecord]s.
class ResolvedHistory {
  const ResolvedHistory({required this.records, required this.isSynthetic});

  /// Chronologically ordered history records.
  final List<HistoryRecord> records;

  /// Whether timestamps were synthetically generated due to unconfirmed
  /// firmware timestamp formatting.
  final bool isSynthetic;
}

/// Resolves timestamps across a history records list.
///
/// Rules (PRD §5.2 and safety contract):
/// 1. If all records have null timestamps, falls back to pushKey ordering
///    and synthetic 5-minute spacing backwards from [clock]. Flagged as synthetic.
/// 2. If partially null, drops the records with null timestamps and logs a warning.
///    Never mixes real and synthetic timestamps.
/// 3. If all records have valid timestamps, sorts them chronologically.
ResolvedHistory resolveTimestamps(
  List<HistoryRecord> records, {
  DateTime Function()? clock,
}) {
  if (records.isEmpty) {
    return const ResolvedHistory(records: [], isSynthetic: false);
  }

  final nullCount = records.where((r) => r.timestamp == null).length;

  // Case 1: All timestamps are null -> fallback to synthetic spacing
  if (nullCount == records.length) {
    final sortedByPushKey = List<HistoryRecord>.from(records)
      ..sort((a, b) => a.pushKey.compareTo(b.pushKey));

    final now = (clock ?? DateTime.now)();
    final total = sortedByPushKey.length;

    final syntheticRecords = <HistoryRecord>[];
    for (var i = 0; i < total; i++) {
      // 5-minute spacing ending at now
      final syntheticTime = now.subtract(
        Duration(minutes: 5 * (total - 1 - i)),
      );
      syntheticRecords.add(
        sortedByPushKey[i].copyWith(timestamp: syntheticTime),
      );
    }

    debugPrint(
      '[HistoryPipeline] // TODO(confirm): All history timestamps null; '
      'using synthetic 5-minute spacing sorted by pushKey.',
    );
    return ResolvedHistory(records: syntheticRecords, isSynthetic: true);
  }

  // Case 2: Partially null -> drop records with null timestamps
  if (nullCount > 0) {
    debugPrint(
      '[HistoryPipeline] // TODO(confirm): Dropped $nullCount history records '
      'with null timestamps. Never mixing real and synthetic timestamps.',
    );
    final validRecords = records.where((r) => r.timestamp != null).toList()
      ..sort((a, b) {
        final cmp = a.timestamp!.compareTo(b.timestamp!);
        return cmp != 0 ? cmp : a.pushKey.compareTo(b.pushKey);
      });
    return ResolvedHistory(records: validRecords, isSynthetic: false);
  }

  // Case 3: All valid
  final sortedRecords = List<HistoryRecord>.from(records)
    ..sort((a, b) {
      final cmp = a.timestamp!.compareTo(b.timestamp!);
      return cmp != 0 ? cmp : a.pushKey.compareTo(b.pushKey);
    });
  return ResolvedHistory(records: sortedRecords, isSynthetic: false);
}

// ---------------------------------------------------------------------------
// Filtering by Range
// ---------------------------------------------------------------------------

/// Filters [records] to those within the given [range] window relative to [clock].
List<HistoryRecord> filterByRange(
  List<HistoryRecord> records,
  HistoryRange range, {
  DateTime Function()? clock,
}) {
  if (records.isEmpty) return const [];

  final now = (clock ?? DateTime.now)();
  final cutoff = now.subtract(range.duration);

  // Keep records within [cutoff, now + 1 min tolerance]
  final upperLimit = now.add(const Duration(minutes: 1));
  return records.where((r) {
    if (r.timestamp == null) return false;
    return !r.timestamp!.isBefore(cutoff) && !r.timestamp!.isAfter(upperLimit);
  }).toList();
}

// ---------------------------------------------------------------------------
// Live Append & Merge
// ---------------------------------------------------------------------------

/// Merges [newRecord] into [existing] records list.
///
/// Rules:
/// - Dedupes by [pushKey] (e.g. when `onChildAdded(limitToLast(1))` re-emits the latest record).
/// - Keeps chronological order by timestamp (secondary sort by pushKey).
/// - Caps result at [maxRecords] (default 2016 = 7 days), dropping oldest.
List<HistoryRecord> mergeHistoryRecords(
  List<HistoryRecord> existing,
  HistoryRecord newRecord, {
  int maxRecords = 2016,
}) {
  final copy = List<HistoryRecord>.from(existing);
  final existingIndex = copy.indexWhere((r) => r.pushKey == newRecord.pushKey);

  if (existingIndex != -1) {
    // Replace duplicate with newest value
    copy[existingIndex] = newRecord;
  } else {
    copy.add(newRecord);
  }

  // Keep sorted
  copy.sort((a, b) {
    if (a.timestamp != null && b.timestamp != null) {
      final cmp = a.timestamp!.compareTo(b.timestamp!);
      if (cmp != 0) return cmp;
    }
    return a.pushKey.compareTo(b.pushKey);
  });

  // Cap at maxRecords
  if (copy.length > maxRecords) {
    return copy.sublist(copy.length - maxRecords);
  }
  return copy;
}

// ---------------------------------------------------------------------------
// Gap detection & Segment splitting
// ---------------------------------------------------------------------------

/// Splits sorted [records] into contiguous segments.
///
/// Whenever the gap between consecutive records exceeds [gapThreshold]
/// (default 15 minutes, representing missing packets/device offline),
/// a new segment is started.
List<List<HistoryRecord>> splitIntoSegments(
  List<HistoryRecord> records, {
  Duration gapThreshold = const Duration(minutes: 15),
}) {
  if (records.isEmpty) return const [];

  final segments = <List<HistoryRecord>>[];
  var currentSegment = <HistoryRecord>[records.first];

  for (var i = 1; i < records.length; i++) {
    final prev = records[i - 1];
    final curr = records[i];

    if (prev.timestamp != null && curr.timestamp != null) {
      final diff = curr.timestamp!.difference(prev.timestamp!);
      if (diff > gapThreshold) {
        segments.add(currentSegment);
        currentSegment = [curr];
        continue;
      }
    }
    currentSegment.add(curr);
  }

  segments.add(currentSegment);
  return segments;
}

// ---------------------------------------------------------------------------
// Spot conversion
// ---------------------------------------------------------------------------

/// Maps a segment of [records] to [FlSpot]s for a specific sensor field.
List<FlSpot> segmentToSpots(
  List<HistoryRecord> records,
  double? Function(HistoryRecord) extractor,
) {
  final spots = <FlSpot>[];
  for (final record in records) {
    final val = extractor(record);
    if (val != null && record.timestamp != null && !val.isNaN) {
      spots.add(
        FlSpot(record.timestamp!.millisecondsSinceEpoch.toDouble(), val),
      );
    }
  }
  return spots;
}

// ---------------------------------------------------------------------------
// LTTB (Largest-Triangle-Three-Buckets) Downsampling
// ---------------------------------------------------------------------------

/// Downsamples [data] to [threshold] points using Largest-Triangle-Three-Buckets (LTTB).
///
/// Retains the first and last points, and maximizes the triangular area for each
/// intermediate bucket, preserving visible peaks and valleys.
///
/// Precondition: [data] must be contiguous without [FlSpot.nullSpot] markers.
List<FlSpot> lttb(List<FlSpot> data, int threshold) {
  if (data.length <= threshold || threshold < 3) {
    return List<FlSpot>.from(data);
  }

  final sampled = <FlSpot>[];
  // Always add first point
  sampled.add(data.first);

  final bucketSize = (data.length - 2) / (threshold - 2);
  var aIndex = 0;

  for (var i = 0; i < threshold - 2; i++) {
    // Current bucket range
    final rangeStart = (i * bucketSize).floor() + 1;
    final rangeEnd = ((i + 1) * bucketSize).floor() + 1;

    // Next bucket range for centroid average
    final nextStart = ((i + 1) * bucketSize).floor() + 1;
    final nextEnd = math.min(((i + 2) * bucketSize).floor() + 1, data.length);

    // Centroid of next bucket
    double avgX = 0;
    double avgY = 0;
    final count = nextEnd - nextStart;
    for (var j = nextStart; j < nextEnd; j++) {
      avgX += data[j].x;
      avgY += data[j].y;
    }
    avgX /= count;
    avgY /= count;

    // Previous point A
    final pointA = data[aIndex];

    // Find point B in current bucket that maximizes triangle area (A, B, C)
    double maxArea = -1;
    var maxAreaIndex = rangeStart;

    for (var j = rangeStart; j < rangeEnd; j++) {
      final point = data[j];
      final area =
          ((pointA.x - avgX) * (point.y - pointA.y) -
                  (pointA.x - point.x) * (avgY - pointA.y))
              .abs() *
          0.5;

      if (area > maxArea) {
        maxArea = area;
        maxAreaIndex = j;
      }
    }

    sampled.add(data[maxAreaIndex]);
    aIndex = maxAreaIndex;
  }

  // Always add last point
  sampled.add(data.last);
  return sampled;
}

/// Downsamples each segment proportionally and joins them with [FlSpot.nullSpot].
///
/// LTTB operates strictly within each contiguous segment so it never sees null spots.
List<FlSpot> downsampleAndJoinSegments(
  List<List<FlSpot>> segments, {
  int targetTotal = 400,
}) {
  final totalSpots = segments.fold<int>(0, (sum, s) => sum + s.length);
  if (totalSpots == 0) return const [];

  final result = <FlSpot>[];

  // If total spots within budget, keep all points without downsampling
  if (totalSpots <= targetTotal) {
    for (var i = 0; i < segments.length; i++) {
      result.addAll(segments[i]);
      if (i < segments.length - 1 && segments[i].isNotEmpty) {
        result.add(FlSpot.nullSpot);
      }
    }
    return result;
  }

  // Proportionally downsample each segment
  for (var i = 0; i < segments.length; i++) {
    final segment = segments[i];
    if (segment.isEmpty) continue;

    final proportion = segment.length / totalSpots;
    final segmentTarget = math.max(2, (targetTotal * proportion).round());

    final downsampled = segment.length <= segmentTarget
        ? segment
        : lttb(segment, segmentTarget);

    result.addAll(downsampled);

    if (i < segments.length - 1 && segments[i].isNotEmpty) {
      result.add(FlSpot.nullSpot);
    }
  }

  return result;
}

// ---------------------------------------------------------------------------
// Chart axis bounds calculation
// ---------------------------------------------------------------------------

/// Holds calculated Y-axis visual bounds and threshold limits.
class YAxisBounds {
  const YAxisBounds({
    required this.minY,
    required this.maxY,
    required this.safeMax,
    required this.dangerMin,
    required this.interval,
  });

  final double minY;
  final double maxY;
  final double safeMax;
  final double dangerMin;
  final double interval;
}

/// Computes Y-axis min/max bounds such that Safe/Medium/Danger threshold bands
/// are always visible and lines fill the chart area.
///
/// Formula:
/// minY = min(dataMin, safeMax) - pad
/// maxY = max(dataMax, dangerMin) + pad
YAxisBounds calculateYAxisBounds({
  required List<FlSpot> spots,
  required double safeMax,
  required double dangerMin,
  required double padding,
  double? absoluteMin,
  double? absoluteMax,
  required double interval,
}) {
  final valid = spots.where((s) => s != FlSpot.nullSpot && !s.y.isNaN).toList();
  final double dataMin;
  final double dataMax;

  if (valid.isEmpty) {
    dataMin = safeMax;
    dataMax = dangerMin;
  } else {
    dataMin = valid.map((s) => s.y).reduce(math.min);
    dataMax = valid.map((s) => s.y).reduce(math.max);
  }

  var minY = math.min(dataMin, safeMax) - padding;
  var maxY = math.max(dataMax, dangerMin) + padding;

  if (absoluteMin != null) minY = math.max(absoluteMin, minY);
  if (absoluteMax != null) maxY = math.min(absoluteMax, maxY);

  // Snap to interval steps
  minY = (minY / interval).floor() * interval;
  maxY = (maxY / interval).ceil() * interval;

  return YAxisBounds(
    minY: minY,
    maxY: maxY,
    safeMax: safeMax,
    dangerMin: dangerMin,
    interval: interval,
  );
}

// ---------------------------------------------------------------------------
// X-axis configuration
// ---------------------------------------------------------------------------

/// Configuration for X-axis time labels and grid alignment.
class XAxisConfig {
  const XAxisConfig({
    required this.minX,
    required this.maxX,
    required this.baselineX,
    required this.interval,
    required this.formatDate,
  });

  final double minX;
  final double maxX;
  final double baselineX;
  final double interval;
  final String Function(DateTime) formatDate;
}

/// Calculates round-boundary X-axis parameters for the given [range].
///
/// Round boundaries:
/// - 1 h: every 15 min on :00, :15, :30, :45 (format "HH:mm")
/// - 6 h: every 1 h on the hour (format "HH:mm")
/// - 24 h: every 4 h on 00, 04, 08, 12, 16, 20 (format "HH:mm")
/// - 7 d: every 24 h at midnight (format "EEE d")
XAxisConfig calculateXAxisConfig(
  HistoryRange range, {
  DateTime Function()? clock,
}) {
  final now = (clock ?? DateTime.now)();
  final maxX = now.millisecondsSinceEpoch.toDouble();
  final minX = now.subtract(range.duration).millisecondsSinceEpoch.toDouble();

  final double intervalMs;
  final double baselineX;
  final String Function(DateTime) formatter;

  switch (range) {
    case HistoryRange.h1:
      intervalMs = 15 * 60 * 1000.0;
      final startDt = now.subtract(range.duration);
      final rem = startDt.minute % 15;
      final aligned = startDt.subtract(
        Duration(
          minutes: rem,
          seconds: startDt.second,
          milliseconds: startDt.millisecond,
        ),
      );
      baselineX = aligned.millisecondsSinceEpoch.toDouble();
      formatter = (dt) => DateFormat('HH:mm').format(dt);

    case HistoryRange.h6:
      intervalMs = 60 * 60 * 1000.0;
      final startDt = now.subtract(range.duration);
      final aligned = DateTime(
        startDt.year,
        startDt.month,
        startDt.day,
        startDt.hour,
      );
      baselineX = aligned.millisecondsSinceEpoch.toDouble();
      formatter = (dt) => DateFormat('HH:mm').format(dt);

    case HistoryRange.h24:
      intervalMs = 4 * 3600 * 1000.0;
      final startDt = now.subtract(range.duration);
      final hourMod4 = startDt.hour - (startDt.hour % 4);
      final aligned = DateTime(
        startDt.year,
        startDt.month,
        startDt.day,
        hourMod4,
      );
      baselineX = aligned.millisecondsSinceEpoch.toDouble();
      formatter = (dt) => DateFormat('HH:mm').format(dt);

    case HistoryRange.d7:
      intervalMs = 24 * 3600 * 1000.0;
      final startDt = now.subtract(range.duration);
      final aligned = DateTime(startDt.year, startDt.month, startDt.day);
      baselineX = aligned.millisecondsSinceEpoch.toDouble();
      formatter = (dt) => DateFormat('EEE d').format(dt);
  }

  return XAxisConfig(
    minX: minX,
    maxX: maxX,
    baselineX: baselineX,
    interval: intervalMs,
    formatDate: formatter,
  );
}

// ---------------------------------------------------------------------------
// Semantics summary generator
// ---------------------------------------------------------------------------

/// Generates an accessible screen-reader summary for a metric chart.
String generateChartSummary({
  required String metricName,
  required String unit,
  required HistoryRange range,
  required List<FlSpot> spots,
  required double safeMax,
  required double dangerMin,
  int fractionDigits = 1,
}) {
  final validSpots = spots
      .where((s) => s != FlSpot.nullSpot && !s.y.isNaN)
      .toList();

  if (validSpots.isEmpty) {
    return '$metricName history over the last ${range.label}: no readings available.';
  }

  final current = validSpots.last.y.toStringAsFixed(fractionDigits);
  final minVal = validSpots
      .map((s) => s.y)
      .reduce(math.min)
      .toStringAsFixed(fractionDigits);
  final maxVal = validSpots
      .map((s) => s.y)
      .reduce(math.max)
      .toStringAsFixed(fractionDigits);

  return '$metricName history over the last ${range.label}. '
      'Current: $current $unit. '
      'Minimum: $minVal $unit, Maximum: $maxVal $unit. '
      'Safe below $safeMax $unit, Danger above $dangerMin $unit.';
}
