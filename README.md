# AeroSense Companion App

Flutter companion application (Android and Web) for the **AeroSense** adaptive ventilation system (Techtonic 3.0 STEM competition).

The app serves as the **User Application Layer**: it reads live telemetry and archived logs from Firebase Realtime Database (RTDB), visualizes 24-hour and 7-day trends, computes an in-browser confidence-gated diurnal forecast, and sends a single command: requesting a timed manual ventilation run.

---

## Core Design Principle

> **Intelligence can add savings but never remove safety.**

The ESP32 firmware is the sole authority for room safety classification (**Safe**, **Caution**, **Danger**) and fan actuation. The application is an observer and polite requester. The app never decides to run or stop the fan on its own authority and never overrides or bypasses the Danger tier.

---

## Environment & Prerequisites

Tested and built against:
- **Flutter SDK**: `3.47.9` (channel `stable`)
- **Dart SDK**: `3.13.7`
- **Application Version**: `1.0.0+1` (defined in `pubspec.yaml` and `lib/core/config.dart`)
- **Firebase Regional RTDB**: `asia-southeast1` (`https://aerosense-502de-default-rtdb.asia-southeast1.firebasedatabase.app`)
- **Supported Targets**: Android (API 21+) and Web (modern desktop/mobile browsers)

---

## Setup & Configuration

### 1. Flutter Setup
Clone the repository and fetch dependencies:
```bash
git clone <repo-url>
cd aerosense_app
flutter pub get
```

### 2. Firebase Configuration
The project is already wired to the `aerosense-502de` Firebase project. If reconfiguring:
```bash
flutterfire configure --project=aerosense-502de --platforms=android,web
```
Verify that `lib/firebase_options.dart` contains the `databaseURL` pointing to `asia-southeast1`.

> **Note on Firebase Security & Web Keys:**
> The Firebase configuration parameters in `firebase_options.dart` (such as `apiKey` and `appId`) identify the Firebase project on Google servers. In client-side web and mobile apps, these identifiers are embedded in public client code by design and are not secrets. Real security is enforced on the server by **Firebase Authentication** and **Realtime Database Security Rules** (`database.rules.json`).

### 3. User Authentication & Accounts
- **Booth Visitors (Google Sign-In)**: Visitors authenticate instantly with "Continue with Google" without prior provisioning. They receive read-only access to `/system`, `/history`, and `/forecast` per RTDB security rules (`database.rules.json`) and cannot write triggers or toggle pre-ventilation settings.
- **Team Accounts (Email & Password)**: Team members must be provisioned in the **Firebase Console** (Authentication $\to$ Users $\to$ Add user). Use these credentials for administrative actions, manual ventilation requests, and automated pre-ventilation configuration.
  - *Booth Laptop Publishing Role*: Only one device should publish automated pre-ventilation triggers. The booth laptop must sign in with the email/password team account and enable **"This device publishes pre-ventilation"** in Settings. Google sign-in accounts are treated as visitors and will not see or execute publishing options.
- **Testing without credentials**: Click **Try Demo Mode** on the login screen to explore the app with simulated data.

### 4. Deploying RTDB Security Rules
The database rules enforce that visitors and team members must be authenticated to read, the ESP32 device writes telemetry, and only provisioned team accounts can request manual ventilation:
- `DEVICE_UID`: ESP32 device account UID.
- `TEAM_UID_1`: Giovanni's team account UID.
- `TEAM_UID_2`: Dedicated booth team account UID.

```bash
# Replace placeholders in database.rules.json before deploying:
firebase deploy --only database
```
*(Reference: see `database.rules.json`)*.

---

## Running the App

### Build commands

The live assistant reads `GEMINI_API_KEY` at build time from a JSON file passed with
`--dart-define-from-file`. Use **two different restricted keys**: `env.json` for web and
`env.android.json` for Android.

| Target | Command |
|---|---|
| Web release | `flutter build web --release --dart-define-from-file=env.json` |
| Android release APK | `flutter build apk --release --dart-define-from-file=env.android.json` |
| Demo web | `flutter build web --release --dart-define-from-file=env.json --dart-define=DEMO=true` |
| Demo APK | `flutter build apk --release --dart-define-from-file=env.android.json --dart-define=DEMO=true` |
| Run locally (web) | `flutter run -d chrome --dart-define-from-file=env.json` |
| Run locally (Android) | `flutter run --dart-define-from-file=env.android.json` |

