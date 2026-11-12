import 'package:aerosense_app/data/models/system_state.dart';

/// Contract for live system telemetry and manual fan actuation.
///
/// The UI never touches Firebase directly — it goes through this interface.
abstract class SystemRepository {
  /// Stream of parsed live system state from `/system`.
  Stream<SystemState> watchSystemState();

  /// Stream of raw snapshot value from `/system` for debug display.
  Stream<Object?> watchRawSystem();

  /// Stream of `/config` node from RTDB for runtime configuration parameters.
  Stream<Map<String, dynamic>?> watchConfig();

  /// Requests a timed manual ventilation cycle by writing `true` to `/system/manualToggle`.
  ///
  /// The app NEVER writes `false` to cancel — the firmware automatically resets
  /// `manualToggle` when the run ends or if the request is rejected outside Caution.
  Future<void> requestManualVentilation();

  /// Stream of app-to-Firebase connection state (`.info/connected`).
  Stream<bool> watchConnected();
}
