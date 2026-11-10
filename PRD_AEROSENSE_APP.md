# PRD: AeroSense Companion App (Flutter: Android + Web)

> **For the AI coding agent.** Read this whole file before writing code. Build in the phases of section 11, in order. Where this PRD says **CONFIRM**, do not guess: leave a clearly marked `// TODO(confirm)` and make the code tolerant of either option. Never invent sensor data in production code paths; fake data is allowed only inside the Demo Mode feature (FR-11).

---

## 1. Product overview

**AeroSense** is an IoT adaptive ventilation system for homes (STEM competition project, Techtonic 3.0). The hardware is **already built**: an ESP32 reads a DHT22 (temperature, humidity) and an MQ-135 (air quality), classifies the room into three tiers (**Safe / Medium / Danger**), drives a relay-switched 5 V fan, and syncs to **Firebase Realtime Database (RTDB)**.

**This app is the User Application Layer.** It does not read sensors and does not make safety decisions. It:

1. Shows live telemetry from RTDB.
2. Lets the user send a manual fan toggle (only where the firmware honours it).
3. Visualizes archived history.
4. Runs the confidence-gated diurnal forecasting layer on the client.

### Core design principle (must be reflected in UX and code)

> Intelligence can add savings but never remove safety.

The ESP32 firmware is the single source of truth for tier and fan state. The app is an observer plus a polite requester. The app must never present itself as being able to override the **Danger** tier.

## 2. Goals and non-goals

**Goals**
- G1. Live dashboard that updates within ~1 s of an RTDB change.
- G2. Manual fan toggle that correctly reflects tier rules (enabled in Safe/Medium, locked in Danger).
- G3. 24 h history charts with Safe/Medium/Danger bands.
- G4. Diurnal sinusoidal forecast + residual-error gate, with clear "predictive layer active / locked out" state.
- G5. One codebase running on **Android** and **Flutter Web**, responsive.
- G6. Demoable without hardware (Demo Mode) as a fallback for the competition.

**Non-goals**
- No direct device communication (BLE, local HTTP). Firebase only.
- No tier/safety logic that can actuate the fan on its own authority. The only fan control path is writing `/system/manualToggle`.
- No iOS/desktop work (don't break them, don't test them).
- No multi-room, no AC-mains/HVAC features (these are "conceptual scale-up" in the proposal).

## 3. Users

| User | Need |
|---|---|
| Household member / student | See room state at a glance, decide whether to ventilate in Medium tier |
| Competition judge (demo) | See the live loop work: sensor → cloud → app → relay, and see the safety override |

Single room, single device. Authenticated users only.

## 4. Tech stack (decisions already made, don't substitute)

- **Flutter** (latest stable), Dart null-safety, targets: `android`, `web`.
- **Firebase**: `firebase_core`, `firebase_auth`, `firebase_database`. Configure via **FlutterFire CLI** (`flutterfire configure`, select Android + Web).
- **State management**: Riverpod (`flutter_riverpod`).
- **Routing**: `go_router`.
- **Charts**: `fl_chart`.
- **Other**: `intl` (time formatting). Keep dependencies minimal; justify any addition in a code comment or PR note.
- **Lint**: `flutter_lints`. `flutter analyze` must pass with zero errors.

> **Important (Firebase region):** the RTDB lives in **asia-southeast1**, so the `databaseURL` must be the regional one (`https://<project-id>-default-rtdb.asia-southeast1.firebasedatabase.app`). Verify the generated `firebase_options.dart` contains it; if not, pass it explicitly via `FirebaseDatabase.instanceFor(app: ..., databaseURL: ...)`.

## 5. Data contract (RTDB)

This section is derived from the firmware design. **CONFIRM every field type against the real data in the Firebase console before coding the models** (see section 12).

### 5.1 `/system` (live, overwritten by ESP32 every 2 s)

| Field | Expected type | Notes |
|---|---|---|
| `temperature` | number (°C) | DHT22; may be `NaN`/null/missing on a failed read |
| `humidity` | number (% RH) | same |
| `airQuality` | number (int 0–4095) | MQ-135 raw 12-bit ADC, relative index (not ppm) |
| `fanStatus` | **CONFIRM**: string `"ON"/"OFF"` or bool | parse tolerantly |
| `manualToggle` | bool | **written by the app**, read by ESP32 |
| `statusMessage` | string | see 5.3 |

### 5.2 `/history` (archive, appended by ESP32 every 5 min via `pushJSON`)

