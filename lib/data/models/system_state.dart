import 'package:aerosense_app/data/models/tier.dart';

/// Live system state read from `/system`.
///
/// NOTE: Defensive model stub for Phase 0. Fleshed out in Phase 1 with
/// full fromJson / serialization once DATA_SAMPLE.json is provided.
class SystemState {
  const SystemState({
    this.temperature,
    this.humidity,
    this.airQuality,
    this.fanStatus,
    this.manualToggle = false,
    this.statusMessage = '',
    this.tier = Tier.safe,
    this.lastSeen,
  });

  final double? temperature;
  final double? humidity;
  final double? airQuality;
  // TODO(confirm): fanStatus type - bool vs string "ON"/"OFF"
  final dynamic fanStatus;
  final bool manualToggle;
  final String statusMessage;
  final Tier tier;
  // TODO(confirm): lastSeen field availability
  final DateTime? lastSeen;
}
