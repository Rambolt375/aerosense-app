import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';

/// Gate status for an individual metric (Temperature or Air Quality).
enum MetricGateStatus {
  /// Live reading within residual tolerance (confidence gate open).
  active,

  /// Residual error exceeded tolerance or freshly fitted model waiting for hysteresis.
  lockedOut,

  /// Historical dataset is still accumulating required time span or coverage.
  learning,

  /// Device history lacks real RTC/NTP timestamps.
  waitingForTimestamps,

  /// Model does not explain sufficient variance (R^2 < minR2Pattern); no periodic diurnal pattern.
  noClearPattern,
}

/// Overall combined status for the diurnal forecasting engine.
enum ForecastGateStatus {
  /// Both metric models are Active and live samples are predictable.
  active,

  /// One or both metrics are Locked Out due to anomalous error or hysteresis.
  lockedOut,

  /// Accumulating historical records.
  learning,

  /// Historical records have synthetic timestamps.
  waitingForTimestamps,
}

/// Tracks the live residual error and 3-sample hysteresis state for a single metric.
class MetricGateTracker {
  MetricGateTracker({
    required this.metricName,
    this.model,
    MetricGateStatus? initialStatus,
  }) : status =
           initialStatus ??
           (model != null
               ? (!model.hasClearDailyPattern
                     ? MetricGateStatus.noClearPattern
                     : MetricGateStatus.lockedOut)
               : MetricGateStatus.learning),
       consecutiveInTolerance = 0,
       threshold = model?.effectiveThreshold ?? 0.0;

  final String metricName;
  DiurnalModel? model;
  MetricGateStatus status;
  int consecutiveInTolerance;
  double threshold;

  double? lastLiveValue;
  double? lastPredictedValue;
  double? lastError;

  /// Evaluates a live sensor reading against the fitted diurnal model.
  ///
  /// Skips evaluation if [value] is null or NaN (preserving current gate state).
  void processSample(double? value, DateTime time) {
    if (value == null || value.isNaN) return;
    if (model == null) return;
    if (!model!.hasClearDailyPattern) {
      status = MetricGateStatus.noClearPattern;
      consecutiveInTolerance = 0;
      return;
    }

    final yHat = model!.predictDateTime(time);
    final error = (value - yHat).abs();

    lastLiveValue = value;
    lastPredictedValue = yHat;
    lastError = error;

    if (error <= threshold) {
      if (consecutiveInTolerance < AppConfig.forecastHysteresisSamples) {
        consecutiveInTolerance++;
      }
      if (consecutiveInTolerance >= AppConfig.forecastHysteresisSamples) {
        status = MetricGateStatus.active;
      }
    } else {
      consecutiveInTolerance = 0;
      status = MetricGateStatus.lockedOut;
    }
  }

  /// Updates the underlying model on a refit.
  ///
  /// If the new model's prediction at [now] differs by <= 0.5 * threshold from
  /// the old model, the gate status and hysteresis counter are preserved.
  /// Otherwise, resets to [MetricGateStatus.lockedOut] with 0 counter.
  void updateModel(
    DiurnalModel? newModel, {
    DiurnalFitStatus? fitStatus,
    DateTime? now,
  }) {
    if (fitStatus == DiurnalFitStatus.waitingForTimestamps) {
      model = newModel;
      status = MetricGateStatus.waitingForTimestamps;
      consecutiveInTolerance = 0;
      return;
    }

    if (newModel == null) {
      model = null;
      status = MetricGateStatus.learning;
      consecutiveInTolerance = 0;
      return;
    }

    if (!newModel.hasClearDailyPattern) {
      model = newModel;
      threshold = newModel.effectiveThreshold;
      status = MetricGateStatus.noClearPattern;
      consecutiveInTolerance = 0;
      return;
    }

    final oldModel = model;
    final currentTime = now ?? DateTime.now();

    if (oldModel != null && oldModel.hasClearDailyPattern) {
      final oldPred = oldModel.predictDateTime(currentTime);
      final newPred = newModel.predictDateTime(currentTime);
      final diff = (newPred - oldPred).abs();

      if (diff <= 0.5 * threshold) {
        // Model prediction shifted insignificantly: keep status and hysteresis counter
        model = newModel;
        threshold = newModel.effectiveThreshold;
        return;
      }
    }

    // Materially different model or initial fit: start locked out
    model = newModel;
    threshold = newModel.effectiveThreshold;
    status = MetricGateStatus.lockedOut;
    consecutiveInTolerance = 0;
  }

  /// Creates an identical copy of this tracker preserving state.
  MetricGateTracker clone() {
    final copy = MetricGateTracker(
      metricName: metricName,
      model: model,
      initialStatus: status,
    );
    copy.consecutiveInTolerance = consecutiveInTolerance;
    copy.threshold = threshold;
    copy.lastLiveValue = lastLiveValue;
    copy.lastPredictedValue = lastPredictedValue;
    copy.lastError = lastError;
    return copy;
  }
}

