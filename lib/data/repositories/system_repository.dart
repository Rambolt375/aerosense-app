import 'package:aerosense_app/data/models/forecast_preferences.dart';
import 'package:aerosense_app/data/models/system_state.dart';

/// Contract for live system telemetry, manual fan actuation, and pre-ventilation.
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

  /// Stream of `/forecast` node from RTDB for automated pre-ventilation settings.
  Stream<ForecastPreferences> watchForecastPreferences();

  /// Updates user opt-in for automated pre-ventilation (`/forecast/allowPreventive`).
  ///
  /// Can be set to `true` or `false` by team accounts only.
  Future<void> setAllowPreventive(bool allowed);

  /// Requests a pre-ventilation cycle by writing `true` to `/forecast/preventiveTrigger`.
  ///
  /// The app NEVER writes `false`. The firmware keeps `preventiveTrigger = true` for
  /// the whole run and resets it to `false` only when the run ends. If the request is
  /// declined (`allowPreventive` false, Danger tier, or fan busy) the firmware resets
  /// it to `false` immediately without starting the fan.
  Future<void> requestPreventiveTrigger();
}
