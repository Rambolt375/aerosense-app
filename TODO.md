# TODO.md: AeroSense App progress

> Living checklist. The agent updates this at the end of every work session: tick items, add notes, and log decisions. Spec lives in `PRD_AeroSense_App.md`; don't duplicate it here.
> **Current phase:** 5 (✅ COMPLETE — awaiting user review before Phase 6)

## Blockers / open questions (owner: human)

- [x] Paste real `/system` JSON into `DATA_SAMPLE.json` (confirmed: `airQuality`, `fanStatus: "OFF"`, `humidity`, `statusMessage`, `temperature`; no `manualToggle`, no `lastSeen`)
- [ ] Confirm `/history` timestamp format/units once firmware creates the node (currently parsed defensively for epoch s/ms and ISO 8601)
- [ ] Confirm firmware updates `/system` without erasing `manualToggle` (no whole-node `setJSON`)
- [ ] Ask firmware owner to add `lastSeen` to `/system` (optional, enables stale-device detection; staleness currently a no-op)
- [x] Firebase project ID (`aerosense-502de`), RTDB URL (`asia-southeast1`)
- [ ] Confirm whether firmware resets `manualToggle` to `false` on boot
- [ ] Add Inter font files to `assets/fonts/` (Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf) and uncomment `fonts` block in `pubspec.yaml`
- [x] Run `flutterfire configure` to register the Android app in the Firebase project and generate final `firebase_options.dart`
- [ ] Hardware check: toggle in Medium clicks the relay; locked in Danger (needs real ESP32)
- [ ] Hardware check: verify real firmware status message strings against PRD Table III assumptions

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

## Phase 6: Polish (P2)
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

## Known issues
- Inter font files are pending human addition into `assets/fonts/`.
