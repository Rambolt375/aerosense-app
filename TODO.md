# TODO.md: AeroSense App progress

> Living checklist. The agent updates this at the end of every work session: tick items, add notes, and log decisions. Spec lives in `PRD_AeroSense_App.md`; don't duplicate it here.
> **Current phase:** 6a (✅ COMPLETE — timed manual ventilation; awaiting user review before Phase 6b)

## Blockers / open questions (owner: human)

- [x] Paste real `/system` JSON into `DATA_SAMPLE.json` (confirmed: `airQuality`, `fanStatus: "OFF"`, `humidity`, `statusMessage`, `temperature`; no `manualToggle`, no `lastSeen`)
- [ ] Confirm `/history` timestamp format/units once firmware creates the node (currently parsed defensively for epoch s/ms and ISO 8601)
- [ ] Confirm firmware updates `/system` without erasing `manualToggle` (no whole-node `setJSON`)
- [ ] Ask firmware owner to add `lastSeen` to `/system` (optional, enables stale-device detection; staleness currently a no-op; device offline is tracked via newest `/history` record)
- [x] Firebase project ID (`aerosense-502de`), RTDB URL (`asia-southeast1`)
- [ ] Confirm whether firmware resets `manualToggle` to `false` on boot
- [ ] Confirm whether humidity is used in firmware tier logic (currently marked `// TODO(confirm)`)
- [ ] Pre-ventilation / predictive fan start: postponed pending firmware design
- [ ] Add Inter font files to `assets/fonts/` (Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf) and uncomment `fonts` block in `pubspec.yaml`
- [x] Run `flutterfire configure` to register the Android app in the Firebase project and generate final `firebase_options.dart`
- [ ] Hardware check: toggle in Medium clicks the relay; locked in Danger (needs real ESP32)
- [x] Hardware check: verify real firmware status message strings against PRD Table III assumptions (confirmed: bare/prefixed keywords case-insensitive, Normal/Safe, Caution/Medium, Danger)

## Phase 0: Setup
- [x] Add dependencies (riverpod, go_router, firebase_*, fl_chart, intl)
- [x] `firebase_options.dart` generated via `flutterfire configure`; verified regional asia-southeast1 `databaseURL` on both Web and Android
- [x] Folder structure, theme (`TierColors` + `AppColors` ThemeExtensions, explicit ColorScheme, light & dark), router skeleton with responsive layout
- [x] `flutter analyze` clean (0 issues); `flutter test` passing (5 tests)

## Phase 1: Auth + data layer
- [x] Login screen, session persistence, route guard
- [x] Models: `SystemState`, `HistoryRecord`, `Tier` (+ `parseTimestamp`, `parseSensorDouble`)
- [x] Tier tests incl. boundary values (28, 32, 60, 75, 1000, 2000, and exact `DATA_SAMPLE.json` parsing)
- [x] Firebase repositories (auth, system, history) + fake repositories
- [x] Debug screen prints a live `/system` object (`watchRawSystem`)
- [x] All tests passing (72 tests), `flutter analyze` clean (0 issues)

## Phase 2: Live dashboard
- [x] Metric tiles (temperature, humidity, air quality raw index), tabular figures, DESIGN.md tokens
- [x] Per-metric tier badges via shared `MetricTier` helper + boundary tests
- [x] Tier banner with title, icon, verbatim firmware `statusMessage`, and Danger opacity pulse (respects `MediaQuery.disableAnimations`)
- [x] Connection chip in AppBar header ("Online" / "Offline")
- [x] Fan status card with sentence case ("Fan On" / "Fan Off")
- [x] Optimistic manual toggle via Riverpod `Notifier`: 5 s timeout, stream reconciliation, debug log on revert
- [x] Danger tier safety: switch locked/disabled, reflects `fanOn`, never writes to RTDB (verified with test)
- [x] Safe tier with manual override active displays: "Manual override is on. The fan is running."
- [x] Loading skeletons (`surfaceContainerHighest`) and error card with Retry for stream failure
- [x] In-router `/splash` route preserving `from` query param and redirecting upon auth resolution
- [x] Responsive layout: single column (< 600 dp), 2 columns (600–899 dp), 3 columns with max-width 1200 dp centered on desktop (≥ 900 dp)
- [ ] Hardware check: toggle in Medium clicks the relay; locked in Danger (needs real ESP32)

