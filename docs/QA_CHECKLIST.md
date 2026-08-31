# Waypoint — QA checklist

What to validate on a simulator build, by feature area. Update this file
whenever new screens/flows land; treat it as the source of truth for what
"done" means functionally, alongside `test_report.json`'s automated results.

Known tooling gotcha: `xcrun simctl io screenshot` has produced misleading
captures in this environment in (at least) two distinct ways: (1) a
correctly-sized, fixed-size widget rendered as a wildly stretched rectangle
in the screenshot while the actual on-screen content (confirmed via
`simctl io recordVideo` + a QuickLook thumbnail) was correct, and (2) under
rapid successive calls, it can serve stale/byte-identical duplicate frames
rather than the current screen. If a screenshot shows something that seems
physically implausible given the code, or two screenshots taken moments
apart look suspiciously identical despite navigating, cross-check with a
video-frame capture or direct widget-tree inspection before filing it as a
bug.

## Onboarding (`OnboardingFlow`) — real auth, 3 sign-in paths

Apple and Google OAuth are now fully configured (Google Cloud Console +
Supabase provider setup both done — see `PROGRESS.md`). Both should be
able to complete end-to-end, though driving Apple/Google's native system
UI to a full successful finish is still outside `integration_test`'s
reach — structural checks (button presence, no crash, spinner behavior)
remain the practical ceiling for those two specifically.

- Sign-in screen (`SignInStep`): Apple button only shows on iOS; Google
  button on both; tapping either shows a loading spinner and doesn't
  crash; a cancelled Apple sheet doesn't show a spurious error.
- **Email sign-in (new)**: "Continue with email" pushes a new screen
  (email field, "Send code" button). Submitting an invalid email (no @,
  no domain) shows an inline error without calling Supabase. A valid
  email calls `sendEmailOtp` and pushes the 6-digit code entry screen —
  can't verify actual email delivery/receipt via `integration_test`
  (same "real external system" limitation as OAuth), but the screen
  transition, loading states, and "resend code" button should all work
  without crashing regardless of whether a real code ever arrives.
  Entering a wrong/expired code shows "That code is invalid or expired"
  inline, not a crash. Back button on either email screen returns
  correctly (email code screen -> email entry screen -> sign-in screen).
- Profile Details step: phone + address fields behave as before ("Use
  current location" fills them); "Finish" doesn't crash even if
  `saveProfile` fails. **New**: if sign-in didn't provide a name (this
  only happens via the email path — Apple/Google always give one),
  First/Last name fields appear above phone; "Finish" is blocked with an
  inline error until First name is filled; these fields do NOT appear at
  all after Apple/Google sign-in (should never see them there).
- All Set -> Enable Face ID step (only for a genuinely new account,
  detected via `isNewUser`) — "Enable Face ID" and "Not now" both
  tappable without crashing.
- Cold launch with no session lands on the sign-in screen; with a
  persisted session, skips straight to Home (or the Face ID gate if
  enabled) — no crash from `_StartupGate`'s session check either way.

## Home tab (`HomeTab`)

- Greeting shows the right first name and initials avatar.
- "Next trip" hero card: landscape art renders (not blank/broken), correct
  trip name/destination/date, avatar stack caps at 2 visible + a "+N"
  overflow badge matching the actual remaining member count.
- Tapping the hero card opens Trip Detail for that trip.
- "Create a group" now opens the real `CreateGroupFlow` wizard (see new
  section below) — no longer disabled. "Join with code" is still visibly
  disabled — confirm it doesn't crash or silently no-op with a stray
  console error.
- Recent activity list renders all sample items.
- After creating a group (see below), Home's hero card should immediately
  show the NEW trip, not the old default (Lake Tahoe Crew) — `AppData`'s
  `nextTrip` is the first `upcoming` trip and newly created trips are
  inserted at the front.

## Trip Detail (`TripDetailScreen`)

- Hero image shows the days-left badge (top-right) and destination + date +
  ETA (bottom-left) — values match the `Trip` passed in.
- "Start" button shows a snackbar placeholder, no crash (real navigation
  deep-link is a future task).
- Weather card shows the trip's temp/condition.
- Members section: admin (You) + every `TripMember`, each with the correct
  status badge (Admin/Member/Invited) and distance text.
