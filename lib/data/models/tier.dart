import 'package:flutter/foundation.dart';
import 'package:aerosense_app/core/thresholds.dart';

/// Ventilation state tiers determined by the firmware or by value fallback.
///
/// The ESP32 firmware owns the actual tier decision. The app derives tier
/// from [statusMessage] as the primary source, falling back to sensor values.
/// See PRD §5.3 for the full tier-determination rules.
enum Tier {
  safe,
  medium,
  danger;

  /// Parses the [statusMessage] written by the ESP32 firmware.
  ///
  /// Returns null when the message is null, empty, or uses an unrecognised
  /// format — the caller falls back to [Tier.fromValues] in that case.
  ///
  /// Recognised formats (case-insensitive, firmware-authoritative):
  ///   - Bare "DANGER", or "DANGER:" prefix / trailing text → [Tier.danger]
  ///   - Bare "CAUTION", "MEDIUM", or "CAUTION:" / "MEDIUM:" prefix / trailing text → [Tier.medium]
  ///   - Bare "NORMAL", "SAFE", "NORMAL:" / "SAFE:" prefix, or "System Safe" → [Tier.safe]
  static Tier? fromStatusMessage(String? msg) {
    if (msg == null) return null;
    final trimmed = msg.trim();
    if (trimmed.isEmpty) return null;

    if (trimmed.toLowerCase() == 'system safe') return Tier.safe;

    // Danger: bare keyword or prefix
    if (RegExp(
      r'^(DANGER)(?::|\s|$)',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return Tier.danger;
    }

    // Caution / Medium: bare keyword or prefix
    if (RegExp(
      r'^(CAUTION|MEDIUM)(?::|\s|$)',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return Tier.medium;
    }

    // Normal / Safe: bare keyword or prefix
    if (RegExp(
      r'^(NORMAL|SAFE)(?::|\s|$)',
      caseSensitive: false,
    ).hasMatch(trimmed)) {
      return Tier.safe;
    }

    return null; // unrecognised format
  }

  /// Derives a tier from raw sensor values using the thresholds in [Thresholds].
  ///
  /// NOTE: Comparisons are inclusive (>=). [Tier.fromValues] cannot model the
  /// 1250 air quality recovery hysteresis implemented in firmware (where returning
  /// to Normal after Caution/Danger requires AQ < 1250). The firmware's
  /// [statusMessage] is authoritative; [fromValues] is strictly a fallback.
  ///
  /// Danger is checked first (worst-indicator-wins). Null values are excluded
  /// — a single null field cannot by itself elevate the tier.
  static Tier fromValues({
    double? temperature,
    double? humidity,
    double? airQuality,
  }) {
    final tempDanger =
        temperature != null && temperature >= Thresholds.tempDangerMin;
    final humDanger =
        Thresholds.useHumidity &&
        humidity != null &&
        humidity >= Thresholds.humidityDangerMin;
    final aqDanger =
        airQuality != null && airQuality >= Thresholds.airQualityDangerMin;
    if (tempDanger || humDanger || aqDanger) return Tier.danger;

    final tempMedium =
        temperature != null && temperature >= Thresholds.tempSafeMax;
    final humMedium =
        Thresholds.useHumidity &&
        humidity != null &&
        humidity >= Thresholds.humiditySafeMax;
    final aqMedium =
        airQuality != null && airQuality >= Thresholds.airQualitySafeMax;
    if (tempMedium || humMedium || aqMedium) return Tier.medium;

    return Tier.safe;
  }

  /// Resolves the authoritative tier from [statusMessage] with a value fallback.
  ///
  /// - If [statusMessage] is recognised → use its tier (primary source).
  /// - If not recognised → fall back to [Tier.fromValues].
  /// - If both are recognised but disagree → log a debug warning and keep
  ///   the message result, because the firmware's own status is authoritative.
  static Tier resolve(
    String? statusMessage, {
    double? temperature,
    double? humidity,
    double? airQuality,
  }) {
    final fromMsg = Tier.fromStatusMessage(statusMessage);
    final fromVals = Tier.fromValues(
      temperature: temperature,
      humidity: humidity,
      airQuality: airQuality,
    );

    if (fromMsg == null) return fromVals;

    if (fromMsg != fromVals) {
      // The firmware's statusMessage disagrees with the threshold calculation.
      // Trust the firmware; log for diagnosis.
      debugPrint(
        'Tier mismatch: statusMessage→$fromMsg, values→$fromVals '
        '(temp=$temperature, hum=$humidity, aq=$airQuality). '
        'Using statusMessage result.',
      );
    }

    return fromMsg;
  }
}