Create the two local files from the committed templates and fill in the keys:

```bash
cp env.example.json env.json
cp env.android.example.json env.android.json
```

Both real files are gitignored and must never be committed. Without a key, the app still
builds and runs; only the **Ask AeroSense** action is hidden.

### Building Android APK & Web

Both builds read their settings from a JSON file with `--dart-define-from-file`. The web build
also carries the Gemini key (the assistant runs in the browser), so **both** builds need a key.

```bash
# 1. Android release APK (Gemini key for the assistant)
flutter build apk --release --dart-define-from-file=env.android.json
#    -> build/app/outputs/flutter-apk/app-release.apk

# 2. Web release (Gemini key for the assistant)
flutter build web --release --dart-define-from-file=env.json
#    -> build/web
```

The keys in both builds are **temporary competition keys**: create them in a separate no-billing
project, restrict each one per platform, keep the release APK to team and booth devices, and
**revoke both keys after the event**. The production design is a backend proxy; see
**Assistant and keys** below.

The landing page's **Get the Android app** button is a plain redirect to the public GitHub
Releases page:

```text
https://github.com/Rambolt375/aerosense-app/releases
```

It is a hard-coded constant (`AppConfig.apkReleasesUrl`), not a build flag: the page always lists
the newest build and its notes, so it cannot go stale or 404 when an asset is renamed. Publish the
APK as a GitHub Release asset; the button then opens the releases page in a new tab
(`noopener,noreferrer`) and the visitor picks the build there. Nothing is installed by the app
itself. The hero also has a **Download APK** button, which only scrolls down to this section so
the visitor reads what the build is first. To point the button elsewhere (a mirror, a direct
file), override `apkDownloadUrlProvider` or change the constant.

### Demo Mode (Fully Simulated Telemetry)

Demo Mode runs without a Firebase connection or hardware and uses the scripted assistant:

```bash
flutter run -d chrome --dart-define=DEMO=true
flutter run --dart-define=DEMO=true
```

Demo Mode can also be toggled at runtime from the **Login** screen ("Try Demo Mode") or the
**Settings** screen. The persistent **DEMO MODE** ribbon, the speed-dial action label, and the
Ask AeroSense screen all label scripted answers as scripted.

### Entry points and the public landing page

| Visitor | Web | Android |
|---|---|---|
| Signed out | `/` is the public landing page | straight to `/login` |
| Signed in | `/dashboard` | `/dashboard` |

The landing page is registered on both platforms, but a provider (`webLandingEnabledProvider`,
`kIsWeb` by default) decides what `/` does, so the redirect table is testable without a browser.
It is a static page: hero, the three states, how it works, cost, and a link to the dashboard.
"Try the demo" turns Demo Mode on and opens the dashboard in one tap.

Deep links still work. A signed-out visit to a guarded route goes to `/login?from=<location>`,
and sign-in returns there. `from` is honoured only for internal paths that are not `/`,
`/login`, `/splash` or `/dashboard`, so it cannot be used to bounce a visitor to an external
site. The router reads the auth state inside its redirect and is refreshed, never rebuilt, so an
auth event does not reset the location.

---

## Testing & Code Quality

```bash
# Format check / apply
dart format .

# Static analysis (must report zero issues)
flutter analyze

# Run complete test suite (unit, pipeline, widget, and responsive tests)
flutter test

# Fail if a tracked file contains a Google API key prefix
tool/check_no_secrets.sh
```

---

## Release Builds

The commands are in the table above. Outputs:

- Android APK: `build/app/outputs/flutter-apk/app-release.apk`
- Web: `build/web`

Notes:

- The Android manifest (`android/app/src/main/AndroidManifest.xml`) includes
  `android.permission.INTERNET` and application label `AeroSense`.
- Passing `--no-web-resources-cdn` to a web build downloads and bundles CanvasKit and static
  web resources locally, so the demo works even on unstable venue Wi-Fi.
- Demo builds keep the `DEMO MODE` ribbon; they never call the live assistant.
- The Android release APK is published as a GitHub Release, so it is publicly downloadable and the
  Android Gemini key inside it must be treated as **public**: no-billing free-tier key, revoked
  after the event, with the project quota as the only ceiling. See **Assistant and keys** below.