- Chat icon opens `ChatScreen` for the same trip.

### Today's ETAs (new — only shows on trip day)

None of the 3 seeded sample trips are dated today, so this section won't
appear on them — **create a new trip via the group wizard with today's
date** (Home > Create a group > pick today in the date picker) to test it.
It should appear between the weather/Start row and Members, and NOT
appear at all on any trip whose date isn't today (including all 3 seeded
trips) or on past trips.

- Tapping "Share my ETA" triggers the OS location-permission prompt the
  first time (can't be driven by `integration_test` — check it appears
  and that denying it surfaces "Location access is off..." rather than
  hanging or crashing). Granting it (or pre-granting via Simulator's
  Settings app, or `xcrun simctl privacy <udid> grant location
  com.srigautham.waypoint` beforehand) should let the flow complete.
- On success: the button relabels to "Update my ETA (N min)", "You" in
  the list below shows that same value + "just now", and every other
  listed member shows "Not shared yet" (there's no real second account
  sharing into the same trip in this environment, so that's the expected
  steady state, not a bug).
- Tapping "Update my ETA" again re-shares (button shows a spinner, no
  double-fire if tapped rapidly) and the "just now"/minute-count should
  refresh.
- Denying location, disabling location services, or being offline should
  each surface a specific, readable error message under the button (see
  `_errorMessage` in `trip_detail_screen.dart` for the exact wording per
  case) — never a crash or a silently stuck spinner.
- Backend check (optional, if you want to go one level deeper): the
  `trip_day_status` table in Supabase should get a row per (trip_id,
  your user_id) that upserts in place on repeat shares, not a new row
  each time.

## Chat (`ChatScreen`)

- Seeded conversation renders; sender name shows only on received messages,
  never on your own.
- Subtitle lists You + accepted (`MemberStatus.member`) members only —
  Invited members are excluded.
