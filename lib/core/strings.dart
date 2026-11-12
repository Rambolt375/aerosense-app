/// Centralized user-facing strings for the AeroSense application.
///
/// Follows DESIGN.md §8: Plain, calm, factual. Short sentences,
/// no exclamation marks, no jargon, no blame.
/// Ready for future localization.
class AppStrings {
  AppStrings._();

  // App & Navigation
  static const appName = 'AeroSense';
  static const appSubtitle = 'Adaptive Ventilation Companion';
  static const navDashboard = 'Dashboard';
  static const navHistory = 'History';
  static const navForecast = 'Forecast';
  static const navSettings = 'Settings';

  // Tier Status (DESIGN.md §8)
  static const tierSafeTitle = 'Room is safe';
  static const tierMediumTitle = 'Room is getting stuffy';
  static const tierDangerTitle = 'Hazardous air detected';

  // Fan Control & Status Headers (DESIGN.md §8)
  static const fanOn = 'Fan on';
  static const fanOff = 'Fan off';
  static const fanVentilate = 'Ventilate';
  static String fanVentilateFor(int minutes) => 'Ventilate for $minutes min';
  static const fanStarting = 'Starting fan...';
  static const fanRunning = 'Fan running';
  static String fanRunningWithCountdown(String countdown) =>
      'Fan running, $countdown left';
  static const fanWaitingForDevice = 'Waiting for the device...';

  // Fan Helper Text (DESIGN.md §8)
  static const fanHelperIdleKnown =
      'Room is stuffy. The fan stays off unless you turn it on.';
  static const fanHelperIdleUnknown =
      'The fan runs for a fixed time set by the device.';
  static const fanHelperRunning =
      'Manual ventilation is on. The fan is running.';
  static const fanHelperDangerLatched = 'Fan stays on until the room is safe.';
  static const fanHelperSafe =
      'The fan stays off while the room is safe. Manual ventilation is available when the room gets stuffy.';
  static const fanHelperDanger =
      'Safety override active. The fan is forced on and manual control is bypassed.';
  static const fanHelperWaitingForDevice =
      'Waiting for the device to turn off the fan.';
  static const fanHelperPending = 'Sending request to device...';
  static const fanHelperAppOffline = 'App is offline. Fan control unavailable.';
  static const fanHelperDeviceOffline =
      'Device offline. Fan control unavailable.';

  // Snackbar Errors & Feedback
  static const fanErrorStartFailed =
      "The device didn't start the fan. The room may no longer be in the stuffy range.";
  static const fanErrorConnection =
      'Failed to start ventilation. Check connection.';

  // History (PRD FR-5 & DESIGN.md §5)
  static const historyEmptyTitle = 'No history yet';
  static const historyEmptySubtitle = 'The device logs every 10 minutes.';
  static const historyNoReadingsInRange = 'No readings in this range';
  static const historySyntheticWarning =
      "Time axis is estimated: the device isn't sending timestamps.";

  // Forecast (PRD FR-6 & DESIGN.md §5)
  static const forecastStatus = 'Forecast status';
  static const forecastLockedOut =
      'Predictive layer locked out. Deterministic safety logic in control.';
  static const forecastDeviceOffline =
      'Device is offline. Predictive layer is suspended.';
  static const forecastLearning =
      'Awaiting sufficient history data to fit 24-hour diurnal sinusoidal wave.';

  // Accessibility Announcements
  static const semanticsVentilationStarted = 'Ventilation started';
  static const semanticsVentilationEnded = 'Ventilation ended';
}
