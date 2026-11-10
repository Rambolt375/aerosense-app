import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';
import 'package:aerosense_app/features/forecast/sinusoidal_fit.dart';
import 'package:aerosense_app/features/history/history_notifier.dart';

/// Combined fitting results for both Temperature and Air Quality.
class DiurnalFitState {
  const DiurnalFitState({
    required this.temperatureResult,
    required this.airQualityResult,
  });

  final DiurnalFitResult temperatureResult;
  final DiurnalFitResult airQualityResult;
}

/// Computes the diurnal sinusoidal fit for both Temperature and Air Quality.
///
/// NOTE on Riverpod caching (Requirement 9):
/// This provider watches [historyNotifierProvider] and [demoModeProvider] only.
/// It explicitly does NOT watch [selectedRangeProvider], ensuring that switching
/// history chart ranges (1 h, 6 h, 24 h, 7 d) NEVER re-fits the model.
final diurnalFitProvider = Provider<DiurnalFitState>((ref) {
  final historyAsync = ref.watch(historyNotifierProvider);
  final isDemo = ref.watch(demoModeProvider);

  final records = historyAsync.value?.allRecords ?? [];

  final tempResult = fitRobustDiurnal(
    records: records,
    extractor: (r) => r.temperature,
    noiseFloor: AppConfig.minTempTolerance,
    isDemo: isDemo,
  );

  final aqResult = fitRobustDiurnal(
    records: records,
    extractor: (r) => r.airQuality,
    noiseFloor: AppConfig.minAqTolerance,
    isDemo: isDemo,
  );

  return DiurnalFitState(
    temperatureResult: tempResult,
    airQualityResult: aqResult,
  );
});

/// Evaluates live `/system` sensor readings against the fitted diurnal models
/// and manages per-metric gate status and hysteresis.
class ForecastGateNotifier extends Notifier<ForecastGate> {
  StreamSubscription<SystemState>? _systemSub;

  @override
  ForecastGate build() {
    final fitState = ref.watch(diurnalFitProvider);
    final systemRepo = ref.watch(systemRepositoryProvider);

    final gate = ForecastGate(
      tempModel: fitState.temperatureResult.model,
      aqModel: fitState.airQualityResult.model,
      tempFitStatus: fitState.temperatureResult.status,
      aqFitStatus: fitState.airQualityResult.status,
    );

    _systemSub?.cancel();
    _systemSub = systemRepo.watchSystemState().listen((sample) {
      final updated = state.clone();
      updated.processSample(
        temperature: sample.temperature,
        airQuality: sample.airQuality,
        time: DateTime.now(),
      );
      state = updated;
    });

    ref.onDispose(() => _systemSub?.cancel());
    return gate;
  }
}

/// Provider exposing the live residual gate state.
final forecastGateNotifierProvider =
    NotifierProvider<ForecastGateNotifier, ForecastGate>(
      ForecastGateNotifier.new,
    );

/// Samples a fitted [DiurnalModel] across a chart's [minX] to [maxX] window
/// producing roughly 100-200 points for smooth dotted line rendering (Requirement 6).
List<FlSpot> sampleForecastSeries({
  required DiurnalModel model,
  required double minX,
  required double maxX,
  int pointCount = 120,
}) {
  if (maxX <= minX || pointCount < 2) return const [];
  final spots = <FlSpot>[];
  final stepMs = (maxX - minX) / (pointCount - 1);

  for (var i = 0; i < pointCount; i++) {
    final tMs = minX + i * stepMs;
    final dt = DateTime.fromMillisecondsSinceEpoch(tMs.toInt());
    final sec = secondsSinceMidnight(dt);
    final yHat = model.predict(sec);
    spots.add(FlSpot(tMs, yHat));
  }
  return spots;
}