## Phase 3: Demo Mode (resequenced ahead of History)
- [x] Fake repositories wired behind a dynamic runtime switch in Settings and `--dart-define=DEMO=true` build flag
- [x] `demoModeProvider` (`Notifier<bool>`) controlling dynamic repository swapping without app reload
- [x] Persistent "DEMO MODE" ribbon across all routes per DESIGN.md §5, with `MediaQuery.removePadding(removeTop: true)` for notched screens
- [x] "Try Demo Mode" button on `LoginScreen` allowing instant unauthenticated evaluation in release builds
- [x] `FakeSystemRepository` simulating ESP32 firmware: computes tier from `Thresholds`, forces fan ON in Danger, honors `manualToggle` in Safe/Medium, omits `lastSeen`, omits `manualToggle` in raw until first write, uses exact firmware strings
- [x] Scripted simulation scenarios: kitchen smoke spike & recovery, heat spike ramp (+0.5 °C/tick to ~33 °C) & recovery, and reset to baseline
- [x] Timer lifecycle management: ticker starts on stream listen, stops when all listeners cancel, disposes when demo mode turns off (verified with test)
- [x] `FakeHistoryRepository` generating 7-day deterministic diurnal dataset (2016 records, 5-min intervals, anchor rounded to 5-min boundary, dominant 24 h air quality wave, relative anomaly injection flag)
- [x] All 155 tests passing, `flutter analyze` 0 issues

## Phase 4: History (awaits firmware `/history` generation)
- [x] Fetch `limitToLast`, live append via `onChildAdded` / `watchNewRecords()`
- [x] Three synchronized line charts (temperature, humidity, air quality raw index) sharing X time axis
- [x] Safe / Medium / Danger horizontal threshold bands (12% opacity via `withValues(alpha: 0.12)`), 2 px primary line, no area fill, outline grid at 50% opacity
- [x] Legend row (dot + label for Safe, Medium, Danger) and threshold lines with labels on the Y-axis so bands are never color-only
- [x] Responsive Y-axis bounds: `minY = min(dataMin, safeMax) - pad`, `maxY = max(dataMax, dangerMin) + pad` per metric
- [x] Range selector: 1 h (12 records), 6 h (72 records), 24 h (288 records, default), 7 d (2016 records) via `SegmentedButton`
- [x] Gap handling: `splitIntoSegments` splits on gaps > 15 min; segments downsampled proportionally with LTTB (LTTB never sees null spots) and flattened with `FlSpot.nullSpot`
- [x] Timestamp resolution & synthetic fallback: all-null triggers synthetic 5-minute spacing backwards from clock sorted by pushKey; partially null drops null records with warning; never mixes real and synthetic
- [x] Synthetic-timestamp chip using Medium tier tokens and exact text: "Time axis is estimated: the device isn't sending timestamps."
- [x] X ticks on round boundaries (1 h: 15 min; 6 h: 1 h; 24 h: 4 h on hour; 7 d: format "EEE d")
- [x] Pure function merge for live append: dedupes by pushKey (handling `onChildAdded(limitToLast(1))` re-emit), keeps sorted, caps at 2016 records (7 days); subscribes only after initial fetch succeeds; cancels on dispose
- [x] State management: `HistoryNotifier` with `ref.keepAlive()` and manual retry; derived `historyChartDataProvider`
- [x] Separate empty states: "No history yet. The device logs every 5 minutes." (0 records total) and "No readings in this range"
- [x] Accessibility: `Semantics` summary label per chart describing range, current value, min/max, and safe/danger thresholds
- [x] Clean hook for optional Phase 5 forecast dotted series (`[4, 4]`, `textSecondary`)
- [x] Unit tests for pipeline (25 tests) and widget tests for history screen (7 tests) passing; 187 total app tests pass clean

## Phase 5: Forecasting
- [x] Least-squares sinusoidal fit (pure Dart) + unit tests
- [x] Outlier trimming via 1.4826 * MAD on first-pass residuals + unit test for large day-long outlier cluster
- [x] Minimum learning check (>= 24 h span AND >= 20 hourly bins in prod; 36 points in demo) + synthetic timestamp refusal
- [x] Per-metric residual gates (temperature and air quality) with 3-sample hysteresis and DHT22 0.5 °C / ADC noise floor
- [x] Shared 24 h diurnal generator (`generateDiurnalSample`) between `FakeHistoryRepository` and `FakeSystemRepository`
- [x] Riverpod `diurnalFitProvider` (depends on history records only, not range selector) and `forecastGateNotifierProvider`
- [x] Forecast status card: Active / Locked out (with explanation copy) / Learning / Waiting for timestamps + metric pills & predicted peak times
- [x] Dotted prediction curve on charts when metric is Active, sampled at 120 points across the visible range
- [x] All 206 tests passing, `flutter analyze` clean (0 issues)

