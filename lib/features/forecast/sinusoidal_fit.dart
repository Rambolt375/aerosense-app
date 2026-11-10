import 'dart:math' as math;

/// Computes the number of seconds elapsed since midnight for [dt].
///
/// Uses [dt.hour], [dt.minute], [dt.second], and [dt.millisecond] directly,
/// making the computation independent of host machine timezone shifts.
double secondsSinceMidnight(DateTime dt) {
  return dt.hour * 3600.0 +
      dt.minute * 60.0 +
      dt.second +
      dt.millisecond / 1000.0;
}

/// Coefficients of the linearized diurnal sinusoidal model:
///   y(t) = a * sin(omega * t) + b * cos(omega * t) + C
/// equivalent to:
///   y(t) = A * sin(omega * t + phi) + C
/// where omega = 2 * pi / 86400.
class DiurnalCoefficients {
  const DiurnalCoefficients({
    required this.a,
    required this.b,
    required this.c,
    required this.amplitude,
    required this.phase,
    required this.peakSeconds,
  });

  /// Linear sine coefficient.
  final double a;

  /// Linear cosine coefficient.
  final double b;

  /// Constant DC offset C.
  final double c;

  /// Amplitude A = sqrt(a^2 + b^2).
  final double amplitude;

  /// Phase angle phi = atan2(b, a) in radians [-pi, pi].
  final double phase;

  /// Seconds since local midnight when the model reaches its peak [0, 86400).
  final double peakSeconds;

  /// Evaluates the fitted model at [secondsOfDay] (seconds since local midnight).
  double predict(double secondsOfDay) {
    const omega = 2 * math.pi / 86400.0;
    return a * math.sin(omega * secondsOfDay) +
        b * math.cos(omega * secondsOfDay) +
        c;
  }

  /// Evaluates the fitted model for a given local [DateTime].
  double predictDateTime(DateTime dt) {
    return predict(secondsSinceMidnight(dt));
  }

  /// Formatted peak time of day (HH:mm).
  String get formattedPeakTime {
    final totalMinutes = (peakSeconds / 60.0).round() % 1440;
    final hours = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final minutes = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$hours:$minutes';
  }
}

/// Solves the 3x3 linear least-squares normal equations for:
///   y_i = a * sin(omega * t_i) + b * cos(omega * t_i) + C
/// using Gaussian elimination with partial pivoting.
///
/// Returns [DiurnalCoefficients] on success, or `null` if the system is
/// singular or ill-conditioned (determined relative to [relativeSingularThreshold]).
DiurnalCoefficients? fitSinusoid(
  List<double> times,
  List<double> values, {
  double relativeSingularThreshold = 1e-12,
}) {
  final n = times.length;
  if (n < 3 || n != values.length) return null;

  const omega = 2 * math.pi / 86400.0;

  var s2 = 0.0;
  var c2 = 0.0;
  var sc = 0.0;
  var sSum = 0.0;
  var cSum = 0.0;
  var sy = 0.0;
  var cy = 0.0;
  var ySum = 0.0;

  for (var i = 0; i < n; i++) {
    final t = times[i];
    final y = values[i];
    final s = math.sin(omega * t);
    final c = math.cos(omega * t);

    s2 += s * s;
    c2 += c * c;
    sc += s * c;
    sSum += s;
    cSum += c;
    sy += s * y;
    cy += c * y;
    ySum += y;
  }

  // 3x3 normal equation matrix: M * [a, b, C]^T = V
  final m = [
    [s2, sc, sSum],
    [sc, c2, cSum],
    [sSum, cSum, n.toDouble()],
  ];
  final v = [sy, cy, ySum];

  // Compute maximum absolute element in M for relative singularity thresholding
  var maxScale = 0.0;
  for (var r = 0; r < 3; r++) {
    for (var col = 0; col < 3; col++) {
      final absVal = m[r][col].abs();
      if (absVal > maxScale) maxScale = absVal;
    }
  }
  if (maxScale == 0.0) return null;
  final singularCutoff = maxScale * relativeSingularThreshold;

  // Gaussian elimination with partial pivoting
  for (var k = 0; k < 2; k++) {
    var maxRow = k;
    var maxVal = m[k][k].abs();
    for (var r = k + 1; r < 3; r++) {
      final absVal = m[r][k].abs();
      if (absVal > maxVal) {
        maxVal = absVal;
        maxRow = r;
      }
    }

    if (maxVal < singularCutoff) return null;

    if (maxRow != k) {
      final tempRow = m[k];
      m[k] = m[maxRow];
      m[maxRow] = tempRow;
      final tempV = v[k];
      v[k] = v[maxRow];
      v[maxRow] = tempV;
    }

    for (var r = k + 1; r < 3; r++) {
      final factor = m[r][k] / m[k][k];
      for (var c = k; c < 3; c++) {
        m[r][c] -= factor * m[k][c];
      }
      v[r] -= factor * v[k];
    }
  }

  if (m[2][2].abs() < singularCutoff) return null;

  // Back substitution
  final c = v[2] / m[2][2];
  final b = (v[1] - m[1][2] * c) / m[1][1];
  final a = (v[0] - m[0][1] * b - m[0][2] * c) / m[0][0];

  final amplitude = math.sqrt(a * a + b * b);
  final phase = math.atan2(b, a);

  // Peak time: omega * t_peak + phi = pi/2 -> t_peak = (pi/2 - phi) / omega
  // (pi/2) / (2*pi/86400) = 86400 / 4 = 21600 seconds
  var peakSeconds = (21600.0 - (86400.0 / (2 * math.pi)) * phase) % 86400.0;
  if (peakSeconds < 0) peakSeconds += 86400.0;

  return DiurnalCoefficients(
    a: a,
    b: b,
    c: c,
    amplitude: amplitude,
    phase: phase,
    peakSeconds: peakSeconds,
  );
}
