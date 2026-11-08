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

  /// Parses the [statusMessage] prefix written by the ESP32 firmware.
  ///
  /// Returns null when the message is null, empty, or uses an unrecognised
  /// prefix — the caller should fall back to [Tier.fromValues] in that case.
  ///
  /// Recognised prefixes (case-sensitive, firmware-authoritative):
  ///   - "DANGER:" → [Tier.danger]
  ///   - "MEDIUM:" → [Tier.medium]
  ///   - "System Safe" (exact) or "SAFE:" prefix → [Tier.safe]
  static Tier? fromStatusMessage(String? msg) {
    if (msg == null || msg.isEmpty) return null;
    if (msg.startsWith('DANGER:')) return Tier.danger;
    if (msg.startsWith('MEDIUM:')) return Tier.medium;
    // "System Safe" is the firmware's idle message; "SAFE:" covers manual overrides.
    if (msg == 'System Safe' || msg.startsWith('SAFE:')) return Tier.safe;
    return null; // unrecognised format
  }

  /// Derives a tier from raw sensor values using the thresholds in [Thresholds].
  ///
  /// Danger is checked first (worst-indicator-wins). Null values are excluded
  /// — a single null field cannot by itself elevate the tier.
  static Tier fromValues({
    double? temperature,
    double? humidity,
    double? airQuality,
  }) {
    final tempDanger =
        temperature != null && temperature > Thresholds.tempDangerMin;
    final humDanger =
        humidity != null && humidity > Thresholds.humidityDangerMin;
    final aqDanger =
        airQuality != null && airQuality > Thresholds.airQualityDangerMin;
    if (tempDanger || humDanger || aqDanger) return Tier.danger;

    final tempMedium =
        temperature != null && temperature >= Thresholds.tempSafeMax;
    final humMedium =
        humidity != null && humidity >= Thresholds.humiditySafeMax;
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
