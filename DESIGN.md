# DESIGN.md: AeroSense Companion App

Visual system for the AeroSense app (Flutter, Android + Web). **Mood: clean and clinical.** Calm, precise, medical-instrument feel. Lots of whitespace, thin borders instead of shadows, numbers as the heroes. The UI should feel like a trustworthy monitor, not a consumer gadget.

Implementation: map these tokens to `core/theme.dart` (`ThemeData` with an explicit `ColorScheme`, plus a `ThemeExtension<TierColors>` for tier colors). Never hard-code hex values in widgets.

## 1. Principles

1. **Data first.** The current reading and tier are the largest things on screen. Chrome stays quiet.
2. **Status is sacred.** Green / Amber / Red mean Safe / Medium / Danger and nothing else. The brand blue is never used for status, and status colors are never used decoratively.
3. **Never color alone.** Every tier shows color + icon + text.
4. **Flat and bordered.** 1 px outlines, no drop shadows, no gradients, no glassmorphism.
5. **Calm by default.** Motion is minimal. Only Danger draws attention.

## 2. Color tokens

### Light

| Token | Hex | Use |
|---|---|---|
| `background` | `#F6F8FA` | Page background |
| `surface` | `#FFFFFF` | Cards, sheets |
| `surfaceAlt` | `#EDF1F5` | Inputs, chips, chart plot area |
| `outline` | `#D5DDE5` | 1 px card borders, dividers |
| `textPrimary` | `#0F1B2A` | Headings, values |
| `textSecondary` | `#4F5F6F` | Labels, captions |
| `textTertiary` | `#5E6D7C` | Hints, axis labels |
| `primary` | `#1D5FA7` | Buttons, links, selected nav, chart line |
| `onPrimary` | `#FFFFFF` | Text on primary |
| `primaryContainer` | `#E4EEF9` | Selected states |

### Dark

| Token | Hex |
|---|---|
| `background` | `#0B131B` |
| `surface` | `#121D28` |
| `surfaceAlt` | `#1A2836` |
| `outline` | `#283849` |
| `textPrimary` | `#E8EEF4` |
| `textSecondary` | `#9DB0C2` |
| `textTertiary` | `#6F8296` |
| `primary` | `#6FA8E8` |
| `onPrimary` | `#0B131B` |
| `primaryContainer` | `#1B3350` |

### Tier colors (fixed meaning, `TierColors` ThemeExtension)

| Tier | Light solid / text | Light container | Dark solid / text | Dark container | Icon |
|---|---|---|---|---|---|
| **Safe** | `#12704E` | `#E3F5EC` | `#3CC98E` | `#123528` | `check_circle` |
| **Medium** | `#9A6200` | `#FFF3D6` | `#F2B544` | `#3A2C0E` | `warning_amber` |
| **Danger** | `#C62833` | `#FDE7E9` | `#FF6B77` | `#4A1C21` | `error` |

Use the container color as the banner/chip background and the solid color for text, icon, and border. Chart bands use the solid color at **12% opacity**.

All text/background pairs must meet WCAG AA (4.5:1; 3:1 for large text and icons).

## 3. Typography

Font: **Inter** (bundle as an asset or use `google_fonts`; fall back to the platform sans). Enable tabular figures (`FontFeature.tabularFigures()`) on every changing number so digits don't jitter.

| Role | Size / line | Weight | Use |
|---|---|---|---|
| `metricValue` | 44 / 48 | 600 | Live reading (e.g. 27.4) |
| `metricUnit` | 16 / 24 | 500 | °C, %, units next to value |
| `titleLarge` | 22 / 28 | 600 | Screen titles |
| `titleMedium` | 16 / 24 | 600 | Card titles, tier banner |
| `body` | 14 / 20 | 400 | Default text |
| `label` | 12 / 16 | 500 | Metric labels, chips, axis text |
| `caption` | 11 / 14 | 400 | Timestamps, footnotes |

Sentence case everywhere. No ALL CAPS except the "DEMO MODE" ribbon.

## 4. Layout and spacing

- 4 px grid. Spacing scale: `4, 8, 12, 16, 24, 32, 48`.
- **Radius:** cards 12, inputs/buttons 8, chips and pills 999.
- **Borders:** 1 px `outline`. No elevation (`elevation: 0`, `surfaceTintColor: transparent`).
- **Mobile (< 600 dp):** single column, 16 dp page padding, bottom `NavigationBar` (Dashboard / History / Forecast / Settings).
- **Tablet (600-899):** 24 dp padding, 2-column metric grid.
- **Web desktop (≥ 900):** `NavigationRail`, content max width 1200, 24 dp gutters, dashboard in a 12-col grid (metrics 3 tiles across, charts 2 across).