## Phase 5b: Firmware alignment
- [x] Confirmed firmware thresholds implemented in `lib/core/thresholds.dart`: Temperature Caution $\ge$ 33.5, Danger $\ge$ 36.0; Air Quality Caution $\ge$ 1400, Danger $\ge$ 2000, recovery clear level 1250 (firmware hysteresis); Humidity 60/75 marked `// TODO(confirm)`.
- [x] ThresholdPreset architecture: decoupled `firmware` preset from `demo` preset, exposed via single source of truth `Thresholds.current` with defensive JSON parser (`fromMap`).
- [x] Inclusive comparisons: changed `<` to `<=` and `>` to `>=` across `Tier.fromValues`, `MetricTier`, and test boundary values.
- [x] Firmware status message parsing: case-insensitive bare and prefixed keywords (`NORMAL`/`SAFE` -> Safe, `CAUTION`/`MEDIUM` -> Medium, `DANGER` -> Danger, and `"System Safe"`), displaying app-friendly copy for bare keywords in `TierBanner`.
- [x] Manual fan toggle logic: enabled ONLY in Medium tier; disabled in Safe with explanatory copy ("The fan stays off while the room is safe. Manual ventilation is available when the room gets stuffy."); locked on in Danger; disabled on device offline.
- [x] Timed auto-reset: `FakeSystemRepository` auto-resets `manualToggle` to `false` after configurable duration (default 90 s, injected clock), optimistic toggle reconciles to stream.
- [x] 10-minute cadence: `AppConfig.expectedLogInterval = Duration(minutes: 10)`; `HistoryRange` counts: 1 h = 6, 6 h = 36, 24 h = 144, 7 d = 1008; cap at 1008 records; 2.5x gap threshold; synthetic spacing 10 min; empty state copy "The device logs every 10 minutes."
- [x] Forecast data requirements: removed point-count gate (`AppConfig.minForecastPoints`); forecast requires span $\ge$ 48 h and $\ge$ 20 hourly bins (point counts used for progress display only); demo mode uses production rules.
- [x] Device offline detection: offline after 2 missed cycles = 20 min (`2 * expectedLogInterval`) based on newest `/history` timestamp; evaluated every 30 s on injected clock; unknown if history empty/error; offline notice with "Last data at HH:mm", dimmed metrics, disabled toggle, and locked out forecast gate; demo mode never reports offline.
- [x] RTDB rules: added `/config` node to `database.rules.json` (read: `auth != null`, write: device UID).
- [x] Pre-ventilation / predictive fan start postponed pending firmware design.
- [x] All 229 unit and widget tests passing, `flutter analyze` clean (0 issues).

## Real-device testing fixes (sensor resilience, chart collisions, demo thresholds, offline status)
- [x] Sensor failure resilience: created `lib/core/sensor_validation.dart` defining hardware ranges (-40..80 °C, 0..100 % RH, 0..4095 ADC) and DHT22 unplugged 0/0 failure signature. Integrated into `SystemState.fromJson`, `HistoryNotifier`, `diurnalFitProvider`, and history pipeline; live readings render "--", forecast gate skips them, and chart Y-bounds ignore invalid data while keeping threshold lines visible.
- [x] Demo scenario "Simulate sensor unplugged": added `DemoScenario.sensorUnplugged` in `FakeSystemRepository` and a trigger button in `SettingsScreen` that nulls temperature and humidity for 5 ticks before recovering.
- [x] Chart label collision resolution: pure Dart `lib/features/history/chart_label_utils.dart` drops Y-axis ticks within ~14 px of thresholds or adjacent ticks; stacks/offsets threshold labels closer than ~14 px (temperature 33.5 and 36.0); dedupes identical X-axis labels and drops trailing ticks within a label width.
- [x] Demo Mode threshold derivation: `generateDiurnalSample`, `FakeHistoryRepository` anomalies, and `FakeSystemRepository` heat/smoke spikes derive targets dynamically from `Thresholds.current`. Heat spike ramps through Caution into Danger; normal diurnal cycle stays strictly Safe across both `firmware` and `demo` presets. Verified with tests.
- [x] Neutral "Device offline" forecast card: displays neutral surfaceContainerHighest "Device offline" pill instead of amber "Locked out" while device is offline; tailored explanation text reserves safety lockout wording for true error lockouts only.
- [x] All 261 tests passing, `flutter analyze` clean (0 issues).

