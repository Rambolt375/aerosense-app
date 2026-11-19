# Phase 9 plan: demo-only pre-ventilation button, assistant composer, web landing page

Status: implemented (2026-11-19). Three small items, implemented in order A → B → C,
test-first, with a report after each. No release builds and no deploys in this
phase (the human compiles web and APK).

Sources of truth: `PRD_AEROSENSE_APP.md`, `DESIGN.md`, `AGENTS.md`, `TODO.md`,
`docs/phase-8-plan.md`.

## Ground rules

- Test first: write/adjust the failing test, then the implementation.
- No new dependencies. `package:web` is already a dependency (used by
  `core/browser_utils_web.dart`); the APK link uses it through a conditional
  import so Android keeps compiling.
- Write rules in `AGENTS.md` are unchanged. Nothing here writes to RTDB.
- Theme tokens only, 1 px outlines, no elevation, light and dark, tier colors
  never decorative.
- Strings live in one place (`core/strings.dart`, plus one landing copy file).

## Item A: pre-ventilation demo button only in Demo Mode

`PreVentilationCard` renders the "Run pre-ventilation now (demo)" section
(button, pending spinner, disabled-reason line and the divider above them) only
when `demoModeProvider` is true. In live mode the section is not in the widget
tree at all: no disabled button, no placeholder, no divider, no reserved space.
The status pill, description, and the team Settings switches are untouched.
Demo Mode keeps today's behaviour: enabled/disabled with visible reasons and the
decline snackbar.

Tests: live mode -> no button, no reason line, no divider, card height equals the
card height with the section absent; Demo Mode -> button present, disabled reason
shown when a gate fails, enabled when armed, decline snackbar still shown.

Docs: README (live mode can only fire automatically), DESIGN.md, TODO.md.

## Item B: assistant (chat) UI

### Composer

- One full-width field inside the content area: 16 dp padding on phones; on wide
  screens transcript and composer share one centered max width, raised from 720
  to 840 dp.
- Multiline, 1..4 lines.
- Send is a suffix icon button inside the field: 48 dp target, tooltip and
  semantics "Send", disabled while empty or in flight.
- Enter sends, Shift+Enter inserts a newline (web/desktop), implemented with
  `CallbackShortcuts` so it also works in widget tests.
- Counter (`n/300`) appears only above 240 characters; the 300 cap stays.
- Field clears on send and keeps focus.

### Transcript

- `AssistantChatState` gains `pendingQuestion`: the visitor bubble is rendered
  immediately on send and on chip tap, before any answer.
- The thinking bubble (existing skeleton) sits below it; the answer replaces it.
- On error or rate limit the visitor bubble stays, the error card renders under
  it, and "Try again" re-sends the same question without adding a second bubble.
- History sent to the repository stays the previous messages only (last 4); the
  in-flight question is never included.
- Auto-scroll to the newest message (jump instead of animate when
  `disableAnimations`).

### Footer

- One short line under the composer, EN/ID following the language selector:
  "AI can be wrong. The device alert decides. Questions go to Google Gemini."
- Info icon button (tooltip "About this assistant") opens a small sheet with the
  full previous wording, including "Don't type personal information." and, in
  Demo Mode, the scripted-answers note.

Tests: message order, error keeps the bubble, retry does not duplicate, history
excludes the in-flight question, composer full width at 360/768/1280 with 1.3x
text, Send inside the field, Enter/Shift+Enter, counter threshold, disclaimer EN
and ID, info sheet contents.

## Item C: landing page (web only)

### Routing

- New public route `/` (landing). Registered always, but a new injectable
  provider `webLandingEnabledProvider` (`kIsWeb` by default) decides what it
  does: web signed-out users stay on the landing page, Android redirects `/` to
  `/login`.
- Signed-in users always go to `/dashboard` (including `/` and `/login`).
- Deep links keep working: a signed-out visit to a guarded route redirects to
  `/login?from=<encoded location>`, and `/login` returns to `from` after sign-in.
  `from` is only honoured when it is an internal path that is not `/`, `/login`
  or `/splash`.
- `routerProvider` stops rebuilding on auth-state changes (it reads the auth
  state inside the redirect and keeps `refreshListenable`), otherwise a sign-in
  recreates the router at `/splash` and loses `from`.

### Content (English, one strings file)

Hero (logo, name, one line, "Open dashboard" -> `/login`, "Try the demo" -> Demo
Mode on + `/dashboard`, and a "Download APK" shortcut that scrolls to "Get the
app"), "Three states, one rule" cards from `TierColors`,
"How it works" four steps, "Low cost" (about Rp 200,000 in parts, solderless,
homes and boarding houses), "Get the app" (web dashboard; a primary "Get the
Android app" button with the Android logo that redirects to the public GitHub
Releases page, opened with `window.open(..., 'noopener,noreferrer')`),
footer "Prototype by Team Kirkversary for Techtonic 3.0" + `AppConfig.appVersion`.
No ppm, no savings percentages, no unmeasured claims.

### Layout and shell

Max width 1100, hero two columns at >= 900 dp, headings with semantics, logical
focus order, no overflow at 360/768/1280 with 1.3x text, one light entrance
animation that is skipped when `disableAnimations`.

`web/index.html`: meta description, theme-color `#06293D`, Open Graph tags with
`https://aerosense-502de.web.app/icons/Icon-512.png`.

The APK link is a hard-coded constant (`AppConfig.apkReleasesUrl`), not a build
flag: the releases page always lists the newest build and cannot go stale. Since
that makes the APK publicly downloadable, the Android key inside it is treated as
public (free tier, no billing, revoked after the event).

README: "Building Android APK & Web" section with the exact commands, the
Gemini key in both builds (temporary event build, key revoked afterwards), and
how the releases page is published and linked.

Tests: redirect table (web signed out -> landing, Android signed out -> login,
signed in -> dashboard, deep link round-trip), button navigation, "Try the demo"
enables Demo Mode, APK button hidden/shown, copy test (no ppm, no percentage
savings), layout at 360/768/1280 with 1.3x text.

## Risks

| Risk | Handling |
|---|---|
| Router recreated on auth events loses the deep link | `routerProvider` reads auth state inside the redirect; `refreshListenable` drives re-evaluation. Test covers login -> back to `/history`. |
| Enter/Shift+Enter differ per platform | Both are explicit `SingleActivator` bindings; Shift+Enter inserts the newline into the controller, so behaviour is identical and testable. |
| `package:web` breaks the Android build | Conditional import with a no-op stub, same pattern as `browser_utils`. |
| APK button with an empty URL | Hidden by construction; provider override test asserts both states. |

## Outcome

- Item A: `_DemoTriggerSection` mounted only in Demo Mode; live card height asserted equal.
- Item B: composer/transcript/footer rework; `pendingQuestion` keeps the in-flight question out
  of repository history; copy moved to `AssistantCopy`; three dead `AppStrings` removed.
- Item C: `/` landing page behind `webLandingEnabledProvider`; router no longer rebuilt on auth
  events; `safeRedirectFrom` guards the deep-link round trip; the Android button redirects to
  the public GitHub Releases page; `web/index.html` metadata; README build and entry-point
  sections.
- Verification: `dart format .`, `flutter analyze` (0 issues), `flutter test` (all passing),
  `tool/check_no_secrets.sh`. No builds, no deploys.
