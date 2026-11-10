import 'dart:math' as math;

import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/features/forecast/sinusoidal_fit.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';

/// Computes the median of a list of numbers.
double computeMedian(List<double> values) {
  if (values.isEmpty) return 0.0;
  final sorted = List<double>.from(values)..sort();
  final mid = sorted.length ~/ 2;
  if (sorted.length % 2 == 1) {
    return sorted[mid];
  } else {
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }
}

/// Computes the normalized Median Absolute Deviation (MAD):
///   sigma_MAD = 1.4826 * median(|x_i - median(x)|)
/// which provides an outlier-resistant standard deviation estimate with
/// a 50% breakdown point (PRD §FR-6 requirement).
double computeMad(List<double> values) {
  if (values.length < 2) return 0.0;
  final med = computeMedian(values);
  final deviations = values.map((v) => (v - med).abs()).toList();
  final mad = computeMedian(deviations);
  return 1.4826 * mad;
}

/// Status of the diurnal sinusoidal model fit.
enum DiurnalFitStatus {
  /// Model fitted successfully and ready for evaluation.
  ready,

  /// Insufficient data span, coverage, or sample count.
  learning,

  /// Historical records contain synthetic timestamps.
  waitingForTimestamps,

  /// Fitting algorithm failed (e.g. singular matrix).
  failed,
}

/// Fitted diurnal model for a single metric (Temperature or Air Quality).
class DiurnalModel {
  const DiurnalModel({
    required this.coefficients,
    required this.residualStdDev,
    required this.effectiveThreshold,
    required this.hasClearDailyPattern,
    this.rSquared = 0.0,
  });

  /// Sinusoidal coefficients (a, b, C, A, phi, peakSeconds).
  final DiurnalCoefficients coefficients;

  /// Standard deviation of inlier residuals.
  final double residualStdDev;

  /// Effective tolerance threshold: max(k * residualStdDev, noiseFloor).
  final double effectiveThreshold;

  /// Whether the wave explains sufficient variance (R^2 >= minR2Pattern).
  /// If false, the room has no clear daily pattern (peak time is hidden).
  final bool hasClearDailyPattern;

  /// Fraction of variance explained by the diurnal sinusoidal wave (0.0 to 1.0).
  final double rSquared;

  /// Amplitude A of the 24 h wave.
  double get amplitude => coefficients.amplitude;

  /// DC offset C (daily mean).
  double get c => coefficients.c;

  /// Phase angle in radians.
  double get phase => coefficients.phase;

  /// Formatted peak time (e.g. "15:00") or null if no clear daily pattern exists.
  String? get formattedPeakTime =>
      hasClearDailyPattern ? coefficients.formattedPeakTime : null;

  /// Predicts the value at [secondsOfDay] (seconds since local midnight).
  double predict(double secondsOfDay) => coefficients.predict(secondsOfDay);

  /// Predicts the value for a local [DateTime].
  double predictDateTime(DateTime dt) => coefficients.predictDateTime(dt);
}

/// Result of robust diurnal fitting across a historical dataset.
class DiurnalFitResult {
  const DiurnalFitResult({
    required this.status,
    this.model,
    this.learningPercentage = 0,
    this.statusMessage,
  });

  /// High-level fitting status.
  final DiurnalFitStatus status;

  /// Fitted model if [status] is [DiurnalFitStatus.ready].
  final DiurnalModel? model;

  /// Progress towards completing the learning phase (0..99%).
  final int learningPercentage;

  /// Explanatory status message.
  final String? statusMessage;
}

