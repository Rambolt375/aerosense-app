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
- **Pre-ventilation card:** status pill (*Off / Armed / Running / Unavailable*), one line of explanation, and — **Demo Mode only** — a team-only "Run pre-ventilation now (demo)" outlined button with a visible disabled reason. In live mode the button, its reason line and the divider above it are not built at all, so the card keeps its normal height and no manual trigger exists; the chain can only fire automatically.
- **Chips:** connection (`wifi` / `wifi_off`), last update time. Height 28, `surfaceAlt`, `label` text.
- **Buttons:** filled (primary), outlined (outline border, textPrimary), text. Height 44, min touch target 48.
- **Assistant speed dial:** one secondary-container FAB at the shell's bottom end. It has a 1 px outline and no elevation. If both actions are available, it expands upward in 250 ms to `Summarize` then `Ask AeroSense`; with only summary available, it opens the summary directly. It is hidden while the keyboard is open and on full-screen Login, Profile, and Ask routes. Shell scroll views reserve bottom space for it, and floating SnackBars use the standard scaffold placement above it.
- **Ask AeroSense screen:** full-height route with the transcript above and one composer pinned at the bottom. Transcript and composer share one centered max width of 840 dp (16 dp inset on phones, 24 dp on wide screens). Visitor bubbles are right-aligned in the primary container, assistant bubbles left-aligned in `surfaceContainerHighest`; both use a 1 px `outline` border, 12 radius, max 560 dp wide. The thinking indicator is a 16 dp `CircularProgressIndicator` plus "Thinking..." in `textSecondary`, and the answer replaces it in the same position. The composer is a full-width multiline field (1-4 lines) with a 48 dp circular Send icon button as its suffix, filled with `primary` when enabled and `surfaceAlt` when not. Under the composer sits one `bodySmall` line in `textSecondary` and a 48 dp info icon button; the full disclaimer and privacy wording open in a bottom sheet, not on the screen.
- **Account menu:** opens below the app-bar avatar so the avatar remains visible. It contains only Profile and Sign out.
- **Demo ribbon:** 24 dp strip at the top, `#0F1B2A` background, white "DEMO MODE", always visible.
- **Empty / loading:** skeleton blocks in `surfaceAlt`, no spinners over content. Empty states: one icon, one sentence.

## 6. Iconography

Material Symbols, **outlined**, weight 400, 20-24 dp. Thermostat (temperature), `water_drop` (humidity), `air` (air quality), `mode_fan` (fan), `check_circle` / `warning_amber` / `error` (tiers), `wifi` / `wifi_off` (connection). No emoji.

### Public landing page (web only)

A document, not a dashboard: flat surfaces, 1 px `outline` borders, no elevation, no gradient, no illustration, and the same tokens as the app in light and dark.

- Content is centered with a 1100 dp max width; 16 dp page padding under 600 dp, 24 dp above.
- The hero is two columns at 900 dp and wider (copy left, 144 dp rounded app icon right) and one column below it (icon, then copy).
- The "Three states, one rule" cards use `TierColors` container + 1 px solid border. Every card pairs its icon with the word, because tier is never shown by colour alone.
- Sections in order: hero, three states with the closing line "The device decides. The app shows and asks.", how it works (four numbered steps, 1/2/4 columns by width), low cost, get the app, footer.
- Headings are marked as headers for screen readers, and the focus order is the reading order.
- The "Get the Android app" button is a primary filled button with the Android logo: a plain redirect to the public GitHub Releases page (`AppConfig.apkReleasesUrl`), so it is always shown and never points at a file the app serves. It opens in a new tab with `noopener,noreferrer`.
- The hero has a third, outlined "Download APK" button that only scrolls to the "Get the app" section; it does not download by itself, so the visitor reads what the build is before leaving the page.
- One 400 ms fade-and-rise entrance for the whole page, skipped when `MediaQuery.disableAnimations` is set.

## 7. Motion

- 150 ms (small state changes) and 250 ms (cards, nav), `Curves.easeOut`.
- Value changes: cross-fade the number, never count up.
- **Danger only:** the tier icon pulses opacity 1.0 to 0.6 over 1.2 s, repeating. Nothing else animates continuously.
- **Assistant transcript:** new messages scroll into view with a 150 ms ease-out; with `disableAnimations` the transcript jumps instead.
- **Landing page:** one 400 ms fade-and-rise on first paint; with `disableAnimations` the content is simply there.
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
| Say what the device does and what the app asks | Claim savings percentages or measured results we have not measured |
| Support light and dark from day one | Ship only a light theme |
