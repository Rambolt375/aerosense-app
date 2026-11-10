import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';

// ---------------------------------------------------------------------------
// History State & Notifier
// ---------------------------------------------------------------------------

/// State holding all raw records fetched from `/history`.
@immutable
class HistoryState {
  const HistoryState({required this.allRecords});

  final List<HistoryRecord> allRecords;

  HistoryState copyWith({List<HistoryRecord>? allRecords}) {
    return HistoryState(allRecords: allRecords ?? this.allRecords);
  }
}

/// AsyncNotifier managing historical telemetry records.
///
/// Keeps history alive across tab navigation, fetches up to 7 days (2016 records)
/// upon initialization, and subscribes to live appends via `watchNewRecords()`.
class HistoryNotifier extends AsyncNotifier<HistoryState> {
  @override
  Future<HistoryState> build() async {
    // Keep provider alive so switching tabs doesn't re-download 7 days of records.
    ref.keepAlive();

    final repo = ref.watch(historyRepositoryProvider);
    final initialRecords = await repo.fetchHistory(limit: 2016);

    // Subscribe only after the initial fetch succeeds
    final sub = repo.watchNewRecords().listen(
      (newRecord) {
        state.whenData((currentState) {
          final updated = mergeHistoryRecords(
            currentState.allRecords,
            newRecord,
            maxRecords: 2016,
          );
          state = AsyncData(currentState.copyWith(allRecords: updated));
        });
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('[HistoryNotifier] watchNewRecords stream error: $error');
      },
    );
    ref.onDispose(sub.cancel);

    return HistoryState(allRecords: initialRecords);
  }

  /// Retries fetching history from the repository.
  Future<void> retry() async {
    ref.invalidateSelf();
    await future;
  }
}

final historyNotifierProvider =
    AsyncNotifierProvider<HistoryNotifier, HistoryState>(
      HistoryNotifier.new,
      retry: (_, _) => null,
    );

// ---------------------------------------------------------------------------
// Selected Range Notifier
// ---------------------------------------------------------------------------

class SelectedRangeNotifier extends Notifier<HistoryRange> {
  @override
  HistoryRange build() => HistoryRange.h24; // 24 h default per PRD §FR-5

  void select(HistoryRange range) => state = range;
}

final selectedRangeProvider =
    NotifierProvider<SelectedRangeNotifier, HistoryRange>(
      SelectedRangeNotifier.new,
    );

// ---------------------------------------------------------------------------
// Chart Data Presentation Model & Derived Provider
// ---------------------------------------------------------------------------

/// Ready-to-render data model for the three history line charts.
@immutable
class HistoryChartData {
  const HistoryChartData({
    required this.selectedRange,
    required this.hasAnyHistory,
    required this.hasRangeReadings,
    required this.isSynthetic,
    required this.temperatureSpots,
    required this.humiditySpots,
    required this.airQualitySpots,
    this.temperatureForecastSpots,
    this.airQualityForecastSpots,
    required this.xAxisConfig,
    required this.temperatureYBounds,
    required this.humidityYBounds,
    required this.airQualityYBounds,
    required this.temperatureSummary,
    required this.humiditySummary,
    required this.airQualitySummary,
  });

  final HistoryRange selectedRange;
  final bool hasAnyHistory;
  final bool hasRangeReadings;
  final bool isSynthetic;

  final List<FlSpot> temperatureSpots;
  final List<FlSpot> humiditySpots;
  final List<FlSpot> airQualitySpots;

  final List<FlSpot>? temperatureForecastSpots;
  final List<FlSpot>? airQualityForecastSpots;

  final XAxisConfig xAxisConfig;
  final YAxisBounds temperatureYBounds;
  final YAxisBounds humidityYBounds;
  final YAxisBounds airQualityYBounds;

  final String temperatureSummary;
  final String humiditySummary;
  final String airQualitySummary;
}