---

## Firebase Hosting Deployment

`firebase.json` is configured to serve the single-page application from `build/web` with URL rewrites to `/index.html`:

```bash
# 1. Build the production web bundle (the key file also carries the assistant key)
flutter build web --release --dart-define-from-file=env.json

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting
```

> **Crucial Firebase Auth Step for Web:**
> If hosting on a custom domain or standard Firebase Hosting domain (`<project-id>.web.app`), verify that the domain is listed under **Firebase Console $\to$ Authentication $\to$ Settings $\to$ Authorized domains**. Otherwise, Firebase Auth will reject sign-in attempts with `auth/unauthorized-domain`.

---

## Assistant and keys

Ask AeroSense is the only networked AI feature. It calls the Gemini REST API directly over HTTPS
(no Firebase AI Logic, no App Check) so the same implementation runs on web and Android:

```text
POST https://generativelanguage.googleapis.com/v1beta/models/gemini-3.5-flash-lite:generateContent
x-goog-api-key: <build-time key>
```

The key is sent **only** in the `x-goog-api-key` header. It is never placed in the URL, the
request body or a log. The request carries the approved rules plus the deterministic summary in
`systemInstruction`, the last four messages plus the new question in `contents`, and
`generationConfig` with `maxOutputTokens: 600`, `temperature: 0.3`. No tools, no writes.
`gemini-3.5-flash-lite` is the only model; there is no fallback model.

### Gating

The shell's bottom-end **Assistant** speed dial is the entry point for room explanations. With no
assistant key it opens the deterministic **Summarize** sheet directly. When `GEMINI_API_KEY` is
non-empty **and** a user is signed in, it expands to **Summarize** and **Ask AeroSense**. The rule
is identical on web and Android. In Demo Mode Ask is forced on, uses the scripted fake, and is
explicitly labelled as scripted. The dial hides while the soft keyboard is open and does not
appear on Login, Profile, or Ask AeroSense routes.

The app-bar account avatar opens a menu below the photo with **Profile** and **Sign out**. Profile
edits affect the AeroSense display name only; they do not change the Google or team-account name.

### Ask AeroSense screen

One full-width composer at the bottom, capped at 840 dp together with the transcript on wide
screens and inset 16 dp on phones. The field is multiline (1-4 lines) and Send is a 48 dp icon
button inside the field, disabled while the field is empty or a question is in flight. Enter sends
and Shift+Enter inserts a newline on web and desktop. The `n/300` counter only appears above 240
characters; the 300-character cap is unchanged. The field clears and keeps focus after sending.

The visitor's bubble appears immediately on send and on chip tap, with the thinking bubble below
it; the answer replaces the thinking bubble. On error or rate limit the visitor bubble stays and
the error card renders under it, and **Try again** re-sends the same question without adding a
second bubble. Only the previous messages (last four) are sent as history, never the question that
is currently in flight. The transcript scrolls to the newest message.

Under the composer there is one short line: "AI can be wrong. The device alert decides. Questions
go to Google Gemini." (Indonesian equivalent when the language selector is on Indonesia.) The info
button next to it opens an **About this assistant** sheet with the full wording, including "Don't
type personal information." and, in Demo Mode, the scripted-answers note.

### Key setup (competition-only exception)

The normal rule is "no API key in the app". This competition build is a documented exception:

1. Use a **separate, no-billing Google AI Studio project** and two **restricted free-tier keys**:
   - **Web key** (`env.json`): HTTP-referrer restricted to the hosted and localhost origins.
   - **Android key** (`env.android.json`): API-restricted only (Android apps cannot hide a key).
2. Supply each key at build time with `--dart-define-from-file`; never commit it. Create the real
   files from `env.example.json` and `env.android.example.json`.
3. The APK is distributed through a public GitHub Releases page, so anyone can download it and
   read the Android key inside. That is why it must be a free-tier, no-billing, API-restricted
   key whose worst case is quota exhaustion: monitor the project quota, and delete the key after
   the competition. Do not put a billed or unrestricted key in a published build.
4. **After the competition, delete both keys** in the Google AI Studio project. The app keeps
   building without them; only the assistant is hidden.

