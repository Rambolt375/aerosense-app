# TODO.md: AeroSense App progress

> Living checklist. The agent updates this at the end of every work session: tick items, add notes, and log decisions. Spec lives in `PRD_AeroSense_App.md`; don't duplicate it here.
> **Current phase:** 0 (complete, awaiting review for Phase 1)

## Blockers / open questions (owner: human)

- [ ] Paste real `/system` JSON and one `/history` record from the Firebase console (into `DATA_SAMPLE.json`)
- [ ] Confirm `fanStatus` type (bool vs string) and `/history` `timestamp` format/units
- [ ] Confirm firmware updates `/system` without erasing `manualToggle` (no whole-node `setJSON`)
- [ ] Ask firmware owner to add `lastSeen` to `/system` (optional, enables stale-device detection)
- [ ] Firebase project ID, RTDB URL (asia-southeast1), ESP32 device account UID
- [ ] Confirm whether firmware resets `manualToggle` to `false` on boot
- [ ] Add Inter font files to `assets/fonts/` (Inter-Regular.ttf, Inter-Medium.ttf, Inter-SemiBold.ttf) and uncomment `fonts` block in `pubspec.yaml`
- [x] Run `flutterfire configure` to register the Android app in the Firebase project and generate final `firebase_options.dart`

## Phase 0: Setup
- [x] Add dependencies (riverpod, go_router, firebase_*, fl_chart, intl)
- [x] `firebase_options.dart` generated via `flutterfire configure`; verified regional asia-southeast1 `databaseURL` on both Web and Android
- [x] Folder structure, theme (`TierColors` + `AppColors` ThemeExtensions, explicit ColorScheme, light & dark), router skeleton with responsive layout
- [x] `flutter analyze` clean (0 issues); `flutter test` passing (5 tests)

## Phase 1: Auth + data layer
- [ ] Login screen, session persistence, route guard
- [ ] Models: `SystemState`, `HistoryRecord`, `Tier` (+ `parseTimestamp`)
- [ ] Tier tests incl. boundary values (28, 32, 60, 75, 1000, 2000)
- [ ] Firebase repositories (system, history) + fake repositories
- [ ] Debug screen prints a live `/system` object

## Phase 2: Live dashboard
- [ ] Metric tiles, tier banner, fan status card, `statusMessage`
- [ ] Connection chip (`.info/connected`); staleness only if `lastSeen` exists
- [ ] Manual toggle (enabled Safe/Medium, locked Danger, optimistic + reconcile)
- [ ] Responsive dashboard (360 / 768 / 1280 px)
- [ ] Hardware check: toggle in Medium clicks the relay; locked in Danger

## Phase 3: History
- [ ] Fetch `limitToLast`, live append via `onChildAdded`
- [ ] Three charts with Safe/Medium/Danger bands, range selector (1h / 6h / 24h / 7d)
- [ ] Empty/loading states, gap handling (> ~15 min)

## Phase 4: Demo Mode
- [ ] Fake repositories wired behind a switch and `--dart-define=DEMO=true`
- [ ] "DEMO MODE" ribbon on every screen
- [ ] Scripted Danger spike (kitchen-smoke) button

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

## Known issues
- Inter font files are pending human addition into `assets/fonts/`.
- `flutterfire configure` pending execution by user to link Android application and produce full multi-platform options.
- `DATA_SAMPLE.json` pending human paste before Phase 1 models.