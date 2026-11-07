/// Single archived telemetry record from `/history`.
///
/// NOTE: Defensive model stub for Phase 0. Fleshed out in Phase 1 with
/// parseTimestamp() once real sample timestamps are confirmed.
class HistoryRecord {
  const HistoryRecord({
    this.timestamp,
    this.temperature,
    this.humidity,
    this.airQuality,
  });

  // TODO(confirm): timestamp format (epoch seconds, ms, millis since boot, or ISO string)
  final DateTime? timestamp;
  final double? temperature;
  final double? humidity;
  final double? airQuality;
}