/// Fits a diurnal sinusoidal model using two-pass robust least squares.
///
/// Steps:
/// 1. Reuses Phase 4 timestamp resolution. Refuses fit if timestamps are synthetic.
/// 2. Validates learning requirements: 24 h span AND >= 20 hourly bins (production).
/// 3. Pass 1: Initial ordinary least-squares fit across all valid points.
/// 4. Outlier rejection: Computes 1.4826 * MAD of residuals and filters inliers (|r| <= 3 * scale).
/// 5. Pass 2: Re-fits on inliers to prevent anomaly distortion and threshold inflation.
/// 6. Enforces sensor accuracy floor (DHT22 0.5 °C / AQ floor) and checks variance explained (R^2).
DiurnalFitResult fitRobustDiurnal({
  required List<HistoryRecord> records,
  required double? Function(HistoryRecord) extractor,
  required double noiseFloor,
  bool isDemo = false,
  double sigmaMultiplier = AppConfig.forecastSigmaMultiplier,
  double minR2Pattern = AppConfig.minR2Pattern,
}) {
  if (records.isEmpty) {
    return const DiurnalFitResult(
      status: DiurnalFitStatus.learning,
      learningPercentage: 0,
    );
  }

  // 1. Timestamp resolution check (PRD §5.2 rule: never fit synthetic timestamps)
  final resolved = resolveTimestamps(records);
  if (resolved.isSynthetic) {
    return const DiurnalFitResult(
      status: DiurnalFitStatus.waitingForTimestamps,
      statusMessage: 'Waiting for real timestamps',
    );
  }

  // Extract valid points
  final times = <double>[];
  final values = <double>[];
  final validRecords = <HistoryRecord>[];

  for (final r in resolved.records) {
    final val = extractor(r);
    if (val != null && !val.isNaN && r.timestamp != null) {
      times.add(secondsSinceMidnight(r.timestamp!));
      values.add(val);
      validRecords.add(r);
    }
  }

  final n = times.length;
  if (n < 3) {
    return const DiurnalFitResult(
      status: DiurnalFitStatus.learning,
      learningPercentage: 0,
    );
  }

  // 2. Learning data requirements check (span >= 48 h and >= 20 hourly bins)
  // Non-negotiable: point-count gate removed; point counts used for progress display only.
  // Demo mode uses the exact same production rules (fake history spans 7 days).
  final oldest = validRecords.first.timestamp!;
  final newest = validRecords.last.timestamp!;
  final timeSpan = newest.difference(oldest);

  final hourlyBins = <int>{};
  for (final r in validRecords) {
    hourlyBins.add(r.timestamp!.hour);
  }

  final expectedPoints =
      (AppConfig.minForecastSpanHours * 60) ~/
      AppConfig.expectedLogInterval.inMinutes;
  final pointProgress = n / expectedPoints;
  final spanProgress =
      timeSpan.inMinutes / (AppConfig.minForecastSpanHours * 60);
  final coverageProgress = hourlyBins.length / AppConfig.minHourlyBins;

  final minProgress = math.min(
    pointProgress,
    math.min(spanProgress, coverageProgress),
  );

  if (timeSpan < Duration(hours: AppConfig.minForecastSpanHours) ||
      hourlyBins.length < AppConfig.minHourlyBins) {
    final pct = (minProgress * 100).clamp(0, 99).floor();
    return DiurnalFitResult(
      status: DiurnalFitStatus.learning,
      learningPercentage: pct,
    );
  }

  // 3. Pass 1: Fit sinusoid across all valid data points
  final pass1 = fitSinusoid(times, values);
  if (pass1 == null) {
    return const DiurnalFitResult(status: DiurnalFitStatus.failed);
  }

  // 4. Outlier rejection using 1.4826 * MAD
  final residuals = <double>[];
  for (var i = 0; i < n; i++) {
    residuals.add(values[i] - pass1.predict(times[i]));
  }

  final madSigma = computeMad(residuals);
  final medResidual = computeMedian(residuals);
  final effectiveScale = math.max(madSigma, noiseFloor);
  final outlierCutoff = 3.0 * effectiveScale;

  final inlierTimes = <double>[];
  final inlierValues = <double>[];

  for (var i = 0; i < n; i++) {
    if ((residuals[i] - medResidual).abs() <= outlierCutoff) {
      inlierTimes.add(times[i]);
      inlierValues.add(values[i]);
    }
  }

  // 5. Pass 2: Re-fit exclusively on inliers
  final pass2 = (inlierTimes.length >= 3)
      ? (fitSinusoid(inlierTimes, inlierValues) ?? pass1)
      : pass1;

  final evalTimes = inlierTimes.length >= 3 ? inlierTimes : times;
  final evalValues = inlierValues.length >= 3 ? inlierValues : values;

  // 6. Compute inlier residual standard deviation and variance explained (R^2)
  var sumSq = 0.0;
  var sumY = 0.0;
  for (var i = 0; i < evalTimes.length; i++) {
    sumY += evalValues[i];
  }
  final meanY = sumY / evalTimes.length;

  var ssTot = 0.0;
  for (var i = 0; i < evalTimes.length; i++) {
    final diff = evalValues[i] - pass2.predict(evalTimes[i]);
    sumSq += diff * diff;
    final devMean = evalValues[i] - meanY;
    ssTot += devMean * devMean;
  }
  final residualStdDev = math.sqrt(sumSq / evalTimes.length);
  final rSquared = ssTot > 0.0 ? (1.0 - (sumSq / ssTot)) : 0.0;

  // Effective confidence threshold: max(k * stddev, noiseFloor)
  final effectiveThreshold = math.max(
    sigmaMultiplier * residualStdDev,
    noiseFloor,
  );

  // 7. Check if variance explained (R^2) meets pattern threshold
  final hasClearDailyPattern = rSquared >= minR2Pattern;

  return DiurnalFitResult(
    status: DiurnalFitStatus.ready,
    model: DiurnalModel(
      coefficients: pass2,
      residualStdDev: residualStdDev,
      effectiveThreshold: effectiveThreshold,
      hasClearDailyPattern: hasClearDailyPattern,
      rSquared: rSquared,
    ),
  );
}
