# TODO.md: AeroSense App progress

> Living checklist. The agent updates this at the end of every work session: tick items, add notes, and log decisions. Spec lives in `PRD_AeroSense_App.md`; don't duplicate it here.
> **Current phase:** 2 (✅ COMPLETE — awaiting user review before Phase 3)

## Blockers / open questions (owner: human)

- [x] Paste real `/system` JSON into `DATA_SAMPLE.json` (confirmed: `airQuality`, `fanStatus: "OFF"`, `humidity`, `statusMessage`, `temperature`; no `manualToggle`, no `lastSeen`)
- [ ] Confirm `/history` timestamp format/units once firmware creates the node (currently parsed defensively for epoch s/ms and ISO 8601)
- [ ] Confirm firmware updates `/system` without erasing `manualToggle` (no whole-node `setJSON`)
- [ ] Ask firmware owner to add `lastSeen` to `/system` (optional, enables stale-device detection; staleness currently a no-op)
- [x] Firebase project ID (`aerosense-502de`), RTDB URL (`asia-southeast1`)
- [ ] Confirm whether firmware resets `manualToggle` to `false` on boot
- [ ] Add Inter font files to `assets/fonts/` (Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf) and uncomment `fonts` block in `pubspec.yaml`
- [x] Run `flutterfire configure` to register the Android app in the Firebase project and generate final `firebase_options.dart`

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
- [ ] Fake repositories wired behind a switch and `--dart-define=DEMO=true`
- [ ] "DEMO MODE" ribbon on every screen
- [ ] Scripted Danger spike (kitchen-smoke) button and sinusoidal telemetry generator

## Phase 4: History (awaits firmware `/history` generation)
- [ ] Fetch `limitToLast`, live append via `onChildAdded`
- [ ] Three charts with Safe/Medium/Danger bands, range selector (1h / 6h / 24h / 7d)
- [ ] Empty/loading states, gap handling (> ~15 min)

## Phase 5: Forecasting
- [ ] Least-squares sinusoidal fit (pure Dart) + unit tests
- [ ] Residual gate (`k * stddev`, 3-sample hysteresis) + unit tests
- [ ] Forecast status card: Learning / Active / Locked out
- [ ] Dotted prediction curve on charts when Active

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


## Known issues
- Inter font files are pending human addition into `assets/fonts/`.