`tool/check_no_secrets.sh` fails if a tracked file contains a Google API key prefix. It allowlists
only the three generated, public Firebase client-config files (`lib/firebase_options.dart`,
`android/app/google-services.json`, `firebaseEndpointReference.js`), whose keys identify the
Firebase project by design. Run it before every commit and before builds.

The production design is a **backend proxy** (Firebase AI Logic with App Check), so no key ever
ships to a client. The direct-client route is a competition-only exception, not the long-term
architecture.

### Request behaviour and friendly errors

- **20 s timeout** per request. One automatic retry only for `503` / overloaded responses, about
  1.5 s later on the same model.
- **400 / 403:** "The assistant isn't set up right now."
- **429:** "The assistant is busy right now." (no retry)
- **503 / overloaded after the retry:** "The assistant is busy right now. Try again in a minute."
- **Timeout or no network:** "No connection."
- **Blocked or empty answer:** "I couldn't answer that."
- Every failure keeps the deterministic **Room summary** on screen. Questions and answers are
  never logged, and neither is the key or the request URL.
- Response parsing tolerates future fields (`thoughtSignature`, non-text parts, thought parts) and
  returns partial text when `finishReason` is `MAX_TOKENS`.

### Risks

| Risk | Handling |
|---|---|
| Key extraction from a client build | Two restricted free-tier keys in a no-billing project, no billing enabled, per-platform restrictions, build-time supply, no commits, keys deleted after the competition. The published APK's Android key is treated as public: free tier, no billing, quota monitored. The production design is a backend proxy. |
| Quota abuse | Client limiter (6 questions / 10 min, 1.5 s spacing), one request per question, 600 output tokens, no retries except one `503` retry, Demo Mode offline, free-tier quota monitoring. |
| Wrong answers | Grounded-only instruction, verbatim firmware tier, a pinned one-line disclaimer under the composer (full wording in the "About this assistant" sheet), summary one tap away, no tools, no write path. |
| Prompt injection | Visitor text only in the user turn, facts only in the system instruction, explicit ignore rule-changing requests, plain-text output, length cap. |
| Privacy | No chat storage, no personal data in the payload, no telemetry, no release logging. |
| Key leak in git | `env.json` and `env.android.json` are gitignored; `tool/check_no_secrets.sh` guards tracked files. |

---

## Data Contract Reference

### 1. `/system` (Live Telemetry, updated every 2 s by ESP32)
| Key | Type | Description |
|---|---|---|
| `temperature` | number (°C) | Ambient temperature from DHT22. |
| `humidity` | number (% RH) | Relative humidity from DHT22. |
| `airQuality` | number (0–4095) | Raw 12-bit ADC reading from MQ-135 (relative index, uncalibrated). |
| `fanStatus` | string / bool | `"ON"` / `"OFF"` reporting physical fan state. |
| `statusMessage` | string | Firmware tier keyword (`SAFE`, `CAUTION`, `DANGER`). |
| `manualToggle` | bool | Written by app as `true` only for manual ventilation; firmware resets to `false`. |
| `manualEndsAt` | number | Optional epoch seconds (UTC) target completion time for timed run. |

### 2. `/history` (Time-Series Archive, logged every 10 min by ESP32)
Each child is a chronological push key containing:
- `timestamp`: UTC epoch seconds or milliseconds.
- `temperature`: float (°C).
- `humidity`: float (% RH).
- `airQuality`: int (0–4095 raw ADC index).

The app reads `/history` with `orderByKey().limitToLast(1008)` (7-day window at 10-minute cadence) and performs live appends via `onChildAdded`.

### 3. `/config` (Device Configuration)
- `manualDurationSec`: Duration in seconds for a timed ventilation cycle (default: 300 s = 5 min).

### 4. `/forecast` (Automated Pre-Ventilation, team opt-in & trigger)
| Key | Type | Description |
|---|---|---|
| `allowPreventive` | bool | Written by app (`true`/`false`) from team Settings. Opts into automated pre-ventilation cycles ahead of predicted air quality peaks. |
| `preventiveTrigger` | bool | **App writes `true` only.** Requests an automated pre-ventilation cycle from the ESP32. Firmware keeps it `true` for the **whole run** and resets it to `false` only when the run ends. If disallowed (allowPreventive off), in Danger, or fan busy, firmware resets it immediately without starting the fan. The app NEVER writes `false` and performs NO retries. |