## Phase 6a: Timed manual ventilation (firmware alignment)
- [x] Pure state derivation (`deriveFanCardUiState`) covering 9 exhaustive states (`appOffline`, `deviceOffline`, `danger`, `safe`, `dangerLatched`, `waitingForDevice`, `running`, `pending`, `idle`) with 19 table-driven unit tests.
- [x] Action button replacing switch: "Ventilate for N min" (when `/config/manualDurationSec` is known) or "Ventilate" (with fallback helper "The fan runs for a fixed time set by the device.").
- [x] Running state with countdown ("Fan running, M:SS left") or fallback ("Fan running") when duration is unknown or opened mid-run.
- [x] Isolated 1 s ticker widget (`VentilationCountdownText`) for countdown rendering, avoiding whole-card rebuilds.
- [x] Write safety: replaced `setManualToggle(bool)` with `requestManualVentilation()` that only ever writes `true` to `/system/manualToggle`. Verified with unit test (`test/data/manual_ventilation_safety_test.dart`) that no code path writes `false`.
- [x] `FakeSystemRepository` defensive ignore of `false` writes and rejection outside Caution; publishes bare keywords (`SAFE`, `CAUTION`, `DANGER`), planned `manualEndsAt` (epoch seconds UTC), and `/config/manualDurationSec` (default 300 s).
- [x] Danger latch logic (`evaluateDangerLatch`): Danger cancels manual run and latches fan ON through Caution until Safe. Latch helper text ("Fan stays on until the room is safe.") displayed only if held $\ge 6$ s in unlatched Caution or Danger observed since last Safe (prevents flashing on normal spin-down).
- [x] Timeout and immediate rejection handling: if stream doesn't reflect `manualToggle == true` within 5 s, or reverts to `false` in < 5 s, shows snackbar: "The device didn't start the fan. The room may no longer be in the stuffy range." No auto-retry.
- [x] 30 s overrun handling: if `manualToggle` remains `true` > 30 s after scheduled end time, shows "Waiting for the device..." and stays disabled.
- [x] Countdown clamping (`clampManualEndsAt`): returns null if remaining < 0 or > 2× known duration, falling back to "Fan running" without countdown.
- [x] Accessibility: semantics announcements ("Ventilation started" / "Ventilation ended") emitted once via `SemanticsService.sendAnnouncement`.
- [x] Sentence case headers: "Fan on" / "Fan off".
- [x] All 293 tests passing, `flutter analyze` clean (0 issues).

## Phase 6b: Polish (P2)
- [ ] Preventive ventilation suggestion (FR-7), with the "app must be open" limitation shown
- [ ] In-app Medium/Danger notifications, debounced
- [ ] Settings screen
- [ ] README (setup, APK build, Firebase Hosting deploy)
- [ ] `flutter build apk --release` and `flutter build web` succeed

