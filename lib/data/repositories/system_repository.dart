import 'package:aerosense_app/data/models/system_state.dart';

/// Contract for live system telemetry and manual fan actuation.
///
/// The UI never touches Firebase directly — it goes through this interface.
abstract class SystemRepository {
  /// Stream of parsed live system state from `/system`.
  Stream<SystemState> watchSystemState();

  /// Stream of raw snapshot value from `/system` for debug display.
  Stream<Object?> watchRawSystem();

  /// Sets `/system/manualToggle` to [value].
  ///
  /// CRITICAL — firmware write rule: writes ONLY to `/system/manualToggle`.
  /// Never calls set() on the whole `/system` node. See PRD §5.4.
  Future<void> setManualToggle(bool value);

  /// Stream of app-to-Firebase connection state (`.info/connected`).
  Stream<bool> watchConnected();
}