---

## Diurnal Forecasting & Requirements

The client-side forecasting engine (`lib/features/forecast/`):
1. Fits a 24-hour diurnal sinusoidal wave ($\hat{y}(t) = A\sin(\omega t + \phi) + C$) using 2-pass linear least-squares with outlier rejection ($1.4826 \times \text{MAD}$).
2. Evaluates the residual gate: $E = |y(t) - \hat{y}(t)| \le 3.0 \times \text{stddev}$.
3. **Data Requirements**: The mathematical fitter strictly requires **$\ge 48$ hours of continuous device uptime and history logs** with readings spanning at least **20 distinct hourly bins (0..23)**.
4. Below 48 hours of history, the UI displays a calm progress indicator: *"Awaiting sufficient history data to fit 24-hour diurnal sinusoidal wave"*.
5. In Demo Mode, a synthetic 7-day diurnal dataset (1008 points) is generated automatically to demonstrate the active forecast curve.

### Automated Pre-Ventilation (Phase 6c)

The companion app evaluates predictive pre-ventilation rules in a pure decision function (`evaluatePreventiveDecision` in `lib/features/forecast/preventive_decision.dart`):
1. **Team Opt-In**: `/forecast/allowPreventive == true` in Firebase RTDB.
2. **Model Confidence**: Air quality diurnal residual gate is `Active` (hysteresis verified, low live residual error).
3. **Variance Explained**: $R^2 \ge 0.3$ on the 24-hour diurnal sinusoidal fit.
4. **Stuffy Peak Threshold**: Predicted daily peak $\ge 1400$ ADC (the firmware Caution threshold).
5. **Lead Window**: Current time is 10 to 20 minutes before the predicted peak ($10 \le \Delta t \le 20\text{ min}$).
6. **Device Freshness**: Device is online (most recent `/history` record $\le 20$ minutes old).
7. **Safety Precedence**: Room tier is NOT Danger (Danger locks the fan ON unconditionally).
8. **Fan Idle**: Physical fan is not already running, no manual run is active, and no trigger is in flight.
9. **Single Trigger Per Peak**: Exactly one pre-ventilation cycle is triggered per diurnal peak.
10. **Cooldown**: Minimum 6 hours elapsed since the last pre-ventilation run.

#### Publisher Role & Persistence
- To avoid race conditions and redundant writes from multiple open tabs or phones, only the designated publisher device sends automated triggers.
- In **Settings $\to$ Automated Pre-Ventilation (Team)**, enable **"This device publishes pre-ventilation"** on the booth laptop. This preference and the execution timestamps (`lastTriggerTime`, `lastTriggeredPeakTime`) are persisted in `SharedPreferences`.
- When designated, an evaluation loop runs every 30 seconds and upon telemetry updates. If all 10 conditions pass, the app writes `/forecast/preventiveTrigger = true`.

#### Run Lifecycle
- An accepted trigger keeps `/forecast/preventiveTrigger = true` for the **entire run**. The firmware resets it to `false` only when the cycle ends, at which point the fan also stops.
- While the trigger is `true`, the app reports **Running** and disables the demo button.

#### Decline Detection
- When a pre-ventilation request is submitted, the app monitors `/forecast/preventiveTrigger` and the fan state.
- If the firmware resets `preventiveTrigger` back to `false` within 5 seconds without starting the fan, the app presents a floating SnackBar: *"The device declined (permission off or busy)"*.

#### Manual Trigger Is Demo-Only
- The **"Run pre-ventilation now (demo)"** button is rendered **only in Demo Mode**. In a live build the
  control is not in the widget tree at all: no disabled button, no placeholder and no reserved space.
- In live mode the pre-ventilation chain can only fire **automatically**, from the 30-second publisher
  loop described above. Nothing in the app can force a cycle by hand.
- The rest of the card (status pill, description) and the team **Settings → Automated Pre-Ventilation**
  switches behave identically in both modes.

#### Demo Mode Behavior
- In Demo Mode, the synthetic baseline stays clean and Safe ($< 1400$ ADC) so the automated path displays: *"Unavailable: predicted peak below stuffy threshold"*.
- Team members can test pre-ventilation actuation using the **"Run pre-ventilation now (demo)"** button on the `ForecastScreen`. It stays disabled with a visible reason when pre-ventilation is off, the device is offline, the room is in Danger, or a cycle is already running, and the decline SnackBar above is shown when the firmware refuses.

