# Phase 8 plan: profile page + assistant speed dial

Status: 8b in progress (2026-11-16). Slice 8a was approved; stop for human
review after slice 8b.

Sources of truth: `PRD_AEROSENSE_APP.md`, `DESIGN.md`, `AGENTS.md`, `TODO.md`,
`docs/phase-7b-plan.md`.

## Ground rules for both slices

- `setState` only for purely local, ephemeral UI state (inline edit form, saving
  flag). Shared state stays in Riverpod.
- No UI file imports `firebase_auth`. The new account model is plain Dart and is
  built in the data layer (`data/repositories/providers.dart`).
- No new dependencies. `Characters` (for emoji-safe initials and name length) is
  already available because `package:flutter/widgets.dart` re-exports
  `package:characters/characters.dart`.
- Write rules in `AGENTS.md` are unchanged: a Firebase Auth profile update is not
  a Realtime Database write. No RTDB path is touched in either slice.
- Visual rules: 0 elevation, 1 px outline, theme tokens only (no raw hex in
  widgets), 40 dp avatar inside a 48 dp target, tier colors never reused
  decoratively.
- Verify package APIs against the installed SDK/docs before use (`Image.network`
  -> `webHtmlElementStrategy`).

## Slice 8a: profile page

### 1. Account data layer

`lib/core/account_name.dart` (pure, no Flutter widgets):

- `displayNameMaxLength = 40`.
- `String? normalizeDisplayName(String? raw)`: trim, collapse inner whitespace
  runs to one space, drop control characters, reject empty or longer than 40
  grapheme clusters. Returns the cleaned name or `null` when invalid.
- `String accountInitial({String? displayName, String? email})`: first grapheme
  of the trimmed name, else of the email local part, else `?`; uppercased
  (emoji-safe because uppercase of an emoji is itself).

`AuthRepository` additions:

- `Stream<User?> userChanges()` — auth state **plus** profile changes.
- `Future<void> updateDisplayName(String name)` — normalizes defensively, throws
  `AuthFailure` on invalid input or platform failure.

`FirebaseAuthRepository`: `_auth.userChanges()` and
`_auth.currentUser?.updateDisplayName(name)`, mapped to
`AuthFailure(AppStrings.profileNameSaveFailed)` on any platform error. The
`userChanges` stream naturally re-emits after a profile update.

`FakeAuthRepository`: one mutable synthetic `User`, a broadcast change
controller, `userChanges()`/`authStateChanges()` both yield the current user then
the change stream (`async*`), `updateDisplayName` updates memory and emits.
Disposed through a dedicated provider, like `fakeSystemRepositoryProvider`.

`lib/data/models/account_info.dart`: plain `AccountInfo`
(`displayName`, `email`, `photoUrl`, `kind`, `isDemo`, `initial`) with
`AccountProviderKind { google, team, demo }`. Built in `providers.dart` from the
`User`; `accountProvider` is `Provider<AccountInfo?>` on
`userChangesProvider` so a rename repaints the avatar immediately.

Strings in `core/strings.dart`: `profileNameSaveFailed`
("Could not save your name. Check your connection."), `profileNameInvalid`,
`profileEditName`, `profileSave`, `profileCancel`, `profileNameSaved`,
`profileDemoNotSaved` ("Demo Mode: not saved"), `profileCaption`
("Changing your name only affects AeroSense."), `accountMenu`, `profileTitle`,
`signOut`, `signOutConfirm`, `providerGoogle` ("Google account"),
`providerTeam` ("Team account"), `providerDemo` ("Demo").

### 2. `/profile` route

Top-level `GoRoute(path: '/profile')` beside `/assistant`: outside the shell, so
no bottom navigation, and the existing auth guard already covers it. Pushed from
the account menu, so `AppBar` shows the automatic back arrow.

`ProfileScreen` (max width 640, `ListView`, 16/24 dp padding):

- 96 dp avatar (photo with a loading placeholder, `errorBuilder` -> initial).
- Display name (`titleLarge`), email read-only, provider chip
  (Google account / Team account / Demo).
- Caption "Changing your name only affects AeroSense.".
- "Edit name" inline form: `TextField` (40-char max), Save / Cancel, inline
  validation message, snackbar on save, snackbar with the friendly error on
  failure, `TextInputAction.done`. In Demo Mode the section additionally reads
  "Demo Mode: not saved" and the edit is in-memory only.
- Sign out button using the shared confirmation dialog.

Email and photo are read-only; only the name is editable.

### 3. Shared widgets

