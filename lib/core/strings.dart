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

  // Device Connection Notices (Requirement 8)
  static String deviceOfflineAt(String? time) => time != null && time.isNotEmpty
      ? 'Device offline. Last data at $time'
      : 'Device offline.';
  static String lastDataAt(String? time) =>
      'Last data at ${time != null && time.isNotEmpty ? time : '--'}';
  static const deviceReconnected = 'Device reconnected';

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

  // Summary & Assistant Entry (Phase 7b)
  static const roomSummaryTitle = 'Room summary';
  static const askAboutRoomTitle = 'Ask about this room';
  static const askAboutRoomBody =
      'Get a plain-language description of what the device reports right now.';
  static const summarize = 'Summarize';
  static const askAeroSense = 'Ask AeroSense';
  static const summaryTitle = 'Summary';
  static const languageEnglish = 'English';
  static const languageIndonesia = 'Indonesia';
  static const summaryCopy = 'Copy';
  static const summaryCopied = 'Summary copied';
  static const summaryDisclaimer =
      'This describes what the device reports. The device decides safety.';
  static const summaryNoDataTitle = 'No reading yet';
  static const summaryNoDataBody =
      'Wait for the first telemetry from the device, then try again.';
  static const summaryClose = 'Close';

  // Ask AeroSense (Phase 7b-2)
  static const assistantIntro =
      'Ask about the readings in this room. Answers are based only on what the '
      'device reports.';
  static const assistantDisclaimer =
      'AI-generated, may be wrong. The device alert is authoritative.';
  static const assistantPrivacy =
      "Questions are sent to Google's Gemini service. "
      "Don't type personal information.";
  static const assistantInputHint = 'Ask about this room';
  static const assistantSend = 'Send';
  static const assistantThinking = 'Thinking...';
  static const assistantErrorTitle = "The assistant couldn't answer";
  static const assistantErrorBody = 'Here is the room summary instead.';
  static const assistantUnavailableBody =
      "The assistant isn't available in this build. "
      'Here is the room summary instead.';
  static const assistantFailureQuota =
      'The assistant has reached its usage limit for now. '
      'Here is the room summary instead.';
  static const assistantFailureService =
      "The assistant service isn't available right now. "
      'Here is the room summary instead.';
  static const assistantFailureNetwork =
      "Couldn't reach the assistant. Check the connection and try again. "
      'Here is the room summary instead.';
  static const assistantFailureBlocked =
      "The assistant couldn't answer that question. "
      'Try asking about the readings instead. Here is the room summary.';
  static const assistantFailureEmpty =
      'The assistant returned no answer. '
      'Here is the room summary instead.';
  static const assistantFailureUnknown =
      "The assistant couldn't answer just now. "
      'Here is the room summary instead.';
  static const assistantRateLimitedTitle = 'Question limit reached';
  static String assistantRateLimitedBody(String wait) =>
      'You can ask again in $wait. Here is the room summary.';
  static const assistantTryAgain = 'Try again';
  static const assistantSummaryFallback = 'Room summary';
  static const assistantChipsEnglish = <String>[
    'Is the room OK right now?',
    'Why is it in Caution?',
    'When is it warmest?',
  ];
  static const assistantChipsIndonesian = <String>[
    'Apakah ruangan aman sekarang?',
    'Mengapa berstatus Caution?',
    'Kapan paling hangat?',
  ];

  // Accessibility Announcements
  static const semanticsVentilationStarted = 'Ventilation started';
  static const semanticsVentilationEnded = 'Ventilation ended';
}
