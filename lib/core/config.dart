/// Application configuration flags and default parameters.
class AppConfig {
  AppConfig._();

  /// Application version string matching pubspec.yaml.
  static const String appVersion = '1.0.0+1';

  /// Whether user self-signup is permitted in the UI.
  /// Accounts are managed in Firebase Console by default.
  static const bool allowSignUp = false;

  // --- Ask AeroSense assistant (Phase 7b) ---

  /// The only Gemini model used by the live assistant.
  ///
  /// Verified working with the project's restricted free-tier key. There is no
  /// fallback model: a request either succeeds on this model or falls back to
  /// the deterministic summary in the UI.
  static const String assistantModel = 'gemini-3.5-flash-lite';

  /// Gemini API key supplied at build time.
  ///
  /// `String.fromEnvironment` is compile-time only, so the key is supplied with
  /// `--dart-define-from-file=env.json` (web) or `env.android.json` (Android).
  /// Empty means the live assistant is hidden; "Summarize" still works.
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  /// Where the landing page sends people for the Android build.
  ///
  /// The public GitHub Releases page, not a direct `.apk` file: the page always
  /// lists the newest build, shows its notes, and cannot 404 when an asset is
  /// renamed. It is a plain redirect to GitHub, so the visitor chooses what to
  /// download there.
  static const String apkReleasesUrl =
      'https://github.com/Rambolt375/aerosense-app/releases';

  /// Output cap per answer (the prompt asks for under ~120 words).
  static const int assistantMaxOutputTokens = 600;

  /// Low sampling temperature: the assistant explains given facts, it does not
  /// brainstorm.
  static const double assistantTemperature = 0.3;

  /// Maximum input length for one visitor question.
  static const int assistantMaxInputChars = 300;

  /// Client-side question budget per signed-in uid inside [assistantRateWindow].
  ///
  /// Advisory only: App Check plus the project quota are the real ceiling.
  static const int assistantMaxQuestionsPerWindow = 6;

  /// Sliding window for the per-uid question budget.
  static const Duration assistantRateWindow = Duration(minutes: 10);

  /// Minimum spacing between two accepted questions from the same uid.
  static const Duration assistantMinQuestionSpacing = Duration(
    milliseconds: 1500,
  );

  /// One request is abandoned after this long; the summary is shown instead.
  static const Duration assistantTimeout = Duration(seconds: 20);

  /// Delay before the single retry after a 503 / overloaded response.
  static const Duration assistantRetryDelay = Duration(milliseconds: 1500);

  /// Recent conversation messages kept in memory and sent as chat history.
  static const int assistantMaxMessages = 4;

  /// Artificial latency of the scripted Demo Mode assistant.
  static const Duration assistantFakeLatency = Duration(milliseconds: 300);

  /// Regional Realtime Database URL for asia-southeast1.
  static const String databaseUrl =
      'https://aerosense-502de-default-rtdb.asia-southeast1.firebasedatabase.app';

  /// Expected interval at which firmware writes to `/history` (10 minutes).
  static const Duration expectedLogInterval = Duration(minutes: 10);

  /// Device offline threshold: 2 missed cycles = 2 * 10 min = 20 minutes.
  static const Duration offlineThreshold = Duration(minutes: 20);

  /// Cadence for evaluating device offline status (30 seconds).
  static const Duration freshnessEvaluationInterval = Duration(seconds: 30);

  /// Multiplier relative to log interval to detect chart gaps (2.5x = 25 minutes).
  static const double gapThresholdMultiplier = 2.5;

  /// Minimum historical time span required for diurnal fitting (48 hours).
  static const int minForecastSpanHours = 48;

  /// Minimum number of distinct hourly bins (0..23) required for time-of-day coverage.
  static const int minHourlyBins = 20;

  /// Standard deviation multiplier (k) for the forecast residual gate (FR-6).
  static const double forecastSigmaMultiplier = 3.0;

  /// Hysteresis count: consecutive valid samples needed to return from LOCKED_OUT to ACTIVE.
  static const int forecastHysteresisSamples = 3;

  /// Minimum temperature residual tolerance floor derived from DHT22 sensor accuracy (±0.5 °C).
  static const double minTempTolerance = 0.5;

  /// Minimum air quality residual tolerance floor for raw ADC noise.
  static const double minAqTolerance = 30.0;

  /// Minimum variance explained (R^2) required to declare a clear daily pattern.
  static const double minR2Pattern = 0.3;

  /// Default duration for a manual ventilation run (5 minutes).
  static const Duration defaultManualDuration = Duration(minutes: 5);

  /// Default duration in seconds for manual ventilation (300 seconds).
  static const int defaultManualDurationSec = 300;

  /// Confirmation timeout waiting for firmware to echo manualToggle (5 seconds).
  static const Duration manualToggleConfirmTimeout = Duration(seconds: 5);

  /// Minimum lead time ahead of predicted peak for pre-ventilation (10 minutes).
  // TODO(confirm): 10-20 minute pre-ventilation window is planned firmware alignment.
  static const Duration preventiveLeadTimeMin = Duration(minutes: 10);

  /// Maximum lead time ahead of predicted peak for pre-ventilation (20 minutes).
  // TODO(confirm): 10-20 minute pre-ventilation window is planned firmware alignment.
  static const Duration preventiveLeadTimeMax = Duration(minutes: 20);

  /// Target planned run time ahead of predicted peak (15 minutes).
  static const Duration preventiveLeadTimeTarget = Duration(minutes: 15);

  /// Minimum cooldown between successive automated pre-ventilation triggers (6 hours).
  // TODO(confirm): firmware cooldown period between triggers.
  static const Duration preventiveCooldown = Duration(hours: 6);
}