## Decisions log
- 2026-11-07: Phase 0 dependencies added via `flutter pub add` without hand-writing versions (`flutter_riverpod`, `go_router`, `firebase_core`, `firebase_auth`, `firebase_database`, `fl_chart`, `intl`).
- 2026-11-07: SDK constraint `sdk: ^3.13.7` preserved as created by Flutter SDK 3.47.9.
- 2026-11-07: Bundled Inter font configuration added in `pubspec.yaml` with clear TODO; no `google_fonts` dependency.
- 2026-11-07: Theme created in `lib/core/theme.dart` with explicit `ColorScheme` (no deprecated `background`), `scaffoldBackgroundColor`, `CardThemeData`, `TierColors` and `AppColors` ThemeExtensions.
- 2026-11-07: Responsive skeleton shell (`AppShellScaffold`) created using `StatefulShellRoute.indexedStack` (bottom `NavigationBar` under 900 dp, `NavigationRail` 900 dp and above).
- 2026-11-07: `database.rules.json` created in project root based on PRD §8 (not deployed).
- 2026-11-07: Verified generated `firebase_options.dart` contains regional `databaseURL` (`asia-southeast1`) on Web and Android.
- 2026-11-07: Updated app title to "AeroSense" in `lib/app.dart`, `web/index.html`, and `web/manifest.json`.
- 2026-11-07: Diagnosed Chrome console errors on route changes: identified as an internal Flutter web framework debug assertion in `RawKeyboard` (`raw_keyboard.dart:863:7`) caused by Wayland/KDE `MetaLeft` window-switching key events with `metaState: 0`, not application code.
- 2026-11-08: Phase 1 auth & data layer implemented. Added `AuthRepository` interface + `FirebaseAuthRepository` + `FakeAuthRepository` for clean separation and testing.
- 2026-11-08: `Tier.fromStatusMessage` returns nullable `Tier?`. Prefix matching handles both PRD reference strings and real firmware strings (e.g. "MEDIUM: Environment is stuffy..."). `Tier.resolve` prioritises status message from firmware as authoritative, falling back to sensor thresholds, and logs mismatches.
- 2026-11-08: `SystemState.fromJson` parses defensively with `parseSensorDouble` (tolerant of int, double, null, NaN, Infinity) and handles string `fanStatus` ("ON"/"OFF") with bool fallback.
- 2026-11-08: `routerProvider` created once in `Provider<GoRouter>` with `GoRouterRefreshStream` hooked to `authStateChanges()`; splash screen rendered until initial auth state is resolved to prevent login flicker.
- 2026-11-08: Resequenced Phase 3 (Demo Mode) before Phase 4 (History) because the physical device does not yet write `/history`.
- 2026-11-08: Debug screen added for `kDebugMode` showing raw `/system` JSON and connection chip, accessible from dashboard placeholder.
- 2026-11-08: Widget test updated to inject fake repositories into `ProviderScope.overrides`, isolating tests from live Firebase. Timestamp parser unit tests adjusted to use unambiguous pre-2020 UTC epoch seconds.
- 2026-11-08: Phase 2 live dashboard built. Visuals match DESIGN.md §4–5 (0 elevation, 1 px outline borders, tabular figures on metric values, surfaceContainerHighest loading skeletons).
- 2026-11-08: `MetricTier` shared helper added alongside `Tier.fromValues` with 27 boundary tests covering all threshold edges.
- 2026-11-08: `TierColors.forTier(tier)` added to `TierColors` extension returning a `TierColorPair` (solid + container).
- 2026-11-08: Fan icons: Material Icons does not have `mode_fan` from Material Symbols; used `Icons.toys_outlined` (4-blade pinwheel) for Fan On and `Icons.mode_fan_off_outlined` for Fan Off.
- 2026-11-08: Fan card switch locked in Danger tier, reflecting `fanOn` without triggering RTDB writes. Tested with `_WriteSnoopingSystemRepository`.
- 2026-11-08: Optimistic manual toggle implemented via Riverpod 3 `Notifier<ManualToggleState>`. Ignores incoming stream while pending; timeout (5 s) falls back to stream and logs `debugPrint` if stream reverted. Reverts immediately if write throws.
- 2026-11-08: In-router `/splash` preserved with `from` URI parameter (`/splash?from=...`) to redirect back to original requested route upon auth resolution.
- 2026-11-08: `DashboardScreen` error state uses `skipLoadingOnReload: true` on `systemState.when(...)` so stream failures trigger the error card with Retry rather than staying stuck in retrying loading skeletons.
- 2026-11-10: Phase 3 (Demo Mode) implemented. `demoModeProvider` added as `Notifier<bool>` initialized from `kDemoDefault` (`--dart-define=DEMO=true`). `authRepositoryProvider`, `systemRepositoryProvider`, and `historyRepositoryProvider` dynamically switch between fake and live implementations without app reload.
- 2026-11-10: `DemoRibbon` rendered in `MaterialApp.router` `builder` across all routes. Child wrapped in `MediaQuery.removePadding(removeTop: true)` to avoid double-padding on notched screens.
- 2026-11-10: Added "Try Demo Mode" `OutlinedButton` to `LoginScreen` allowing unauthenticated and release users to explore Demo Mode without adding third-party persistence dependencies.
- 2026-11-10: `FakeSystemRepository` mirrors exact firmware contract: no `lastSeen`, raw map omits `manualToggle` until first write, fan forced ON in Danger tier, real status strings from PRD Table III and `DATA_SAMPLE.json`. Timers start on stream listen, stop when all cancel, and dispose when demo mode turns off.
- 2026-11-10: `FakeHistoryRepository` generates deterministic 2016 records (7 days × 288 points/day, 5-minute spacing) with anchor rounded down to 5-minute boundary, dominant 24 h air quality diurnal wave, and relative anomaly injection flag.
- 2026-11-10: Phase 4 (History visualization) implemented. Range sizes matched to 5-min logging interval (1 h: 12, 6 h: 72, 24 h: 288, 7 d: 2016). Proportional LTTB downsampling runs strictly within contiguous segments and joins with `FlSpot.nullSpot` to prevent downsampling distortion across missing-data gaps (> 15 min). Threshold bands drawn at 12% opacity with accompanying dot+label legend and Y-axis labeled lines to ensure accessibility without color-only indicators. `historyNotifierProvider` uses `ref.keepAlive()` and `retry: (_, _) => null` with explicit `retry()` reload to cleanly display error states and retry without automatic retry delay loops. Semantics descriptions provided for each metric chart.
- 2026-11-10: Phase 5 (Diurnal Forecasting & Residual Gate) implemented.
  - Linear least-squares solver (`lib/features/forecast/sinusoidal_fit.dart`) written in pure Dart using 3x3 normal equations with partial pivoting and relative singularity thresholds. Evaluates seconds-of-day directly from `DateTime` fields without machine timezone dependency.
  - Robust diurnal fitter (`lib/features/forecast/robust_diurnal_fitter.dart`) implements 2-pass OLS with `1.4826 * MAD` outlier filtering on residuals (proven to cleanly reject day-long 24 h anomaly clusters without distorting wave parameters or inflating residual standard deviation).
  - Production data gates require >= 24 h span AND >= 20 hourly bins across the day to ensure coverage before fitting; demo mode permits short live testing (36 points). Refuses fitting on synthetic timestamps ("Waiting for real timestamps").
  - Enforced sensor accuracy noise floors: DHT22 0.5 °C floor and 30 ADC air quality floor. If amplitude is small relative to residual spread ($A/\sigma < 0.4$), the room is flagged as having "No clear daily pattern" and peak times are omitted. NOTE: Constants are not tuned on fake data and must be recalibrated when real 24 h+ physical logs arrive.
  - Per-metric gates (`lib/features/forecast/residual_gate.dart`) track Temperature and Air Quality independently with 3-sample hysteresis. Fresh fits start in `lockedOut` until 3 consecutive in-tolerance samples occur. Live samples with null or NaN values are skipped without disrupting gate status. Worst state wins in the overall combined status card.
  - Extracted `generateDiurnalSample` into `lib/data/repositories/fake_diurnal_generator.dart` shared by both `FakeHistoryRepository` and `FakeSystemRepository`. Live demo telemetry tracks diurnal baseline at current clock time, preventing persistent gate lockout in Demo Mode while preserving scripted smoke/heat scenario overrides.
  - Riverpod architecture: `diurnalFitProvider` depends on history records only, not `selectedRangeProvider`, preventing refits on range changes. Sampled forecast dotted curves generated at 120 points across visible chart windows and hooked into Phase 4 charts.
  - UI: `ForecastStatusCard` placed on `ForecastScreen` and on `HistoryScreen` displaying overall status pill, exact explanation copy ("Predictive layer locked out. Deterministic safety logic in control."), per-metric pills with hysteresis count, and predicted peak times. Full parameter diagnostic tables rendered on `ForecastScreen`.

