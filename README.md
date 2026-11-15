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

### Live Mode (Connected to Physical Hardware / Firebase)
```bash
# Web
flutter run -d chrome

# Android
flutter run
```

### Demo Mode (Fully Simulated Telemetry)
You can launch directly in Demo Mode without requiring a Firebase connection or hardware:
```bash
flutter run -d chrome --dart-define=DEMO=true
flutter run --dart-define=DEMO=true
```
Demo Mode can also be toggled dynamically at runtime from the **Login** screen ("Try Demo Mode") or the **Settings** screen.

---

## Testing & Code Quality

```bash
# Format check / apply
dart format .

# Static analysis (must report zero issues)
flutter analyze

# Run complete test suite (unit, pipeline, widget, and responsive tests)
flutter test
```

---

## Release Builds

### 1. Android Release APK
The Android manifest (`android/app/src/main/AndroidManifest.xml`) includes `android.permission.INTERNET` and application label `AeroSense`.

```bash
# Standard Production APK (Connected to Firebase)
flutter build apk --release
# Output: build/app/outputs/flutter-apk/app-release.apk

# Competition Demo APK (Starts with Demo Mode enabled)
flutter build apk --release --dart-define=DEMO=true
# Copy/rename output:
cp build/app/outputs/flutter-apk/app-release.apk build/app/outputs/flutter-apk/aerosense-demo-release.apk
```

### 2. Web Release
```bash
# Standard Production Web
flutter build web --release
# Output: build/web

# Competition Demo Web (Bundles static renderer assets locally without CDN reliance)
flutter build web --release --dart-define=DEMO=true --no-web-resources-cdn
# Output: build/web
```
*Note: Passing `--no-web-resources-cdn` downloads and bundles CanvasKit and static web resources locally, ensuring the demo web app works reliably even if venue Wi-Fi is unstable or offline.*

---

## Firebase Hosting Deployment

`firebase.json` is configured to serve the single-page application from `build/web` with URL rewrites to `/index.html`:

```bash
# 1. Build the production web bundle
flutter build web --release

# 2. Deploy to Firebase Hosting
firebase deploy --only hosting
```

> **Crucial Firebase Auth Step for Web:**
> If hosting on a custom domain or standard Firebase Hosting domain (`<project-id>.web.app`), verify that the domain is listed under **Firebase Console $\to$ Authentication $\to$ Settings $\to$ Authorized domains**. Otherwise, Firebase Auth will reject sign-in attempts with `auth/unauthorized-domain`.

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
- When a pre-ventilation request is submitted (or when clicking **Run pre-ventilation now (demo)**), the app monitors `/forecast/preventiveTrigger` and the fan state.
- If the firmware resets `preventiveTrigger` back to `false` within 5 seconds without starting the fan, the app presents a floating SnackBar: *"The device declined (permission off or busy)"*.

#### Demo Mode Behavior
- In Demo Mode, the synthetic baseline stays clean and Safe ($< 1400$ ADC) so the automated path displays: *"Unavailable: predicted peak below stuffy threshold"*.
- Team members can test pre-ventilation actuation using the **"Run pre-ventilation now (demo)"** button on the `ForecastScreen`.

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
