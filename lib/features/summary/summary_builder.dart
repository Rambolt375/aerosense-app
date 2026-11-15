import 'package:aerosense_app/core/sensor_validation.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/summary/summary_copy.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';

/// Whether [message] is only a tier keyword, with no descriptive text.
///
/// A bare keyword is already represented by the firmware-tier line, so it must
/// not be quoted again as a status message.
bool isBareTierKeyword(String? message) {
  if (message == null) return false;
  final normalized = message.trim().toUpperCase();
  return normalized == 'CAUTION' ||
      normalized == 'SAFE' ||
      normalized == 'DANGER' ||
      normalized == 'NORMAL' ||
      normalized == 'MEDIUM';
}

/// Canonical tier word used in both languages.
String tierWord(Tier tier) {
  switch (tier) {
    case Tier.safe:
      return 'Safe';
    case Tier.medium:
      return 'Caution';
    case Tier.danger:
      return 'Danger';
  }
}

/// Builds the deterministic summary. Pure Dart, no network, no Flutter.
///
/// The firmware tier is always quoted when the device sent one. The builder
/// never re-derives the tier, never decides safety, and never instructs the
/// visitor.
SummaryResult buildSummary(SummaryInput input) {
  final copy = SummaryCopy(input.language);
  return SummaryResult(
    sections: [
      _statusSection(input, copy),
      _readingsSection(input, copy),
      _historySection(input, copy),
      _forecastSection(input, copy),
    ],
  );
}

SummarySection _statusSection(SummaryInput input, SummaryCopy copy) {
  final state = input.state;
  final firmwareTier = Tier.fromStatusMessage(state.statusMessage);
  final lines = <String>[];

  if (firmwareTier != null) {
    lines.add(copy.firmwareTier(tierWord(firmwareTier)));
  } else {
    lines.add(copy.displayedTier(tierWord(state.tier)));
  }

  final message = state.statusMessage.trim();
  if (message.isNotEmpty && !isBareTierKeyword(message)) {
    lines.add(copy.statusMessage(message));
  }

  lines.add(copy.fanLine(state.fanOn));
  lines.addAll(copy.deviceLines(input.device));

  if (!input.appConnected) {
    lines.add(copy.appOffline);
  }

  return SummarySection(heading: copy.statusHeading, lines: lines);
}

SummarySection _readingsSection(SummaryInput input, SummaryCopy copy) {
  final thresholds = input.thresholds;
  final readings = validateSensorReadings(
    temperature: input.state.temperature,
    humidity: input.state.humidity,
    airQuality: input.state.airQuality,
  );
  final lines = <String>[];

  final temperature = readings.temperature;
  if (temperature == null) {
    lines.add(copy.temperatureNoReading);
  } else {
    lines.add(
      copy.temperatureReading(
        temperature,
        thresholds.tempCautionMin,
        thresholds.tempDangerMin,
      ),
    );
  }

  final humidity = readings.humidity;
  if (humidity == null) {
    lines.add(copy.humidityNoReading);
  } else {
    lines.add(
      copy.humidityReading(
        humidity,
        thresholds.humidityCautionMin,
        thresholds.humidityDangerMin,
        confirmedByFirmware: thresholds.humidityConfirmedByFirmware,
      ),
    );
  }
  if (!thresholds.humidityConfirmedByFirmware) {
    lines.add(copy.humidityNotUsed);
  }

  final airQuality = readings.airQuality;
  if (airQuality == null) {
    lines.add(copy.airQualityNoReading);
  } else {
    lines.add(
      copy.airQualityReading(
        airQuality,
        thresholds.airQualityCautionMin,
        thresholds.airQualityDangerMin,
      ),
    );
  }

  return SummarySection(heading: copy.readingsHeading, lines: lines);
}

SummarySection _historySection(SummaryInput input, SummaryCopy copy) {
  switch (input.historyAvailability) {
    case HistoryAvailability.loading:
      return SummarySection(
        heading: copy.historyHeading(null),
        lines: [copy.loadingHistory],
      );
    case HistoryAvailability.unavailable:
      return SummarySection(
        heading: copy.historyHeading(null),
        lines: [copy.historyUnavailable],
      );
    case HistoryAvailability.ready:
      break;
  }

  final history = input.history;
  if (history.isEmpty) {
    return SummarySection(
      heading: copy.historyHeading(null),
      lines: [copy.noHistory],
    );
  }

  final lines = <String>[];
  if (history.isSparse) {
    lines.add(copy.limitedData);
  }

  final temperature = history.temperature;
  if (temperature != null) {
    lines.add(
      copy.temperatureStats(temperature.min, temperature.max, temperature.mean),
    );
  }
  final humidity = history.humidity;
  if (humidity != null) {
    lines.add(copy.humidityStats(humidity.min, humidity.max, humidity.mean));
  }
  final airQuality = history.airQuality;
  if (airQuality != null) {
    lines.add(
      copy.airQualityStats(airQuality.min, airQuality.max, airQuality.mean),
    );
  }

  return SummarySection(
    heading: copy.historyHeading(history.sampleCount),
    lines: lines,
  );
}

SummarySection _forecastSection(SummaryInput input, SummaryCopy copy) {
  final forecast = input.forecast;
  final lines = <String>[];

  switch (forecast.status) {
    case ForecastSummaryStatus.active:
      lines.add(copy.forecastActive);
      final temperaturePeak = forecast.temperaturePeak;
      if (temperaturePeak != null) {
        lines.add(copy.temperaturePeak(temperaturePeak));
      }
      final airQualityPeak = forecast.airQualityPeak;
      if (airQualityPeak != null) {
        lines.add(copy.airQualityPeak(airQualityPeak));
      }
      break;
    case ForecastSummaryStatus.lockedOut:
      lines.add(copy.forecastLockedOut);
      break;
    case ForecastSummaryStatus.learning:
      lines.add(copy.forecastLearning);
      final percent = forecast.learningPercent;
      if (percent != null) {
        lines.add(copy.learningProgress(percent));
      }
      break;
    case ForecastSummaryStatus.waitingForTimestamps:
      lines.add(copy.forecastWaiting);
      break;
    case ForecastSummaryStatus.unavailable:
      lines.add(copy.forecastUnavailable);
      break;
  }

  return SummarySection(heading: copy.forecastHeading, lines: lines);
}
