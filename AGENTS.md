# AGENTS.md: AeroSense Companion App

Flutter app (Android + Web) for the AeroSense IoT ventilation system. Reads live and historical data from Firebase Realtime Database, shows it, and sends one command: the manual fan toggle.

**Read `PRD_AeroSense_App.md` before starting any task.** It is the source of truth for scope, data contract, and build phases. Work one phase at a time and stop to report after each.

## Non-negotiables

1. **The firmware owns safety.** The ESP32 decides the tier and the fan state. The app never decides to run or stop the fan on its own authority and never implies it can override the Danger tier. The toggle is locked in Danger.
2. **Write rules.** The only path the app writes is `/system/manualToggle` (bool), using `.set()` on that exact child. Never `set()` or `update()` the whole `/system` node. Never write `/history`.
3. **No invented data** in production code paths. Fake data exists only in Demo Mode (repository implementations under `data/repositories/fake_*`), and Demo Mode must show a visible ribbon.
4. **Don't guess the data contract.** Field types and the `/history` timestamp format are marked CONFIRM in the PRD. Parse defensively, leave `// TODO(confirm)`, and ask me.
5. **Thresholds live in one file** (`core/thresholds.dart`). Never hard-code 28 / 32 / 60 / 75 / 1000 / 2000 in widgets.
6. Air quality is a raw, uncalibrated ADC index (0-4095). Never label it ppm.

## Stack (don't substitute without asking)

Flutter stable, `flutter_riverpod`, `go_router`, `firebase_core` / `firebase_auth` / `firebase_database`, `fl_chart`, `intl`. Keep new dependencies to a minimum and say why in your report.

## Code rules

- Feature-first folders under `lib/features/`; shared code in `lib/core`, `lib/data`, `lib/shared`. UI never touches Firebase directly, only through repository interfaces.
- State with Riverpod providers. `setState` only for purely local, ephemeral UI state.
- Models parse defensively: nullable-tolerant, `num` to `double`, unknown fields ignored, NaN/null/missing render as `--`.
- Forecast math (`features/forecast/`) is pure Dart with no Flutter imports, and has unit tests.
- Use theme tokens and `ColorScheme`, not raw hex colors in widgets. Tier is never shown by color alone (add icon + text).
- Use `const` constructors where possible, split large widgets, prefer small files. No dead code, no unused imports, no commented-out blocks.
- User-facing strings go in one place, ready for localization.
- Layouts must be responsive: test at 360, 768, and 1280 px widths.
- Comment the *why* for anything tied to the firmware contract. Don't comment the obvious.

## Workflow

- After every change: `dart format .`, `flutter analyze` (must be clean), `flutter test`.
- Use the Dart and Flutter MCP server to check analyzer errors and runtime errors instead of guessing. Check installed skills in `.agents/skills/` before starting a task they cover.
- Verify package APIs against current docs (pub.dev / package docs) before using them. Don't rely on memory for `fl_chart`, Riverpod, or FlutterFire APIs.
- Don't add features outside the current phase.
- End each phase with a short report: what was done, what's untested, what needs a human check on real hardware.

## Commands

```bash
flutter pub get
flutter run -d chrome
flutter run                      # Android device/emulator
flutter analyze && flutter test
flutter build apk --release
flutter build web
dart run build_runner build      # only if codegen is introduced
```

_Update this file with real structure notes after Phase 2._