/// Combined residual gate managing Temperature and Air Quality gates.
class ForecastGate {
  ForecastGate({
    DiurnalModel? tempModel,
    DiurnalModel? aqModel,
    DiurnalFitStatus? tempFitStatus,
    DiurnalFitStatus? aqFitStatus,
  }) : tempGate = MetricGateTracker(
         metricName: 'Temperature',
         model: tempModel,
         initialStatus: tempFitStatus == DiurnalFitStatus.waitingForTimestamps
             ? MetricGateStatus.waitingForTimestamps
             : (tempModel == null
                   ? MetricGateStatus.learning
                   : (!tempModel.hasClearDailyPattern
                         ? MetricGateStatus.noClearPattern
                         : MetricGateStatus.lockedOut)),
       ),
       aqGate = MetricGateTracker(
         metricName: 'Air Quality',
         model: aqModel,
         initialStatus: aqFitStatus == DiurnalFitStatus.waitingForTimestamps
             ? MetricGateStatus.waitingForTimestamps
             : (aqModel == null
                   ? MetricGateStatus.learning
                   : (!aqModel.hasClearDailyPattern
                         ? MetricGateStatus.noClearPattern
                         : MetricGateStatus.lockedOut)),
       );

  final MetricGateTracker tempGate;
  final MetricGateTracker aqGate;

  /// Updates the underlying metric models across a refit, preserving gate states
  /// if predictions at [now] are within tolerance.
  void updateModels({
    DiurnalModel? tempModel,
    DiurnalModel? aqModel,
    DiurnalFitStatus? tempFitStatus,
    DiurnalFitStatus? aqFitStatus,
    DateTime? now,
  }) {
    tempGate.updateModel(tempModel, fitStatus: tempFitStatus, now: now);
    aqGate.updateModel(aqModel, fitStatus: aqFitStatus, now: now);
  }

  /// Creates an identical copy of this gate with fresh tracker clones.
  ForecastGate clone() {
    final copy = ForecastGate(tempModel: tempGate.model, aqModel: aqGate.model);
    copy.tempGate.status = tempGate.status;
    copy.tempGate.consecutiveInTolerance = tempGate.consecutiveInTolerance;
    copy.tempGate.threshold = tempGate.threshold;
    copy.tempGate.lastLiveValue = tempGate.lastLiveValue;
    copy.tempGate.lastPredictedValue = tempGate.lastPredictedValue;
    copy.tempGate.lastError = tempGate.lastError;

    copy.aqGate.status = aqGate.status;
    copy.aqGate.consecutiveInTolerance = aqGate.consecutiveInTolerance;
    copy.aqGate.threshold = aqGate.threshold;
    copy.aqGate.lastLiveValue = aqGate.lastLiveValue;
    copy.aqGate.lastPredictedValue = aqGate.lastPredictedValue;
    copy.aqGate.lastError = aqGate.lastError;
    return copy;
  }

  /// Combined status resolving worst state:
  /// waitingForTimestamps > learning > lockedOut (incl. noClearPattern) > active
  ForecastGateStatus get status {
    if (tempGate.status == MetricGateStatus.waitingForTimestamps ||
        aqGate.status == MetricGateStatus.waitingForTimestamps) {
      return ForecastGateStatus.waitingForTimestamps;
    }
    if (tempGate.status == MetricGateStatus.learning ||
        aqGate.status == MetricGateStatus.learning) {
      return ForecastGateStatus.learning;
    }
    if (tempGate.status == MetricGateStatus.lockedOut ||
        aqGate.status == MetricGateStatus.lockedOut ||
        tempGate.status == MetricGateStatus.noClearPattern ||
        aqGate.status == MetricGateStatus.noClearPattern) {
      return ForecastGateStatus.lockedOut;
    }
    return ForecastGateStatus.active;
  }

  /// Processes a live `/system` sample for both metrics.
  void processSample({
    double? temperature,
    double? airQuality,
    required DateTime time,
  }) {
    tempGate.processSample(temperature, time);
    aqGate.processSample(airQuality, time);
  }

  /// Standard explanation copy matching DESIGN.md §5 and PRD §FR-6.
  String get statusExplanation {
    switch (status) {
      case ForecastGateStatus.active:
        return 'Room pattern is predictable.';
      case ForecastGateStatus.lockedOut:
        return 'Predictive layer locked out. Deterministic safety logic in control.';
      case ForecastGateStatus.learning:
        return 'Learning your room\'s pattern.';
      case ForecastGateStatus.waitingForTimestamps:
        return 'Waiting for real timestamps. The device is not sending wall-clock time.';
    }
  }
}