/// Derived provider shaping raw history state into chart-ready series and bounds.
final historyChartDataProvider = Provider<AsyncValue<HistoryChartData>>((ref) {
  final historyAsync = ref.watch(historyNotifierProvider);
  final range = ref.watch(selectedRangeProvider);

  // Uses select so charts only re-evaluate when each metric's own forecast status or model changes (Review fix 3)
  final tempForecastActive = ref.watch(
    forecastGateNotifierProvider.select(
      (g) =>
          g.tempGate.status == MetricGateStatus.active &&
          g.tempGate.model != null &&
          g.tempGate.model!.hasClearDailyPattern,
    ),
  );
  final aqForecastActive = ref.watch(
    forecastGateNotifierProvider.select(
      (g) =>
          g.aqGate.status == MetricGateStatus.active &&
          g.aqGate.model != null &&
          g.aqGate.model!.hasClearDailyPattern,
    ),
  );
  final tempModel = ref.watch(
    forecastGateNotifierProvider.select((g) => g.tempGate.model),
  );
  final aqModel = ref.watch(
    forecastGateNotifierProvider.select((g) => g.aqGate.model),
  );

  return historyAsync.whenData((historyState) {
    if (historyState.allRecords.isEmpty) {
      final xConfig = calculateXAxisConfig(range);
      return HistoryChartData(
        selectedRange: range,
        hasAnyHistory: false,
        hasRangeReadings: false,
        isSynthetic: false,
        temperatureSpots: const [],
        humiditySpots: const [],
        airQualitySpots: const [],
        temperatureForecastSpots: null,
        airQualityForecastSpots: null,
        xAxisConfig: xConfig,
        temperatureYBounds: calculateYAxisBounds(
          spots: const [],
          safeMax: Thresholds.tempSafeMax,
          dangerMin: Thresholds.tempDangerMin,
          padding: 2.0,
          interval: 5.0,
        ),
        humidityYBounds: calculateYAxisBounds(
          spots: const [],
          safeMax: Thresholds.humiditySafeMax,
          dangerMin: Thresholds.humidityDangerMin,
          padding: 5.0,
          absoluteMin: 0.0,
          absoluteMax: 100.0,
          interval: 20.0,
        ),
        airQualityYBounds: calculateYAxisBounds(
          spots: const [],
          safeMax: Thresholds.airQualitySafeMax,
          dangerMin: Thresholds.airQualityDangerMin,
          padding: 100.0,
          absoluteMin: 0.0,
          absoluteMax: Thresholds.airQualityAdcMax,
          interval: 1000.0,
        ),
        temperatureSummary: 'No temperature readings available.',
        humiditySummary: 'No humidity readings available.',
        airQualitySummary: 'No air quality readings available.',
      );
    }

    // Step 1: Resolve timestamps (handling synthetic fallback / dropping nulls)
    final resolved = resolveTimestamps(historyState.allRecords);

    // Step 2: Filter by range window
    final filtered = filterByRange(resolved.records, range);
    final hasRangeReadings = filtered.isNotEmpty;

    // Step 3: X-Axis configuration
    final xConfig = calculateXAxisConfig(range);

    // Step 4: Split into segments (> 15 min gap)
    final segments = splitIntoSegments(filtered);

    // Step 5: Convert and proportionally downsample per metric
    final tempSegments = segments
        .map((s) => segmentToSpots(s, (r) => r.temperature))
        .toList();
    final humSegments = segments
        .map((s) => segmentToSpots(s, (r) => r.humidity))
        .toList();
    final aqSegments = segments
        .map((s) => segmentToSpots(s, (r) => r.airQuality))
        .toList();

    // Downsample if range is 7 d (target 400 points)
    final tempSpots = downsampleAndJoinSegments(
      tempSegments,
      targetTotal: range == HistoryRange.d7 ? 400 : 2016,
    );
    final humSpots = downsampleAndJoinSegments(
      humSegments,
      targetTotal: range == HistoryRange.d7 ? 400 : 2016,
    );
    final aqSpots = downsampleAndJoinSegments(
      aqSegments,
      targetTotal: range == HistoryRange.d7 ? 400 : 2016,
    );

    // Step 6: Y-Axis bounds calculation
    final tempBounds = calculateYAxisBounds(
      spots: tempSpots,
      safeMax: Thresholds.tempSafeMax,
      dangerMin: Thresholds.tempDangerMin,
      padding: 2.0,
      interval: 5.0,
    );
    final humBounds = calculateYAxisBounds(
      spots: humSpots,
      safeMax: Thresholds.humiditySafeMax,
      dangerMin: Thresholds.humidityDangerMin,
      padding: 5.0,
      absoluteMin: 0.0,
      absoluteMax: 100.0,
      interval: 20.0,
    );
    final aqBounds = calculateYAxisBounds(
      spots: aqSpots,
      safeMax: Thresholds.airQualitySafeMax,
      dangerMin: Thresholds.airQualityDangerMin,
      padding: 100.0,
      absoluteMin: 0.0,
      absoluteMax: Thresholds.airQualityAdcMax,
      interval: 1000.0,
    );

    // Step 7: Semantics summaries
    final tempSummary = generateChartSummary(
      metricName: 'Temperature',
      unit: '°C',
      range: range,
      spots: tempSpots,
      safeMax: Thresholds.tempSafeMax,
      dangerMin: Thresholds.tempDangerMin,
    );
    final humSummary = generateChartSummary(
      metricName: 'Humidity',
      unit: '% RH',
      range: range,
      spots: humSpots,
      safeMax: Thresholds.humiditySafeMax,
      dangerMin: Thresholds.humidityDangerMin,
    );
    final aqSummary = generateChartSummary(
      metricName: 'Air quality',
      unit: 'index',
      range: range,
      spots: aqSpots,
      safeMax: Thresholds.airQualitySafeMax,
      dangerMin: Thresholds.airQualityDangerMin,
      fractionDigits: 0,
    );

    // Step 8: Sample forecast dotted series if metric is individually active with clear pattern
    final tempForecast = (tempForecastActive && tempModel != null)
        ? sampleForecastSeries(
            model: tempModel,
            minX: xConfig.minX,
            maxX: xConfig.maxX,
            pointCount: 120,
          )
        : null;

    final aqForecast = (aqForecastActive && aqModel != null)
        ? sampleForecastSeries(
            model: aqModel,
            minX: xConfig.minX,
            maxX: xConfig.maxX,
            pointCount: 120,
          )
        : null;

    return HistoryChartData(
      selectedRange: range,
      hasAnyHistory: true,
      hasRangeReadings: hasRangeReadings,
      isSynthetic: resolved.isSynthetic,
      temperatureSpots: tempSpots,
      humiditySpots: humSpots,
      airQualitySpots: aqSpots,
      temperatureForecastSpots: tempForecast,
      airQualityForecastSpots: aqForecast,
      xAxisConfig: xConfig,
      temperatureYBounds: tempBounds,
      humidityYBounds: humBounds,
      airQualityYBounds: aqBounds,
      temperatureSummary: tempSummary,
      humiditySummary: humSummary,
      airQualitySummary: aqSummary,
    );
  });
});