- 2026-11-10: Phase 5 review fixes implemented:
  - Diurnal model refit tolerance check: `MetricGateTracker.updateModel` preserves gate status and hysteresis counter across periodic refits if $|newModel(now) - oldModel(now)| \le 0.5 \times threshold$. Materially different models restart locked out with 0 counter. Verified with unit tests in `residual_gate_test.dart`.
  - Replaced amplitude/sigma heuristic with variance explained ($R^2 \ge 0.3$, `AppConfig.minR2Pattern`). Added distinct per-metric status `MetricGateStatus.noClearPattern` (no dotted curve, no peak time, and not shown as Active). Verified with unit tests in `robust_diurnal_fitter_test.dart` and `residual_gate_test.dart`.
  - Charts and cards decoupled from 2-second telemetry: `ForecastGateNotifier` only emits updates when a status or hysteresis counter changes. Chart series sampling and status cards use `.select(...)` on each metric's own status/model, eliminating redundant UI repaints.
  - Verified ISO 8601 'Z' suffix parsing returns local time (`toLocal()`), with unit test in `test/parse_timestamp_test.dart`.
  - Set `AppConfig.minForecastPoints = 576` (2 full days) with architectural comment documenting that a single 24 h cycle cannot rule out transient anomalies or confirm periodic recurrence, while keeping the 24 h span and 20 hourly bins coverage checks.
  - All 210 tests passing, `flutter analyze` clean (0 issues).