- `lib/shared/account_avatar.dart`: `AccountAvatar(photoUrl, initial, size)`.
  `Image.network` inside `ClipOval` with `webHtmlElementStrategy:
  WebHtmlElementStrategy.fallback`, a `loadingBuilder` placeholder and an
  `errorBuilder` that renders the initial. Rationale (verified in the installed
  SDK docs): CanvasKit cannot read cross-origin pixels unless the host sends
  CORS headers; `fallback` fetches bytes first and only switches to an HTML
  `<img>` (platform view) when the fetch fails, and the error builder is still
  used when neither route works — so the initial always shows instead of an
  exception box.
- `lib/shared/account_avatar_button.dart`: 48 dp target, 40 dp visual, tooltip =
  display name, semantics label "Account menu", `PopupMenuButton` with exactly
  two items ("Profile", "Sign out"). Sign out goes through the shared
  confirmation dialog, so a mis-tap never signs out.
- `lib/shared/sign_out_dialog.dart`: the dialog extracted verbatim from Settings
  so both entry points behave identically.

### 4. Shell app bar

Each of the four shell screens owns its `AppBar`, so the avatar is added to
Dashboard, History, Forecast and Settings `actions`. This covers both the mobile
`NavigationBar` and the wide `NavigationRail` layout. It is absent from `/login`,
`/profile` and `/assistant` by construction (those routes never include it).

Settings loses the whole Account card (name, email, chip, avatar, sign out); the
theme switcher, thresholds, forecast parameters, Demo controls and the team
pre-ventilation card stay. Settings tests for the account card are removed; the
sign-out test moves to the profile/avatar tests.

### 5. Tests (written first)

| File | Cases |
|---|---|
| `test/core/account_name_test.dart` | trim, inner whitespace collapse, control characters, empty, 40 ok / 41 rejected, emoji counted once; initial from name, email only, emoji name, emoji email, both empty, whitespace name with email. |
| `test/data/auth_repository_test.dart` | fake `updateDisplayName` trims/normalizes, updates `currentUser`, emits on `userChanges`, rejects empty/invalid with `AuthFailure`, `userChanges` yields the current user on subscribe (no missed emission). |
| `test/features/profile/profile_screen_test.dart` | renders name/email/provider chip/caption; photo set but fails -> initial still shown; Edit name save updates UI + snackbar; invalid name -> inline error, no repository call; repository failure -> friendly snackbar; cancel discards; Demo Mode shows "Demo Mode: not saved" and edits in memory; sign out asks for confirmation; no bottom navigation. |
| `test/features/profile/account_avatar_button_test.dart` | semantics label "Account menu"; tooltip is the display name; exactly two menu items; Profile opens `/profile`; Sign out confirms before calling the repository; avatar hidden on `/login`, `/profile`, `/assistant`; visible on all four tabs at 360 and 1280 px; avatar updates after a rename. |
| `test/features/responsive_overflow_test.dart` | Profile at 360x640, 768x1024, 1280x800 with 1.3x text. |

## Slice 8b: assistant speed dial

1. Remove `AskAboutRoomCard` from the dashboard (keep `SummarySheet`).
2. One expandable FAB in the shell, `FloatingActionButtonLocation.endFloat`,
   secondary/tonal, elevation 0, 1 px outline. Collapsed = single icon button
   (tooltip "Assistant"), tap rolls up to 250 ms (none when
   `MediaQuery.disableAnimations`) revealing "Summarize" and "Ask AeroSense"
   (only when `assistantEnabledProvider`). One available action = tap runs it.
   Closes on button tap, `TapRegion` outside tap, Escape and back; collapses
   before navigating. Hidden on `/login`, `/profile`, `/assistant` and while the
   keyboard is open.
3. Bottom padding on every scrollable shell screen; no floating SnackBar may
   overlap the FAB (the earlier "Floating SnackBar presented off screen" bug must
   not return).
4. Demo Mode honesty: scripted note pinned under the Ask screen title; menu
   action labelled "Ask AeroSense (scripted)" in Demo Mode.
5. Semantics/focus: labelled, focusable, Tab/Enter/Escape on web, logical focus
   order.
6. Offline tier banner: neutral "Last known: Caution at HH:mm" (Safe / Caution /
   Danger) instead of live wording.
7. README, DESIGN.md (profile + speed dial sections), TODO.md.

## Risks

| Risk | Handling |
|---|---|
| Cross-origin photo fails on web CanvasKit | `WebHtmlElementStrategy.fallback` + `errorBuilder` -> initial; tested. |
| Profile update not reflected until reload | `userChanges()` stream; `accountProvider` and the edit form both read it; test asserts the avatar text changes. |
| Stale emits from the fake auth stream | `async*` streams yield the current user on subscribe, then the broadcast change stream. |
| `updateDisplayName` used as a write path | Firebase Auth only; no RTDB path, write rules untouched. |
| Name rendered from untrusted input | Control characters stripped, whitespace collapsed, 40-char cap, single-line render with ellipsis. |
