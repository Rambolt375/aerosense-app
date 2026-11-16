import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';

/// Language used for the deterministic summary content.
///
/// Tier names stay canonical (Safe / Caution / Danger) in both languages so
/// the summary always matches the words the firmware writes.
enum SummaryLanguage { en, id }

/// Device freshness as derived from the newest `/history` timestamp.
enum DeviceSummaryState { online, offline, unknown }

/// Overall forecast gate state exposed to the summary.
enum ForecastSummaryStatus {
  active,
  lockedOut,
  learning,
  waitingForTimestamps,
  paused,
  unavailable,
}

/// Whether the 24-hour history could be read.
enum HistoryAvailability { ready, loading, unavailable }

/// Device freshness plus the already-formatted last-data label.
class DeviceSummary {
  const DeviceSummary({required this.state, this.lastDataLabel});

  final DeviceSummaryState state;

  /// Local `HH:mm` label, formatted by the provider. Null when unknown.
  final String? lastDataLabel;
}

/// Forecast facts the summary may mention.
class ForecastSummary {
  const ForecastSummary({
    required this.status,
    this.temperaturePeak,
    this.airQualityPeak,
    this.learningPercent,
  });

  final ForecastSummaryStatus status;

  /// Local `HH:mm` predicted peak, only when the model has a clear pattern.
  final String? temperaturePeak;

  /// Local `HH:mm` predicted peak, only when the model has a clear pattern.
  final String? airQualityPeak;

  /// 0..99 progress while the forecast is still learning.
  final int? learningPercent;
}

/// Min / max / mean for a single metric over the 24-hour window.
class MetricStats {
  const MetricStats({required this.min, required this.max, required this.mean});

  final double min;
  final double max;
  final double mean;
}

/// Validated 24-hour statistics.
///
/// [sampleCount] counts timestamped records inside the window that carried at
/// least one valid metric. Records without timestamps are excluded, never
/// estimated.
class HistoryStats24h {
  const HistoryStats24h({
    this.sampleCount = 0,
    this.temperature,
    this.humidity,
    this.airQuality,
    this.windowStart,
  });

  final int sampleCount;
  final MetricStats? temperature;
  final MetricStats? humidity;
  final MetricStats? airQuality;

  /// Earliest counted timestamp inside the window.
  final DateTime? windowStart;

  bool get isEmpty => sampleCount == 0;

  /// A non-empty window with fewer than 6 readings is flagged as limited.
  bool get isSparse => sampleCount > 0 && sampleCount < 6;
}

/// Plain-value input for [buildSummary].
///
/// Deliberately free of providers and Flutter imports so the builder is pure
/// and testable. The provider layer formats times and maps gate states.
class SummaryInput {
  const SummaryInput({
    required this.state,
    required this.thresholds,
    required this.device,
    required this.forecast,
    required this.history,
    required this.language,
    required this.now,
    this.historyAvailability = HistoryAvailability.ready,
    this.appConnected = true,
  });

  final SystemState state;
  final ThresholdPreset thresholds;
  final DeviceSummary device;
  final ForecastSummary forecast;
  final HistoryStats24h history;
  final SummaryLanguage language;
  final DateTime now;
  final HistoryAvailability historyAvailability;
  final bool appConnected;

  SummaryInput copyWith({SummaryLanguage? language}) {
    return SummaryInput(
      state: state,
      thresholds: thresholds,
      device: device,
      forecast: forecast,
      history: history,
      language: language ?? this.language,
      now: now,
      historyAvailability: historyAvailability,
      appConnected: appConnected,
    );
  }
}

/// One headed block of the summary.
class SummarySection {
  const SummarySection({required this.heading, required this.lines});

  final String heading;
  final List<String> lines;
}

/// Structured summary plus the plain text used by the copy button and the
/// future assistant payload.
class SummaryResult {
  const SummaryResult({required this.sections});

  final List<SummarySection> sections;

  /// Sections joined by a blank line, each as heading then one line per fact.
  String get plainText => sections
      .map((section) => [section.heading, ...section.lines].join('\n'))
      .join('\n\n');
}
