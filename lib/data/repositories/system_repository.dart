import 'package:aerosense_app/data/models/system_state.dart';

/// Abstract contract for live system state telemetry and manual fan actuation.
abstract class SystemRepository {
  /// Stream of live system state events from `/system`.
  Stream<SystemState> watchSystemState();

  /// Sets the manual fan toggle at `/system/manualToggle`.
  ///
  /// CRITICAL: Writes ONLY to `/system/manualToggle`. Never overwrites the whole `/system` node.
  Future<void> setManualToggle(bool value);

  /// Stream of connection status to the backend.
  Stream<bool> watchConnected();
}