- 2026-11-10: Phase 5b (Firmware Alignment) implemented:
  - Encapsulated thresholds into immutable `ThresholdPreset` (`firmware` and `demo` presets) with defensive JSON/Map parser, exposed as static getters via `Thresholds.current` (single source of truth). Confirmed firmware thresholds: Temperature Caution >= 33.5, Danger >= 36.0; Air Quality Caution >= 1400, Danger >= 2000, recovery clear 1250 (firmware hysteresis). Humidity 60/75 marked `// TODO(confirm)`.
  - Inclusive boundary checks (`>=`) aligned across `Tier.fromValues`, `MetricTier`, and boundary tests.
  - Case-insensitive firmware `statusMessage` parsing supports bare and prefixed keywords (`NORMAL`/`SAFE` -> Safe, `CAUTION`/`MEDIUM` -> Medium, `DANGER` -> Danger, `"System Safe"`), displaying app-friendly copy for bare keywords in `TierBanner`.
  - Manual fan toggle restricted to Medium tier only; disabled in Safe with explanatory text; locked on in Danger; disabled on device offline.
  - `FakeSystemRepository` auto-resets `manualToggle` back to `false` after 90 seconds using injected clock; optimistic toggle reconciles cleanly to stream value.
  - History cadence updated to 10 minutes (`AppConfig.expectedLogInterval = Duration(minutes: 10)`): `HistoryRange` counts 1 h = 6, 6 h = 36, 24 h = 144, 7 d = 1008; records capped at 1008; gap threshold derived dynamically at 2.5x median interval (~25 min); empty state copy updated to "The device logs every 10 minutes."
  - Removed point-count gate from diurnal forecasting (`AppConfig.minForecastPoints` removed); gating strictly requires time span >= 48 h and >= 20 hourly bins (point counts used for progress display calculation only); Demo Mode uses the exact same production rules.
  - Device offline detection (`deviceStatusProvider`) checks newest `/history` timestamp staler than 2 missed cycles (20 minutes) on a 30-second periodic timer with injected clock; unknown if history empty/error; renders offline warning card with "Last data at HH:mm", dims metrics via `Opacity(0.45)`, disables manual toggle, and locks out forecast gate. Demo Mode always reports online.
  - Added `/config` node to `database.rules.json` (read: `auth != null`, write: device UID).
  - Pre-ventilation / predictive fan start postponed pending firmware design.
  - Total test suite expanded to 229 tests, static analysis clean (0 issues).
- 2026-11-12: Real-device testing fixes implemented:
  - Added pure Dart sensor validation (`lib/core/sensor_validation.dart`): rejects out-of-range sensor values (-40..80 °C, 0..100 % RH, 0..4095 ADC) and detects the DHT22 disconnection signature (temperature == 0.0 AND humidity == 0.0 simultaneously). Live `/system` renders "--" on invalid fields, forecast gate skips them, and history pipeline drops them so chart Y-bounds calculate strictly from valid physical data without breaking threshold visibility.
  - Added "Simulate Sensor Unplugged" scenario to `FakeSystemRepository` and `SettingsScreen` demo actions, simulating temporary sensor disconnection and seamless recovery to diurnal baseline.
  - Built pure Dart chart label collision detection and layout utilities (`lib/features/history/chart_label_utils.dart`): drops Y-axis ticks within ~14 px of thresholds or adjacent ticks; stacks threshold labels vertically (danger above line, safe below line) when separated by < 14 px; dedupes identical formatted X-axis labels and drops trailing ticks within a label width of the preceding tick. Tested with pure Dart unit tests.
  - Derived all Demo Mode baselines and scenarios dynamically from `Thresholds.current`: normal diurnal baseline stays strictly Safe under any active preset; heat spike ramps through Caution into Danger and recovers; history anomalies cross Caution and Danger on temperature. Verified with `test/data/demo_thresholds_test.dart`.
  - Replaced amber "Locked out" pill in `ForecastStatusCard` with neutral "Device offline" pill when device is offline, updating status explanation copy to reserve safety lockout wording for true operational lockouts.
  - Test suite expanded to 261 tests, static analysis clean (0 issues).
