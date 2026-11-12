import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/time_utils.dart';

void main() {
  group('parseTimestamp', () {
    // --- null / non-numeric / garbage ---
    test('null → null', () => expect(parseTimestamp(null), isNull));
    test('bool true → null', () => expect(parseTimestamp(true), isNull));
    test('bool false → null', () => expect(parseTimestamp(false), isNull));
    test('Map → null', () => expect(parseTimestamp(<String, int>{}), isNull));
    test('List → null', () => expect(parseTimestamp([1, 2, 3]), isNull));
    test(
      'unparseable string → null',
      () => expect(parseTimestamp('not-a-date'), isNull),
    );
    test('empty string → null', () => expect(parseTimestamp(''), isNull));

    // --- epoch seconds (int ≤ 1e12) ---
    test('epoch seconds int → DateTime in Nov 2023', () {
      // 1_700_000_000 s = 2023-11-14 22:13:20 UTC
      final dt = parseTimestamp(1700000000);
      expect(dt, isNotNull);
      expect(dt!.year, 2023);
      expect(dt.month, 11);
    });

    // --- epoch milliseconds (int > 1e12) ---
    test('epoch milliseconds int → same DateTime in Nov 2023', () {
      final dtSeconds = parseTimestamp(1700000000);
      final dtMs = parseTimestamp(1700000000000);
      expect(dtMs, isNotNull);
      expect(dtMs!.year, dtSeconds!.year);
      expect(dtMs.month, dtSeconds.month);
      expect(dtMs.day, dtSeconds.day);
    });

    // --- epoch seconds as double ---
    test('epoch seconds double → valid DateTime', () {
      final dt = parseTimestamp(1700000000.0);
      expect(dt, isNotNull);
      expect(dt!.year, 2023);
    });

    // --- ISO 8601 strings ---
    test('ISO 8601 UTC string → correct DateTime in local time (toLocal)', () {
      const utcString = '2024-05-01T13:00:00Z';
      final expectedLocal = DateTime.parse(utcString).toLocal();
      final dt = parseTimestamp(utcString);
      expect(dt, isNotNull);
      expect(dt!.isUtc, isFalse);
      expect(dt, equals(expectedLocal));
      expect(dt.year, 2024);
      expect(dt.month, 5);
      expect(dt.day, 1);
    });
    test('ISO 8601 without Z → parsed', () {
      final dt = parseTimestamp('2024-05-01T13:00:00');
      expect(dt, isNotNull);
      expect(dt!.year, 2024);
    });

    // --- millis-since-boot heuristic ---
    test('millis-since-boot (45000) → null (year < 2020)', () {
      expect(parseTimestamp(45000), isNull);
    });
    test('millis-since-boot (0) → null (year 1970)', () {
      expect(parseTimestamp(0), isNull);
    });
    test('millis-since-boot (3_600_000, ~1 hour) → null', () {
      // 3_600_000 treated as seconds: year 2084 — does NOT trigger the guard
      // 3_600_000 treated as ms: year 1970 + 1h — DOES trigger guard
      // Value is 3_600_000 ≤ 1e12, so treated as seconds: 3_600_000 s from epoch
      // = 1970-01-01 + ~41 days = 1970-02-11 → year 1970 < 2020 → null
      expect(parseTimestamp(3600000), isNull);
    });

    // --- year boundary ---
    test('value that resolves to exactly year 2020 is NOT nulled', () {
      // 2020-01-01T00:00:00Z in epoch seconds = 1577836800
      final dt = parseTimestamp(1577836800);
      expect(dt, isNotNull);
      expect(dt!.year, 2020);
    });
    test('value that resolves to year 2019 → null', () {
      // 2018-01-01T00:00:00Z in epoch seconds = 1514764800.
      // Safely in 2018 regardless of local timezone — avoids the UTC+N
      // boundary ambiguity that existed with the original 1577836799 value.
      expect(parseTimestamp(1514764800), isNull);
    });

    // --- silent mode for manualEndsAt ---
    test('silent: true with 0, "0", and null returns null silently', () {
      expect(parseTimestamp(null, silent: true), isNull);
      expect(parseTimestamp(0, silent: true), isNull);
      expect(parseTimestamp('0', silent: true), isNull);
      expect(parseTimestamp(45000, silent: true), isNull);
    });
  });
}