Each child (auto-generated push key) contains: `timestamp`, `temperature`, `humidity`, `airQuality`.

- **CONFIRM `timestamp` format**: epoch seconds, epoch milliseconds, `millis()` since boot, or an ISO string. Implement a single `parseTimestamp(dynamic) -> DateTime?` in one place that handles int seconds, int milliseconds (heuristic: > 1e12), and ISO strings. If it turns out to be `millis()` since boot, flag it to the user (it can't be plotted against time of day) and fall back to ordering by push key with synthetic 5-minute spacing.
- Push keys sort chronologically, so fetch with `orderByKey().limitToLast(N)`. 24 h = **288 records**; default fetch 288, maximum 2016 (7 days).

### 5.3 Tier determination

The ESP32 does not publish an explicit `tier` field. Use two sources:

1. **Primary:** parse `statusMessage` prefix. `"DANGER:"` → Danger, `"MEDIUM:"` → Medium, otherwise (`"System Safe"`, `"SAFE:"`) → Safe.
2. **Fallback / cross-check:** compute from values using the table below. If the two disagree, trust `statusMessage` for display and log a debug warning.

| Tier | Condition (worst indicator wins; Danger checked first) |
|---|---|
| **Danger** | temperature **> 32.0** OR humidity **> 75.0** OR airQuality **> 2000** |
| **Medium (Stuffy)** | temperature 28.0–32.0 OR humidity 60.0–75.0 OR airQuality 1000–2000 |
| **Safe** | temperature < 28.0 AND humidity < 60.0 AND airQuality < 1000 |

Put these thresholds in one constants file (`core/thresholds.dart`). They are design parameters and the air-quality ones will be recalibrated during testing, so never hard-code them in widgets.

Reference status strings from firmware (for display and prefix parsing):
- `"System Safe"` / `"SAFE: Fan manually overridden ON."`
- `"MEDIUM: The environment is stuffy. Manual toggle available."` / `"MEDIUM: Fan manually turned ON by user."`
- `"DANGER: High thresholds breached! Auto-fan activated."`

### 5.4 Write rules (critical)

- The app writes **only** `/system/manualToggle` (a bool), using `.set()` on that exact child path. **Never** write or `set()` the whole `/system` node: the ESP32 owns the rest.
- The app never writes `/history`.

## 6. Functional requirements

### FR-1. Authentication
- Email + password sign-in with Firebase Auth. Sign-out. Persistent session.
- No public sign-up in the UI by default (accounts created in Firebase console); put a `kAllowSignUp` flag in config, default `false`.
- Router guard: unauthenticated users only see the login screen.

### FR-2. Live dashboard (home screen)
- Subscribe to `/system` with `onValue` (a single stream provider, auto-disposed).
- Show: temperature, humidity, air quality (large readable tiles/gauges), fan status (ON/OFF with icon), the raw `statusMessage`, and a **tier banner** colored Green (Safe) / Amber (Medium) / Red (Danger).
- Air quality tile shows the raw ADC value and the label "relative index (uncalibrated)". Do not label it ppm.
- Null/NaN/missing values render as `--` and never crash the UI.
- Danger tier: banner turns red and pulses subtly; visible "Auto-fan activated" state.

### FR-3. Connection and freshness state
- App-to-Firebase connectivity: listen to `.info/connected`; show an "Offline" chip when false.
- **Device staleness caveat:** the ESP32 overwrites `/system` every 2 s, but RTDB does not fire `onValue` when the written value is unchanged, so "no event for N seconds" does **not** reliably mean the device is dead. Therefore:
  - If `/system/lastSeen` exists (**CONFIRM**, proposed new field: epoch seconds or ms written every cycle), mark the device **stale** when `now - lastSeen > 15 s`.
  - If it doesn't exist, don't show a stale warning. Show "Last value change: hh:mm:ss" instead, with neutral wording. Make the staleness feature a no-op in that case.

### FR-4. Manual fan toggle
- A switch bound to `/system/manualToggle` (read and write).
- Behavior by tier (confirmed ESP32 firmware alignment):
  - **Safe:** **disabled.** Helper text: "The fan stays off while the room is safe. Manual ventilation is available when the room gets stuffy." (Firmware keeps fan OFF in Safe tier).
  - **Medium:** **enabled.** This is the primary "energy decision" moment, so give it prominence: "Room is stuffy. The fan stays off unless you turn it on." When on: "Manual ventilation is on. The fan is running." Firmware automatically resets `manualToggle` back to false after a fixed time (1–2 min).
  - **Danger:** **disabled/locked.** Text: "Safety override active. The fan is forced on and manual control is bypassed."
- Optimistic UI is allowed but must reconcile to the value streamed back from RTDB. Show a brief "sending..." state; on write error show a snackbar and revert. State also follows stream when firmware auto-resets `manualToggle` to `false`.
- If the device is offline (> 20 min staleness) or app is offline, disable the toggle with an explanation.

### FR-5. History visualization
- Load `/history` (`limitToLast`) once, then keep updated by listening to `onChildAdded` for new records (cadence is 1 record every 10 min). No full re-download on each event.
- Range selector: **1 h (6 pts), 6 h (36 pts), 24 h (default, 144 pts), 7 d (1008 pts)**.
- Charts (using `fl_chart`): **three separate line charts** (temperature, humidity, air quality) sharing the same time axis, each with horizontal **Green/Amber/Red threshold bands** (from `thresholds.dart`). Rationale: the three metrics have very different scales (°C vs % vs 0–4095), which makes a single-axis combined chart unreadable. A combined normalized overlay may be added later as P2.
- X axis: time of day (local time). Tooltips on touch/hover show exact values and time.
- Empty state ("No history yet. The device logs every 10 minutes.") and loading state.
- Handle gaps (device offline) by breaking the line rather than interpolating across gaps larger than 2.5× the sample interval (~25 min).

### FR-6. Diurnal forecasting (client-side)

Implement in pure Dart under `features/forecast/`, unit-tested, no Flutter imports in the math code.

**Model (from proposal, Eq. 1):**

```
ŷ(t) = A·sin(2π·t/T + φ) + C,   T = 86400 s
```

**Fit via linear least squares** (don't use iterative optimizers). Rewrite as:

```
y ≈ a·sin(ωt) + b·cos(ωt) + C,   ω = 2π / 86400
A = sqrt(a² + b²),   φ = atan2(b, a)
```

Solve the 3×3 normal equations (Gaussian elimination with partial pivoting is fine) over the history window. Use `t` = seconds since local midnight (mod 86400) so the phase maps to a real hour of day. Fit **temperature** and **airQuality** (humidity optional, P2).

**Minimum data requirement:** Historical span ≥ 48 hours and ≥ 20 distinct hourly bins (0..23) represented. Point counts are used only for progress display calculation (`Progress = min(span/48h, bins/20, points/288)`). Below the minimum, show "Learning your room's pattern: X% of data needed" instead of a forecast. Demo Mode uses the same rules (fake history spans 7 days).

**Confidence gate (from proposal, Eq. 2):**

```
E = | y(t) − ŷ(t) |
```

- Compute residuals across the fit window; `σ_threshold = k · stddev(residuals)` with `k` default **3.0** (config constant).
- On every new live `/system` sample: compute `E` against the model's prediction for the current time.
- `E ≤ σ_threshold` → **PREDICTABLE** state: show the dotted predicted curve on the chart, enable proactive ventilation suggestions.
- `E > σ_threshold` → **CHAOTIC** state: immediately hide/disable the forecast, show an "Anomaly: predictive layer locked out. Deterministic safety logic in control." badge. Return to predictable only after E stays under threshold for **3 consecutive samples** (simple hysteresis to avoid flicker).
- Always display the gate state in a visible "Forecast status" card: *Learning / Active / Locked out*.

**Preventive ventilation (P2, see FR-7).**

### FR-7. Preventive ventilation scheduling (P2, build last)
- From the fitted model, compute the predicted daily peak time (`t_peak` where ŷ is max) and show it: "Predicted peak: ~14:30".
- Offer a **suggestion** card: "Run a 3 min ventilation cycle at 14:20?" with an Accept button.
- **Limitation to document in the UI/README:** there is no scheduling field in the firmware schema, so a scheduled cycle can only be executed by the app writing `manualToggle = true` for 3 minutes and then `false`, which works **only while the app/tab is open**. If the user wants this to run unattended, the firmware needs a new field (e.g. `/system/preventiveCycle`); list this as a future change, don't build it.
- Only execute when the forecast gate is **Active**; cancel if the gate locks out or tier becomes Danger.
- If the user manually toggles during a cycle, the user's choice wins.

### FR-8. Notifications (P2)
- In-app banner when tier enters Medium ("Room is getting stuffy") and Danger. Debounce: no more than one per tier change per 5 min (proposal lists notification fatigue as a risk).
- Optional: Android local notification when app is backgrounded and a Danger event is seen. Push (FCM) is out of scope.

### FR-9. Settings screen
- Thresholds shown read-only (from `thresholds.dart`) with the note that firmware is the authority.
- Forecast parameters: `k`, min points, demo threshold toggle.
- Theme (system/light/dark). Sign out. App version.

### FR-10. Responsive layout
- Android phone (portrait first): single column, bottom navigation (Dashboard / History / Forecast / Settings).
- Web (desktop widths ≥ 900 px): navigation rail, dashboard in a 2-column grid, charts side by side where space allows.
- Web must work in latest Chrome. Test at 360 px, 768 px and 1280 px widths.

### FR-11. Demo Mode (important for the competition)
- A switch in Settings (and an `--dart-define=DEMO=true` build flag) that replaces the Firebase repositories with a **fake repository** emitting plausible data: a 24 h sinusoidal temperature wave with noise, humidity, air quality, and a scripted "Danger spike" button that simulates a kitchen-smoke event, so the Danger lock and forecast lock-out can be shown on stage if Wi-Fi fails.
- A persistent "DEMO MODE" ribbon must be visible on every screen so it's never mistaken for live data.
- The same `SystemRepository` / `HistoryRepository` interfaces are used, which also makes unit tests easy.

## 7. Architecture

Feature-first, repository pattern:

```
lib/
  main.dart
  app.dart                      // MaterialApp.router, theme
  firebase_options.dart         // generated
  core/
    thresholds.dart
    config.dart                 // flags: kAllowSignUp, forecast defaults
    time_utils.dart             // parseTimestamp()
    theme.dart                  // tier colors: green / amber / red
  data/
    models/
      system_state.dart         // temperature, humidity, airQuality, fanOn, manualToggle, statusMessage, tier
      history_record.dart
      tier.dart                 // enum Tier { safe, medium, danger } + fromStatusMessage + fromValues
    repositories/
      system_repository.dart            // abstract
      history_repository.dart           // abstract
      firebase_system_repository.dart
      firebase_history_repository.dart
      fake_system_repository.dart       // demo
      fake_history_repository.dart      // demo
  features/
    auth/        (login_screen, auth_providers)
    dashboard/   (dashboard_screen, widgets: metric_tile, tier_banner, fan_card, toggle_card)
    history/     (history_screen, widgets: metric_chart w/ bands, range_selector)
    forecast/    (sinusoidal_model.dart [pure Dart], residual_gate.dart [pure Dart], forecast_screen, providers)
    settings/
  shared/ (widgets: connection_chip, demo_ribbon, empty_state)
test/
  tier_test.dart
  parse_timestamp_test.dart
  sinusoidal_model_test.dart
  residual_gate_test.dart
```

Rules:
- UI never touches Firebase directly. Only repositories do.
- Models parse defensively: all fields nullable-tolerant, `num → double` conversion, unknown fields ignored.
- Streams exposed as Riverpod `StreamProvider`s; history as an `AsyncNotifier`.

## 8. Security

- RTDB must **not** be open (`".read": true`). Provide `database.rules.json` in the repo:

```json
{
  "rules": {
    "system": {
      ".read": "auth != null",
      "manualToggle": { ".write": "auth != null", ".validate": "newData.isBoolean()" },
      "temperature":   { ".write": "auth.uid === 'DEVICE_UID_HERE'" },
      "humidity":      { ".write": "auth.uid === 'DEVICE_UID_HERE'" },
      "airQuality":    { ".write": "auth.uid === 'DEVICE_UID_HERE'" },
      "fanStatus":     { ".write": "auth.uid === 'DEVICE_UID_HERE'" },
      "statusMessage": { ".write": "auth.uid === 'DEVICE_UID_HERE'" }
    },
    "history": {
      ".read": "auth != null",
      ".write": "auth.uid === 'DEVICE_UID_HERE'"
    }
  }
}
```

  The user replaces `DEVICE_UID_HERE` with the ESP32's dedicated device-account UID. If the firmware writes extra fields (e.g. `lastSeen`), add them to the rules. Note: if the firmware currently writes with `setJSON` on the whole `/system`, rules like these will reject it, so **CONFIRM** the firmware's write method.
- No API keys or secrets hard-coded beyond the standard generated `firebase_options.dart`.
- Don't log full telemetry or tokens in release builds.

## 9. Non-functional requirements

| Area | Requirement |
|---|---|
| Performance | Dashboard rebuilds only the tiles whose values changed (use `select`). Chart rendering ≤ 2000 points smooth on a mid-range Android phone; downsample for the 7 d view. |
| Resilience | App survives null/NaN/missing fields, offline/online transitions, empty `/history`. |
| Cost | Stay within Firebase free tier: no polling loops, no listening on `/history` root without `limitToLast`. |
| Accessibility | Tier is never conveyed by color alone (also icon + text). Minimum 48 dp touch targets. |
| Language | English UI. All user-facing strings in one place (`l10n`-ready) so Indonesian can be added later. |
| Quality | `flutter analyze` clean; unit tests pass for tier logic, timestamp parsing, sinusoidal fit, and residual gate. |

## 10. Test plan (minimum)

1. **Tier logic:** table-driven tests, including boundary values (28.0, 32.0, 60.0, 75.0, 1000, 2000) and the "worst indicator wins" rule.
2. **Sinusoidal fit:** generate a synthetic wave (`A=3, C=28, φ=1.0`) + small noise; assert recovered A, C, φ within tolerance and that the peak time is correct.
3. **Residual gate:** feed an injected spike; assert LOCKED_OUT immediately and return to ACTIVE only after 3 consecutive in-tolerance samples.
4. **Timestamp parser:** seconds, milliseconds, ISO string, garbage → null.
5. **Toggle widget test:** disabled in Danger, enabled in Safe/Medium (using the fake repository).
6. **Manual on-device checks:** with the real hardware: toggle in Medium (relay clicks), confirm the toggle is locked when heating the DHT22 / exposing the MQ-135 to alcohol vapor reaches Danger.

## 11. Delivery phases (agent: do these in order, stop and report after each)

| Phase | Deliverable | Acceptance |
|---|---|---|
| **0. Setup** | Dependencies added, FlutterFire configured (Android + Web), folder structure, theme, router skeleton, lint clean | `flutter run -d chrome` and Android both launch to a login placeholder |
| **1. Auth + data layer** | Login, route guard, models, `Tier` logic with tests, Firebase repositories, fake repositories | Can sign in; a debug screen prints a live `/system` object from the real RTDB |
| **2. Live dashboard** | FR-2, FR-3, FR-4, FR-10 (dashboard part) | Values update live; toggle works in Medium; locked in Danger |
| **3. History** | FR-5 | 24 h charts with bands render from real `/history` |
| **4. Demo Mode** | FR-11 | App fully usable with no Firebase connection |
| **5. Forecasting** | FR-6 + tests | Fit + gate work on real/demo data; status card shows Learning/Active/Locked |
| **6. Polish (P2)** | FR-7, FR-8, FR-9, responsive pass, README (setup, build APK, deploy web via Firebase Hosting) | Release APK builds; `flutter build web` deploys |

Priority: **P0** = phases 0–3. **P1** = phases 4–5. **P2** = phase 6.

## 12. Open questions: CONFIRM with the hardware/firmware owner before coding models

1. Exact JSON in `/system` and one `/history` record (paste a real sample from the Firebase console).
2. Type of `fanStatus` (bool vs string) and exact `timestamp` format/units in `/history`.
3. Does the firmware update `/system` with `setJSON` (replaces the whole node, would **erase `manualToggle` every 2 s**) or `updateNode`/individual `set` calls? It must not clobber `manualToggle`. If it uses `setJSON`, the firmware must change.
4. Can the firmware add a `lastSeen` field to `/system` each cycle (enables reliable offline detection)?
5. Firebase project ID, RTDB URL, and the ESP32 device account UID (for rules).
6. Does the firmware reset `manualToggle` to `false` on boot, or leave it as last set?

## 13. Out of scope / future

Matter/MQTT, PWM fan speed, NDIR CO₂ calibration view, occupancy sensing, multi-room, power metering (kWh saved), FCM push notifications, iOS.

## 14. Agent working rules

- Ask before deviating from section 4 (stack) or section 5.4 (write rules).
- Keep the forecast math pure Dart and unit tested.
- Don't add features outside the current phase.
- After each phase: run `flutter analyze` and `flutter test`, then summarize what was done, what's untested, and what needs a human check (hardware).
- Prefer small, readable files. Comment the *why* for anything tied to the firmware contract.