- 2026-11-12: Full rules-compliance audit (AGENTS.md, DESIGN.md, TODO.md) completed:
  - Item 1 (Colors): Replaced raw `Color(0xFF0F1B2A)` and `Colors.white` in `DemoRibbon` with `AppColors.demoRibbonBackground` and `AppColors.demoRibbonText` tokens in `lib/core/theme.dart`. Replaced `Colors.white` in `LoginScreen` with `theme.colorScheme.onPrimary`. Zero hardcoded colors outside `core/theme.dart`.
  - Item 2 (Thresholds): Replaced hardcoded `(> 2000)` in `SettingsScreen` with `Thresholds.airQualityDangerMin.toInt()`. Clarified 1-second float tick tolerance in `MetricChartCard` with an explicit named constant (`xTickToleranceMs = 1000`). Zero hardcoded threshold values outside `core/thresholds.dart`.
  - Item 3 (Firebase encapsulation): Verified zero `FirebaseAuth` or `FirebaseDatabase` imports/usages outside `lib/data/repositories/` and `firebase_options.dart`. UI communicates purely through repository interfaces and Riverpod providers.
  - Item 4 (Write boundaries): Verified zero writes other than `_db.ref('system/manualToggle').set(true)`. No `.update`, `.push`, or writing to `/history` or whole `/system` node exists in production paths.
  - Item 5 (State management): Verified `setState` is strictly confined to purely local ephemeral UI state: `_LoginScreenState` (form submission spinner & error message) and `_VentilationCountdownTextState` (isolated 1 s text countdown tick). All shared state lives in Riverpod providers.
  - Item 6 (Strings & casing): Verified zero ALL CAPS UI text other than the required `DEMO MODE` ribbon. Centralized user-facing strings into `lib/core/strings.dart` (`AppStrings`) following DESIGN.md §8 calm plain tone; refactored fan card state, banner titles, and notifier feedback.
  - Item 7 (Timestamp parsing): Updated `parseTimestamp` in `lib/core/time_utils.dart` to support `silent: true`, treating 0, '0', and year < 2020 as "no value" silently for `manualEndsAt` without `TODO(confirm)` debugPrint logs, keeping boot-year warnings for history timestamps only.
  - Item 8 (Animations & Timers): Confirmed `TierBanner` pulse animation respects `MediaQuery.maybeDisableAnimationsOf(context)` and disposes its `AnimationController`. Confirmed all `Timer` instances in `VentilationCountdownText`, `DeviceStatusNotifier`, and `ManualVentilationNotifier` are properly cancelled on widget/provider disposal.
  - Item 9 (Responsive layout & text scaling): Added comprehensive responsive test suite (`test/features/responsive_overflow_test.dart`) testing 360x640 (mobile), 768x1024 (tablet), and 1280x800 (desktop) with `textScaler: TextScaler.linear(1.3)` across Dashboard, History, Forecast, Settings, and Login screens (15 test configurations). Resolved RenderFlex overflow risks:
    - Wrapped `MetricTile` large number and unit in `FittedBox(fit: BoxFit.scaleDown)` to prevent tile overflow under high text zoom.
    - Wrapped `MetricChartCard` header and `ForecastStatusCard` headers in `Wrap(alignment: WrapAlignment.spaceBetween)` so legends and status pills wrap cleanly on narrow screens.
    - Wrapped `_buildMetricPill` and `_buildOverallPill` status labels in `Flexible` to eliminate row overflow under large text scaling.
    - Wrapped `ForecastScreen` model headers in `Wrap` with `Flexible(child: Text(title))` and formula rows in `Wrap`.
    - Wrapped `LoginScreen` in `SingleChildScrollView` to prevent keyboard / small screen vertical overflow.
  - Total test suite expanded to 309 unit and widget tests, static analysis clean (0 issues).

## Known issues
- Inter font files are pending human addition into `assets/fonts/`.