- Typing text and tapping send (or the keyboard's send action) appends a
  right-aligned bubble, clears the input, and scrolls to the new message.
- Back returns to Trip Detail.

### Polls (new)

- The bar-chart icon next to the message input opens a "New poll" sheet.
- Starts with 2 empty option fields; "Add option" adds more (up to 6, then
  the button disappears); each option beyond the first 2 has an "X" to
  remove it (never below 2 remaining).
- "Create poll" is a no-op (doesn't close the sheet) if the question is
  empty or fewer than 2 options have non-empty text — blank options should
  just be dropped, not block creation, if at least 2 have text.
- On success: sheet closes, a poll card appears as a message bubble (from
  "You", right-aligned like a sent text message) showing the question and
  every non-empty option, starting at 0 votes each ("No votes yet").
- Tapping an option: fills its progress bar proportionally, shows the
  correct percentage, marks it with a filled checkmark, and updates the
  "N votes" footer. Tapping a *different* option moves your vote (the
  previously-selected option's bar/checkmark clears) — you can never be
  counted for two options at once. Tapping your *current* selection again
  doesn't remove your vote (single-choice, not toggle-off).
- Poll state persists across scrolling away and back (it's held in the
  screen's message list, same as regular chat messages) but — like the
  rest of chat — is NOT synced across devices/sessions; only expect it to
  persist for the lifetime of that ChatScreen instance.

## Trips tab (`TripsTab`)

- Upcoming section: one hero card per upcoming `Trip`, correct cover art per
  trip (they should look visibly different, not all the same palette),
  avatar overlap + overflow badge correct per trip.
- Tapping an Upcoming card's hero image opens Trip Detail: for the trip
  matching Home's current `activeGroup`-equivalent (Lake Tahoe Crew) it
  should show the same data as Home's card; for a *different* trip it
  should construct fresh detail data without crashing or showing
  stale/wrong info.
- **New**: below each Upcoming hero card, a separate "Details ▾" row
  toggles inline expansion (Members + Things to do nearby — see below).
  Tapping this row must NOT also navigate to Trip Detail (separate tap
  target from the hero card above it, same tap-isolation principle as
  Play vs. expand on Past cards) — and tapping the hero card itself must
  NOT toggle this expansion.
- Past section: one bordered card per past `Trip`.
- Play button opens the full-screen photo slideshow — confirm tapping Play
  does **not** also toggle the card's inline expansion (tap-target
  isolation/`stopPropagation` check).
- Tapping the card body (not Play) toggles inline expansion: **Trip
  Memories** (new), Members, Photos, Activity — in that order.
- **Trip Memories (new)**: cover art (same image/illustration as the
  card's own cover), "TRIP MEMORIES" label, destination + date line
  overlaid on it. Below that, two stat tiles: "Total spent" (sum of every
  charge for that trip — cross-check against `sample_charges.dart`'s `t3`
  entries for the seeded past trip, should be a real non-zero dollar
  figure, not $0.00) and "Photos" (matches the photo count shown in the
  Photos section below it exactly, including after adding a new photo —
  expand/collapse and re-expand to confirm it updates, doesn't just
  reflect the count from when the card first rendered).
- Members list shows You + every trip member.
- Photos grid: existing photos render as square thumbnails (see the
  screenshot-tool caveat above); the "+" tile opens a Library/Camera choice
  sheet and a real picked photo is added to the grid immediately.
- Tapping an existing photo thumbnail opens the slideshow starting at that
  photo's index (not always index 0).
- Slideshow Previous/Next wrap around correctly; both are disabled (not
  crashing) when there's only 1 photo; the "N / total" counter is correct.

### Things to do nearby (new — shared across the group via Supabase)

Shown in the expanded section of BOTH Upcoming and Past trip cards
(Upcoming via the new "Details" toggle, Past below Activity). Backed by
Foursquare's Places API — silently shows "Nearby search isn't set up
yet" if `lib/config/foursquare_config.dart`'s key is still empty; not a
bug if so, just means the key hasn't been added yet.

- **Upcoming trips only**: a "Browse" button opens a full-screen picker.
  It geocodes the trip's destination and searches within 10 miles —
  confirm it shows a loading state, then either a checkbox list of
  varied venues (not all the same category) or a clear error (no
  network, no results, geocode failed) without crashing. Checking items
  and tapping "Add N selected" should save them and return to the trip
  card with the new items appearing in its list. **Past trips do NOT
  show a Browse button** — view/remove only, confirm it's genuinely
  absent, not just disabled.
- Each saved place shows name, category, who added it, a Navigate icon,
  and a Remove (X) icon.
- **Navigate**: should hand off to the device's Maps app with directions
  to that place. Can't verify the handoff completes on Simulator (no
  real Maps app to actually route in), but confirm tapping it doesn't
  crash or hang.
- **Remove**: tapping X removes it immediately (no confirmation dialog
  by design, unlike deleting an expense) — confirm it's gone from both
  the UI and stays gone after collapsing and re-expanding the card (i.e.
  actually removed from the backend, not just hidden locally).
- **Shared across the group**: this is real Supabase-backed shared data
  (`trip_places` table), not local-only like Photos — if you have a way
  to check the Supabase dashboard or a second account, a place added by
  one account should be visible to another. Otherwise, at minimum
  confirm a saved place survives a full app restart (proves it's not
  just in-memory).
- Adding the SAME place twice (browse again, select something already
  saved) should be a graceful no-op, not a duplicate entry or a crash —
  the picker should show already-saved items as pre-checked/disabled
  rather than letting you re-select them.

## Balances tab (`BalancesTab`)

- Overall balance card: net amount is the correct cross-trip,
  payment-adjusted aggregate — spot-check the arithmetic against the seeded
  charges in `sample_charges.dart` (worth hardcoding an expected value in an
  automated test rather than re-deriving it by hand each run).
- Upcoming/Past filter toggle switches the visible trip list.
- Each trip card's balance is per-trip only (not payment-adjusted, matches
  the design's intentional scoping) and its label/color match the sign
  (owe = red, owed = green, zero = "Settled up" neutral).
- "Details"/"Hide" toggles only the tapped card; other cards' expansion
  state is unaffected.
- "Who owes whom" lists correct per-member amounts for that trip only.
- "Activity" lists every charge for the trip with the right category icon,
  payer phrasing ("You paid" vs "`<name>` paid"), date, and split-with text.
  A charge added via a scanned receipt shows a small square thumbnail on
  the right; tapping it opens a full-screen (pinch-to-zoom) viewer with a
  back button. Charges added without scanning show no thumbnail at all —
  not a broken-image placeholder.
- "Add expense": rejects empty description, non-numeric/zero/negative
  amount, and an empty split selection; on success the sheet closes and both
  the trip's balance and the Balances tab's overall balance update
  immediately, no navigation needed to see the new number.
- **Cancel button (new)**: an X in the top-right of the Add Expense sheet
  closes it without adding anything, regardless of what's been typed into
  any field — no dummy expense should appear in Activity, no balance
  change. (Tapping outside the sheet should also still dismiss it, same
  as before — that was never broken, just not the only way out anymore.)
- **Delete an expense (new)**: swiping a charge left in the Activity list
  reveals a red delete affordance; releasing it (past the dismiss
  threshold) prompts "Delete this expense?" with Cancel/Delete — Cancel
  leaves the charge untouched (including if you swipe again after
  cancelling, it should still work normally, not be stuck half-swiped);
  Delete removes it immediately, and both the trip's balance and the
  Balances tab's overall balance update right away, matching what a
  manual recompute would give (spot-check against `sample_charges.dart`
  minus the deleted entry).
- **Scan receipt (new)**: the "Scan" button at the top of the sheet opens
  the same Library/Camera choice sheet as the Trips tab's photo picker.
  After picking a photo: a small thumbnail replaces the receipt icon, the
  button becomes disabled with a spinner while "Reading receipt…" shows,
  then either the Amount field gets prefilled with a number (if the photo
  had a recognizable total) or a snackbar says it couldn't read one — no
  crash either way, and the rest of the form (description, category,
  payer, split) stays fully editable regardless of what happened.
  "Retake" (shown once a receipt's attached) reopens the same picker and
  replaces the thumbnail/re-scans. Submitting without ever scanning a
  receipt still works exactly as before (receipt is optional).
- "Settle Now" opens Balances-by-person.
- Balances-by-person: correct net per person aggregated across *all* trips;
  "Settle up" appears only for people you owe, never for people who owe you.
- Tapping a person row toggles a per-trip breakdown (and a "Payment sent"
  line once a payment exists for them).
- "Settle up" form: prefilled to the exact amount owed; a smaller entered
  amount is accepted as-is; an amount larger than what's owed is clamped
  down to the owed amount, never overpaid; confirming reduces that person's
  balance, flips their row to "Settled up" once fully paid, and the
  Balances tab's overall card reflects the change after returning to it.

## Group creation (`CreateGroupFlow`)

Reached via Home's "Create a group" button. 3 steps, back-button behavior:
tapping back on step 1 pops the whole flow (returns to Home); on steps 2/3
it goes to the previous step without losing entered data.

- **Step 1 (Basics)**: header shows "1 / 3". 4 cover swatches (Mountain
  Lake / Beach / Desert / Forest), each a distinct icon+color; tapping one
  selects it (ring border) and deselects the others — exactly one selected
  at a time. Trip name and Notes fields accept input. Start/End date
  fields open a native date picker on tap and display the picked date
  (format "Sat, Sep 6"); End date is optional.
- **Step 2 (Destination)**: has a new "Generate cover" card below the
  address fields. Tapping "Generate" with no city/trip name entered shows
  an inline error instead of crashing. On iOS Simulator, generation will
  report unavailable (Image Playground needs a real Apple-Intelligence-
  capable device) — expect a "This device can't generate covers" message,
  not a crash; this is expected in Simulator, not a bug. On Android it
  needs an Unsplash API key that isn't configured yet (see `PROGRESS.md`)
  — expect "Cover photos aren't set up on Android yet", also expected.
  Either way, the 4 preset swatches in Step 1 still work as the fallback
  cover, and picking one after a (hypothetical) successful generation
  should clear the generated cover per the UI's own wording.

  Separately, the General area/Exact address toggle — General area is
  selected by default. Switching to
  Exact address reveals Street address + Apt/Unit fields above City;
  switching back to General area hides them again (and their entered
  values, if any, shouldn't cause a crash when hidden then re-shown).
  City/State fields always visible; ZIP is optional in both modes.
- **Step 3 (Invite)**: header shows "3 / 3". Invite code display derives
  from the trip name typed in step 1 (falls back to "TRIP-482" if no name
  was entered) — check it updates if you go back and change the name.
  "Copy" copies the code to the clipboard and shows "Copied!" briefly,
  then reverts to "Copy". Adding a phone/email via the text field creates
  a removable chip below it (tap the chip's X to remove); the input clears
  after adding. All 5 sample contacts are listed with checkboxes;
  selecting/deselecting them doesn't affect the manual-invite chips or
  vice versa. "Create group" is always enabled (no required fields on
  this step).
- **On "Create group"**: navigates to that new trip's Trip Detail screen
  (not back to Home) — the back button from there should return to Home,
  not back into the wizard. The new trip should immediately be visible on:
  Home's hero card (see note in Home section above), Trips tab's Upcoming
  list, and Balances tab's Upcoming list (with $0 balance / "Settled up"
  and an empty Activity list, since it starts with no charges — "Add
  expense" should still work against it like any other trip).
- **Edge cases worth checking**: creating a group with an empty trip name
  (should fall back to "My Trip"), with no destination fields filled
  (should show "Destination TBD"), with no start date (should show "Date
  TBD" and not crash computing days-left), and with zero invitees selected
  (should create successfully with just you as a member, "1 total" on its
  Trip Detail).

## Dark mode (new) — OS-driven, no in-app toggle

`AppColors` moved from static constants to a `ThemeExtension`
(`light`/`dark` palettes), `MaterialApp` now sets `themeMode:
ThemeMode.system` — the app should follow the Simulator's Settings >
Developer > Dark Appearance (or `xcrun simctl ui <udid> appearance
dark`), with no manual toggle anywhere in the app. This touched nearly
every screen (26 files) since every hardcoded `AppColors.xxx` color
reference had to move to a runtime `context.colors.xxx` lookup — self-
verified via screenshot on the sign-in screen only (light mode
unchanged, dark mode renders with a dark background, light text,
visible borders/accent, no unstyled elements), so the main thing this
QA pass should catch is anything that slipped through the mechanical
sweep and still shows a stale/hardcoded color, a white flash, or
unreadable low-contrast text in dark mode specifically.

- Toggle the Simulator to dark appearance, then walk every major
  screen (Onboarding/sign-in, Home, Trip Detail, Chat, Trips tab
  expanded card, Balances tab + Add Expense sheet, Group creation
  flow) and confirm: background/surface/text colors actually flip (not
  stuck on the light palette), no white/light-colored boxes or icons
  left over on a dark background (or vice versa in light mode), text
  stays legible (no light-gray-on-white or dark-gray-on-black),
  status/semantic colors (money owed vs owed-to, success/pending
  badges in Balances and Activity, chat bubble colors) are still
  visually distinguishable in both modes.
- Toggle back to light mode and re-check the same screens — should
  look exactly as before this change (this was the default palette
  pre-refactor, just now sourced through the `ThemeExtension` instead
  of static constants; any visual diff here is a regression).
- Switch appearance while the app is already running (not just cold
  launch) — Flutter's `ThemeMode.system` should repaint live without
  needing a restart; a screen stuck on the old palette after a live
  switch is a bug.
- No `invalid_constant` or similar analyzer/build errors (already
  confirmed clean via `flutter analyze lib` before this checklist
  entry was written, but worth a fresh check if this file changes
  again).

## Cross-cutting

- **Shared state**: `AppData` (in `lib/state/app_data.dart`) is the one
  source of truth for trips/charges/payments now, provided app-wide via
  `AppDataScope` above `MaterialApp` in `main.dart`. If a value changes on
  one screen (e.g. a payment recorded on Balances-by-person) but doesn't
  seem to reflect on another screen after navigating back to it, that's
  worth flagging — it likely means somewhere is still reading stale local
  state instead of `AppDataScope.of(context)`.

- No uncaught exceptions/red screens in the console across the full flow:
  cold launch → onboarding → Home → Trip Detail → Chat → back → Trips tab →
  expand a past trip → Balances tab → Add Expense → Settle Now → Settle Up →
  back.
- No `RenderFlex overflow` or similar layout warnings on any screen at
  standard simulator sizes.
- Text input fields (Add Expense amount/description, Home Address fields,
  Chat input) aren't obscured by the keyboard when focused.
