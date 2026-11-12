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
/// If [silent] is true, `0`, `'0'`, and values resolving to year < 2020 are treated
/// as "no value" silently without emitting `// TODO(confirm)` logs. Used for
/// `/system/manualEndsAt` where 0 or null represents inactive manual ventilation.
/// Returns null for null input, unrecognised types, unparseable strings,
/// and apparent boot-millisecond values.
// TODO(confirm): timestamp format in /history — confirm once real data exists.
DateTime? parseTimestamp(dynamic value, {bool silent = false}) {
  if (value == null) return null;
  if (silent && (value == 0 || value == '0')) return null;

  if (value is String) {
    final dt = DateTime.tryParse(value);
    if (dt == null) return null;
    return _guardYear(dt.toLocal(), silent: silent);
  }

  if (value is num) {
    final ms = value > 1e12 ? value.toInt() : value.toInt() * 1000;
    final dt = DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true).toLocal();
    return _guardYear(dt, silent: silent);
  }

  return null;
}

/// Returns null if [dt] predates 2020 — a heuristic for millis()-since-boot.
DateTime? _guardYear(DateTime dt, {bool silent = false}) {
  if (dt.year < 2020) {
    if (!silent) {
      debugPrint(
        '// TODO(confirm) timestamp-format: parsed DateTime year=${dt.year} '
        'looks like millis-since-boot, not wall-clock time. '
        'Returning null; chart will fall back to push-key ordering.',
      );
    }
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