## 5. Components

- **Metric tile** (temperature, humidity, air quality): surface card, label (`label`, textSecondary) with a 20 dp outlined icon, then `metricValue` + `metricUnit`. A small tier-colored dot + word ("Safe") in the corner shows that metric's own state. Air quality shows the raw index with the caption "Relative index, uncalibrated".
- **Tier banner:** full-width, tier container color, 1 px tier-colored border, icon + `titleMedium` title ("Room is safe" / "Room is getting stuffy" / "Hazardous air detected") and the firmware `statusMessage` below in `body`.
- **Fan card:** fan icon (`toys_outlined` / `mode_fan_off_outlined`), sentence case state header ("Fan on" / "Fan off"), full-width timed ventilation button (`FilledButton.tonal`), and context helper text. The action button is enabled ONLY in Caution idle state; disabled in Running, Safe, Danger, Danger latched, Waiting for device, and Offline states. When running, the countdown text ("Fan running, M:SS left") is isolated in its own 1 s ticker widget.
- **Chart card:** title + range segmented control (1h / 6h / 24h / 7d) in the header. Plot area `surfaceAlt`. Horizontal threshold bands (Safe / Medium / Danger at 12%). Line 2 px `primary`, no area fill, no dots except the touched point. Grid lines `outline` at 50%. Axis text `label` in `textTertiary`. **Forecast** line is dotted (4 on / 4 off) `textSecondary`.
- **Forecast status card:** pill showing *Learning / Active / Locked out*, one line of explanation. Locked out uses the Medium container color and the text "Predictive layer locked out. Deterministic safety logic in control."
- **Chips:** connection (`wifi` / `wifi_off`), last update time. Height 28, `surfaceAlt`, `label` text.
- **Buttons:** filled (primary), outlined (outline border, textPrimary), text. Height 44, min touch target 48.
- **Demo ribbon:** 24 dp strip at the top, `#0F1B2A` background, white "DEMO MODE", always visible.
- **Empty / loading:** skeleton blocks in `surfaceAlt`, no spinners over content. Empty states: one icon, one sentence.

## 6. Iconography

Material Symbols, **outlined**, weight 400, 20-24 dp. Thermostat (temperature), `water_drop` (humidity), `air` (air quality), `mode_fan` (fan), `check_circle` / `warning_amber` / `error` (tiers), `wifi` / `wifi_off` (connection). No emoji.

## 7. Motion

- 150 ms (small state changes) and 250 ms (cards, nav), `Curves.easeOut`.
- Value changes: cross-fade the number, never count up.
- **Danger only:** the tier icon pulses opacity 1.0 to 0.6 over 1.2 s, repeating. Nothing else animates continuously.
- Respect `MediaQuery.disableAnimations`: no pulse when set.

## 8. Voice and copy

Plain, calm, factual. Short sentences, no exclamation marks, no jargon, no blame. Always use sentence case for headers (e.g. "Fan on" / "Fan off").

**Tier status:**
- Safe: "Room is safe"
- Medium: "Room is getting stuffy. The fan stays off unless you turn it on."
- Danger: "Hazardous air detected. The fan is running automatically."

**Fan control:**
- Caution idle (duration known): "Room is stuffy. The fan stays off unless you turn it on."
- Caution idle (duration unknown): "The fan runs for a fixed time set by the device."
- Running: "Manual ventilation is on. The fan is running."
- Danger latch: "Fan stays on until the room is safe."
- Safe tier: "The fan stays off while the room is safe. Manual ventilation is available when the room gets stuffy."
- Danger tier: "Safety override active. The fan is forced on and manual control is bypassed."
- Waiting for device: "Waiting for the device to turn off the fan."
- Confirmation failure / rejection snackbar: "The device didn't start the fan. The room may no longer be in the stuffy range."

## 9. Do / Don't

| Do | Don't |
|---|---|
| Use whitespace and thin borders for structure | Use shadows, gradients, or glass effects |
| Reserve green/amber/red for tiers and chart bands | Use red or green for buttons, accents, or decoration |
| Show units and tabular digits | Show uncalibrated air quality as ppm |
| Show `--` for missing data | Show 0 or fake values for missing data |
| Keep one primary action per screen | Add decorative illustrations or mascots |
| Support light and dark from day one | Ship only a light theme |