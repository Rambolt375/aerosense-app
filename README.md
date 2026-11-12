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

### 3. Creating Auth Users
Public self-signup is disabled in the app by default (`AppConfig.allowSignUp = false`). Users must be provisioned in the **Firebase Console**:
1. Open the [Firebase Console](https://console.firebase.google.com/) $\to$ Authentication $\to$ Users.
2. Click **Add user** and create an Email/Password account.
3. Use these credentials to sign in on the app's login screen.
4. *Tip for testing without credentials*: Click **Try Demo Mode** on the login screen to enter immediately without Firebase.

### 4. Deploying RTDB Security Rules
The database rules enforce that users must be authenticated to read, devices write telemetry, and users can only write `true` to `manualToggle`:
```bash
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
| `manualToggle` | bool | **The only field written by the app.** App writes `true` only; firmware resets to `false`. |
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

---

## Diurnal Forecasting & Requirements

The client-side forecasting engine (`lib/features/forecast/`):
1. Fits a 24-hour diurnal sinusoidal wave ($\hat{y}(t) = A\sin(\omega t + \phi) + C$) using 2-pass linear least-squares with outlier rejection ($1.4826 \times \text{MAD}$).
2. Evaluates the residual gate: $E = |y(t) - \hat{y}(t)| \le 3.0 \times \text{stddev}$.
3. **Data Requirements**: The mathematical fitter strictly requires **$\ge 48$ hours of continuous device uptime and history logs** with readings spanning at least **20 distinct hourly bins (0..23)**.
4. Below 48 hours of history, the UI displays a calm progress indicator: *"Awaiting sufficient history data to fit 24-hour diurnal sinusoidal wave"*.
5. In Demo Mode, a synthetic 7-day diurnal dataset (1008 points) is generated automatically to demonstrate the active forecast curve.

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

- **Pre-ventilation / Predictive Fan Start**: Postponed pending firmware schema support. The app does not schedule automated unattended fan runs.
- **Air Quality Metric**: Raw 12-bit ADC value (0–4095) from MQ-135; uncalibrated relative index (never labeled ppm).
- **Device Staleness Detection**: Without a dedicated `/system/lastSeen` field in firmware, device offline state is evaluated against the newest 10-minute `/history` record ($2\text{ missed cycles} = 20\text{ min}$).
- **Single Room / Single Device**: Multi-room and HVAC mains control are out of scope for the companion app.
