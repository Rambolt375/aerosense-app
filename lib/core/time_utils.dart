import 'package:flutter/foundation.dart';

/// Parses a raw RTDB timestamp value into a [DateTime] in local time.
///
/// Handles the four formats that may come from the ESP32 firmware:
///   - [int] or [double] > 1e12  → epoch milliseconds
///   - [int] or [double] ≤ 1e12  → epoch seconds (converted to ms)
///   - [String]                   → ISO 8601 via DateTime.tryParse
///   - Any value that resolves to year < 2020 → treated as millis() since
///     boot and returns null; the caller should fall back to push-key ordering.
///
/// Returns null for null input, unrecognised types, unparseable strings,
/// and apparent boot-millisecond values.
// TODO(confirm): timestamp format in /history — confirm once real data exists.
DateTime? parseTimestamp(dynamic value) {
  if (value == null) return null;

  if (value is String) {
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return _guardYear(dt.toLocal());
  }

  if (value is num) {
    final ms = value > 1e12 ? value.toInt() : value.toInt() * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return _guardYear(dt);
  }

  return null;
}

/// Returns null if [dt] predates 2020 — a heuristic for millis()-since-boot.
DateTime? _guardYear(DateTime dt) {
  if (dt.year < 2020) {
    debugPrint(
      '// TODO(confirm) timestamp-format: parsed DateTime year=${dt.year} '
      'looks like millis-since-boot, not wall-clock time. '
      'Returning null; chart will fall back to push-key ordering.',
    );
    return null;
  }
  return dt;
}

/// Parses a raw sensor value from an RTDB snapshot into a [double].
///
/// Accepts [num] (int or double from JSON), converts to double. Returns null
/// for null input, NaN, Infinity, or any non-numeric type. Used by both
/// [SystemState] and [HistoryRecord] to parse temperature, humidity, and
/// airQuality fields.
double? parseSensorDouble(dynamic v) {
  if (v == null) return null;
  if (v is! num) return null;
  final d = v.toDouble();
  if (!d.isFinite) return null;
  return d;
}
