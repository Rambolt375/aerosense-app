import 'dart:ui' show Locale, PlatformDispatcher;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/history/history_notifier.dart';
import 'package:aerosense_app/features/summary/history_stats.dart';
import 'package:aerosense_app/features/summary/summary_builder.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';

/// Device locale, used only to pick the initial summary language.
final deviceLocaleProvider = Provider<Locale>((ref) {
  return PlatformDispatcher.instance.locale;
});

/// Default summary language: Indonesian for `id`, otherwise English.
SummaryLanguage summaryLanguageForLocale(Locale locale) {
  return locale.languageCode.toLowerCase() == 'id'
      ? SummaryLanguage.id
      : SummaryLanguage.en;
}

/// Selected summary language. In-memory so it survives reopening the sheet.
class SummaryLanguageNotifier extends Notifier<SummaryLanguage> {
  @override
  SummaryLanguage build() {
    return summaryLanguageForLocale(ref.watch(deviceLocaleProvider));
  }

  void select(SummaryLanguage language) => state = language;
}

final summaryLanguageProvider =
    NotifierProvider<SummaryLanguageNotifier, SummaryLanguage>(
      SummaryLanguageNotifier.new,
    );

/// Adapts already-loaded providers into a plain [SummaryInput].
///
/// Returns null until the first `/system` snapshot exists, so the sheet can
/// show a no-data state instead of inventing readings. The 24-hour stats reuse
/// the history that the dashboard and forecast already loaded.
final summaryInputProvider = Provider<SummaryInput?>((ref) {
  final systemState = ref.watch(systemStateProvider).asData?.value;
  if (systemState == null) return null;

  final deviceStatus = ref.watch(deviceStatusProvider);
  final gate = ref.watch(forecastGateNotifierProvider);
  final fitState = ref.watch(diurnalFitProvider);
  final historyAsync = ref.watch(historyNotifierProvider);
  final now = ref.read(clockProvider)();

  final historyAvailability = _historyAvailability(historyAsync);
  final history = historyAsync.hasValue
      ? computeHistoryStats24h(
          records: historyAsync.value!.allRecords,
          now: now,
        )
      : const HistoryStats24h();

  return SummaryInput(
    state: systemState,
    thresholds: Thresholds.current,
    device: DeviceSummary(
      state: _deviceSummaryState(deviceStatus),
      lastDataLabel: deviceStatus.formattedTime,
    ),
    forecast: _forecastSummary(gate, fitState),
    history: history,
    language: ref.watch(summaryLanguageProvider),
    now: now,
    historyAvailability: historyAvailability,
    appConnected: ref.watch(connectedProvider).asData?.value ?? true,
  );
});

/// Builds the summary in the currently selected language.
final summaryResultProvider = Provider<SummaryResult?>((ref) {
  final input = ref.watch(summaryInputProvider);
  if (input == null) return null;
  final language = ref.watch(summaryLanguageProvider);
  return buildSummary(input.copyWith(language: language));
});

HistoryAvailability _historyAvailability(AsyncValue<HistoryState> value) {
  if (value.hasError) return HistoryAvailability.unavailable;
  if (value.hasValue) return HistoryAvailability.ready;
  return HistoryAvailability.loading;
}

DeviceSummaryState _deviceSummaryState(DeviceStatus status) {
  switch (status.status) {
    case DeviceOnlineStatus.online:
      return DeviceSummaryState.online;
    case DeviceOnlineStatus.offline:
      return DeviceSummaryState.offline;
    case DeviceOnlineStatus.unknown:
      return DeviceSummaryState.unknown;
  }
}

ForecastSummary _forecastSummary(ForecastGate gate, DiurnalFitState fitState) {
  switch (gate.status) {
    case ForecastGateStatus.active:
      return ForecastSummary(
        status: ForecastSummaryStatus.active,
        temperaturePeak: gate.tempGate.model?.formattedPeakTime,
        airQualityPeak: gate.aqGate.model?.formattedPeakTime,
      );
    case ForecastGateStatus.lockedOut:
      return const ForecastSummary(status: ForecastSummaryStatus.lockedOut);
    case ForecastGateStatus.learning:
      final temperaturePercent = fitState.temperatureResult.learningPercentage;
      final airQualityPercent = fitState.airQualityResult.learningPercentage;
      return ForecastSummary(
        status: ForecastSummaryStatus.learning,
        learningPercent: temperaturePercent > 0
            ? temperaturePercent
            : airQualityPercent,
      );
    case ForecastGateStatus.waitingForTimestamps:
      return const ForecastSummary(
        status: ForecastSummaryStatus.waitingForTimestamps,
      );
  }
}