---

## Demo Day Checklist (Competition Presentation)

1. **Hardware Verification**:
   - Power on ESP32; confirm serial monitor connects to Wi-Fi.
   - Verify `/system` updates in the Firebase Console.
   - Test manual ventilation button in Caution: relay should click and countdown timer should begin.
   - Test Danger safety: apply heat to DHT22 or alcohol vapor to MQ-135; verify fan locks ON, banner turns red and pulses, and manual control is bypassed.
2. **Fallback if Wi-Fi or Hardware Fails**:
   - Open the app (Web or Android).
   - Click **Try Demo Mode** on the login screen or toggle **Demo Mode** in Settings.
   - Notice the persistent black **DEMO MODE** ribbon across the top.
   - Open **Settings $\to$ Run the demo**:
     - Tap **Simulate Kitchen Smoke**: demonstrates air quality spike into Danger ($\ge 2000$), auto-fan activation, red pulsing banner, and toggle lock.
     - Tap **Simulate Heat Spike**: demonstrates temperature ramping through Caution ($\ge 33.5$ °C) into Danger ($\ge 36.0$ °C), illustrating the safety handoff.
     - Tap **Simulate Sensor Unplugged**: simulates DHT22 disconnection; verifies dashboard renders `--` gracefully without crashing.
     - Tap **Reset to Baseline**: returns to clean Safe diurnal telemetry.
3. **In-App Notices**:
   - Notices appear at the top of History, Forecast, and Settings screens (hidden on Dashboard to prevent redundancy).
   - Danger notice cooldown: 2 minutes; Caution/Offline/Online: 10 minutes.
   - Notices auto-clear when the room returns to Safe.

---

## Bundling Inter Font Assets

The visual typography is designed for **Inter** with tabular figures (`FontFeature.tabularFigures()`). Currently, Flutter gracefully falls back to the system default sans-serif font (Roboto on Android, browser sans on Web).

To bundle Inter locally:
1. Download Inter static TrueType files (weights 400, 500, 600) from [rsms.me/inter](https://rsms.me/inter/) or Google Fonts.
2. Place the font files into `assets/fonts/`:
   - `assets/fonts/Inter-Regular.ttf` (weight 400)
   - `assets/fonts/Inter-Medium.ttf` (weight 500)
   - `assets/fonts/Inter-SemiBold.ttf` (weight 600)
3. In `pubspec.yaml`, uncomment lines 88–96:
   ```yaml
   fonts:
     - family: Inter
       fonts:
         - asset: assets/fonts/Inter-Regular.ttf
           weight: 400
         - asset: assets/fonts/Inter-Medium.ttf
           weight: 500
         - asset: assets/fonts/Inter-SemiBold.ttf
           weight: 600
   ```
4. Run `flutter pub get`.

---

## Known Limitations & Firmware Notes

- **Automated Pre-Ventilation (Phase 6c Firmware Integration)**:
  - App client logic, pure decision engine, single-publisher designation, decline detection, and demo controls are implemented and tested.
  - The firmware implementation of `/forecast/allowPreventive` and `/forecast/preventiveTrigger` is pending physical confirmation:
    - `// TODO(confirm)`: Does firmware reset `/forecast/preventiveTrigger` to `false` immediately on boot?
    - `// TODO(confirm)`: What is the exact cycle duration executed by firmware for pre-ventilation? (App assumes default 300 s, matching `/config/manualDurationSec`).
    - Confirmed contract modelled in `FakeSystemRepository`: `preventiveTrigger` stays `true` for the whole run and is reset to `false` only when the run ends; on decline (allowPreventive off, Danger, or fan busy) the firmware resets it immediately without starting the fan. Still worth a hardware check.
- **Air Quality Metric**: Raw 12-bit ADC value (0–4095) from MQ-135; uncalibrated relative index (never labeled ppm).
- **Device Staleness Detection**: Without a dedicated `/system/lastSeen` field in firmware, device offline state is evaluated against the newest 10-minute `/history` record ($2\text{ missed cycles} = 20\text{ min}$).
- **Single Room / Single Device**: Multi-room and HVAC mains control are out of scope for the companion app.
