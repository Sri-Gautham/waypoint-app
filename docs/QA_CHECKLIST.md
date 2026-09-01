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

Also seen recently: an OS-level "Apple Account Verification" system dialog
(tied to the Mac's own signed-in Apple ID, nothing to do with Waypoint)
covering the entire Simulator screen, persistent across relaunches/rebuilds.
If you hit this, widget-tree inspection (as used for the dark mode QA pass)
is the reliable fallback over screenshots.

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

**Trips are now real and backend-persisted (see "Trip membership"
below) — the 3 hardcoded demo trips (Lake Tahoe Crew, Weekend at the
Cabin, Napa Wine Tour) are gone entirely.** A fresh/new account has
zero trips until it actually creates or joins one — this is expected,
not a bug, and is the main new thing to verify here.

- Cold launch with no trips yet: instead of a hero card, a "No trips
  yet" card with "Create a group or join one with a code to get
  started" — confirm this shows instead of a blank space or a crash,
  and that it's genuinely gone (replaced by the hero card) as soon as
  you have a real trip.
- A brief loading spinner should show where the hero card goes while
  `AppData` fetches trips on startup — shouldn't flash empty-then-full
  in a jarring way, and shouldn't hang indefinitely on a slow/offline
  connection (confirm it eventually resolves to either a real trip or
  the empty state, not stuck spinning forever).
- Greeting shows the right first name and initials avatar.
- Once you have at least one trip: "Next trip" hero card — landscape
  art renders, correct trip name/destination/date, avatar stack caps
  at 2 visible + a "+N" overflow badge matching the actual remaining
  member count (this will just be you until someone else joins via a
  real code — see below).
- Tapping the hero card opens Trip Detail for that trip.
- "Create a group" opens the real `CreateGroupFlow` wizard (see its
  section below, substantially rewritten). "Join with code" is now
  **enabled** (previously permanently disabled) — tapping it opens a
  dialog prompting for a 6-character code; see "Trip membership" below
  for what to verify there.
- Recent activity list still renders sample/placeholder items —
  unrelated to real trips, not backed by anything yet, unchanged from
  before.

## Trip membership (new) — join codes, real roster, RLS

The core of this batch of work: trips and their membership are now a
real Supabase backend (`trips`/`trip_members` tables + `create_trip`/
`redeem_trip_join_code`/`leave_trip` RPCs) instead of hardcoded mock
data. I could not drive the actual create → get code → redeem code
round trip myself — no real signed-in Simulator session has been
reachable via automation all session — so this needs a genuine
first-look pass, ideally with **two real signed-in accounts** if you
can get them, since several of the most important things to verify
only show up with a second account involved.

- **Create → join round trip (needs 2 accounts)**: Account A creates a
  trip, opens its "Invite" dialog (next to the member count on Trip
  Detail — only visible to the admin), copies the code. Account B taps
  "Join with code" on Home, enters it, and should land on that trip's
  Detail screen with both accounts now showing in the Members list —
  A as Admin, B as Member. Re-fetching (e.g. force-quit and relaunch)
  on either account should show the same up-to-date roster for both.
- **Invalid/garbage code**: entering a code that doesn't match any
  trip shows a clear inline/snackbar error ("That code didn't work"),
  not a crash or a silent no-op.
- **Re-joining a trip you're already in**: entering a code for a trip
  you already belong to should be a harmless no-op (still lands you on
  that trip, doesn't create a duplicate membership row or error out) —
  this is the `on conflict do nothing` behavior in
  `redeem_trip_join_code`, worth confirming it actually holds.
- **Throttling**: entering wrong codes rapidly more than ~10 times in
  a minute should eventually surface a "too many attempts" style error
  instead of continuing to just say "invalid code" — a lower-priority
  check, but worth trying if you have time, since it's a real security
  mechanism (brute-force protection on the join code) and easy to miss
  if it's silently not firing.
- **Isolation (needs a 3rd, uninvolved account or a Supabase dashboard
  spot-check)**: an account that was never invited to a trip and never
  redeemed its code should NOT be able to see that trip at all —
  neither in its own Trips list nor by any other means. This is the
  main security property this whole feature exists to enforce; if
  you have Supabase dashboard access, cross-checking
  `select * from trips` / `trip_members` against what each test
  account's app actually shows is a good substitute if a 3rd real
  account isn't available.
- **Leaving a trip**: not yet wired up to any UI button (the
  `leave_trip` RPC exists but there's no "Leave trip" action in the
  app yet in this phase) — nothing to check here beyond confirming its
  absence isn't accidentally causing a crash somewhere; it's simply
  not built yet, by design.

## Trip Detail (`TripDetailScreen`)

- Hero image shows the days-left badge (top-right) and destination + date
  (bottom-left) — values match the `Trip` passed in. The "ETA —" line
  underneath is a decorative placeholder (no real data source, always
  "—" — not a bug), separate from the real per-user ETA-sharing section
  further down.
- "Start" button shows a snackbar placeholder, no crash (real navigation
  deep-link is a future task).
- Weather card always shows "—°F" / "Forecast pending" — decorative
  placeholder, no real weather source, same as the ETA line above.
- **Members section (rewritten — real data now)**: "You" row shows your
  actual name and initials (resolved via your profile, not a hardcoded
  "You (Admin)"/"ME") with an Admin or Member badge matching your real
  role on that trip; every other real member shows their actual name
  and a Member (or Admin, if they are one) badge. No more "Invited"
  badge state (removed — a member row only ever exists once someone
  has actually joined) and no more "X mi from home" distance line
  under each name (removed — was always mock data, never backed by
  anything real). The member count next to the "Members" heading
  should read `N total` where N = your real trip's member count.
- **"Invite" link (new, admin-only)**: appears next to the member count
  only when your role on that trip is Admin — not for a Member. Tapping
  it opens a dialog showing the trip's real join code with a "Copy"
  button; confirm the copied value actually matches what's on screen
  (paste it somewhere to check) and that "Done" closes the dialog
  cleanly.
- Chat icon opens `ChatScreen` for the same trip.

### Today's ETAs (only shows on trip day)

There are no more seeded sample trips to test this against — **create a
new trip via the group wizard with today's date** (Home > Create a
group > pick today in the date picker) to test it; this is now the
only way to get any trip at all, seeded or otherwise. It should appear
between the weather/Start row and Members, and NOT appear at all on
any trip whose date isn't today or on past trips.

- Tapping "Share my ETA" triggers the OS location-permission prompt the
  first time (can't be driven by `integration_test` — check it appears
  and that denying it surfaces "Location access is off..." rather than
  hanging or crashing). Granting it (or pre-granting via Simulator's
  Settings app, or `xcrun simctl privacy <udid> grant location
  com.srigautham.waypoint` beforehand) should let the flow complete.
- On success: the button relabels to "Update my ETA (N min)", **your
  real name** (not the literal string "You" — this now resolves your
  actual profile name, same fix as the Members section above) in the
  list below shows that same value + "just now", and every other
  listed member shows "Not shared yet" unless a second real account
  has also shared into the same trip.
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

**No more seeded trips** — same as Home, this tab shows a genuine "No
trips yet" message (not a hero card) until the account has actually
created or joined at least one real trip, and a loading spinner
briefly while `AppData` fetches on startup. Confirm both states render
correctly rather than assuming trips are always present, which every
older note below was written against.

- Upcoming section: one hero card per upcoming `Trip`, correct cover art per
  trip (they should look visibly different, not all the same palette),
  avatar overlap + overflow badge correct per trip.
- Tapping an Upcoming card's hero image opens Trip Detail: for the trip
  matching Home's current next-trip hero card, it should show the same
  data as Home's card; for a *different* trip it should construct fresh
  detail data without crashing or showing stale/wrong info.
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
  charge for that trip — there's no more seeded past trip with mock
  charges to check this against; create one with yesterday as its start
  date (see the Cross-cutting note on this below) to get a real Past
  trip, add a few expenses to it, and confirm the tile matches, not
  $0.00 despite real entries existing) and "Photos" (matches the photo
  count shown in the
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

**`sample_charges.dart` (previously seeded mock charges for the 3
hardcoded demo trips) was deleted** along with those trips — it was
keyed entirely to trip ids that no longer exist. Every real trip now
starts with genuinely zero charges (`AppData.chargesByTrip` starts
empty), so there's no pre-seeded arithmetic to spot-check against
anymore — add a few expenses manually via "Add expense" first, then
verify the totals below against what you just entered by hand.

- Overall balance card: net amount is the correct cross-trip,
  payment-adjusted aggregate.
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
  manual recompute would give against whatever expenses you'd entered.
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

## Group creation (`CreateGroupFlow`) — now creates a real, backend-persisted trip

**Rewritten along with trip membership becoming real (see the new
"Trip membership" section below and `PROGRESS.md`) — this replaces the
previous checklist entry for this flow, don't assume the old
invite-code/contact-picker behavior described in prior checklist
revisions still applies. It doesn't; that UI was removed.**

Reached via Home's "Create a group" button. 3 steps, back-button behavior:
tapping back on step 1 pops the whole flow (returns to Home); on steps 2/3
it goes to the previous step without losing entered data.

- **Step 1 (Basics)**: unchanged from before — header "1 / 3", 4 cover
  swatches (Mountain Lake / Beach / Desert / Forest) with exclusive
  selection, Trip name / Notes fields, Start/End date pickers (End
  optional).
- **Step 2 (Destination)**: unchanged — "Generate cover" card (expect
  "can't generate" on Simulator, not a crash), General area/Exact
  address toggle (Exact reveals Street/Apt above City), City/State
  always visible, ZIP optional both modes.
- **Step 3 — now "Review & create", not "Invite members"**: no invite
  code shown here anymore (there's nothing to show one for yet — the
  trip doesn't exist until you tap Create), no contact picker, no
  manual phone/email chips — all removed since they never did anything
  real. Instead: a review card showing the trip name, destination line,
  date range, and notes (if any) exactly as they'll be created. "Create
  group" shows a spinner while the request is in flight and is disabled
  during it (can't double-tap-create); on failure shows an inline error
  and stays on this step so you can retry, rather than losing your
  entered data.
- **On successful "Create group"**: navigates to the new trip's Trip
  Detail screen (not back to Home) — confirm you land there with the
  trip you just described, showing "1 total" member (just you, as
  Admin), and a real join code visible via the new "Invite" link next
  to the member count (see "Trip membership" section). Back from there
  returns to Home, not into the wizard. The new trip should appear on:
  Home's hero card, Trips tab's Upcoming list, and Balances tab's
  Upcoming list ($0 balance / "Settled up", empty Activity, "Add
  expense" still works against it).
- **Edge cases worth checking**: empty trip name falls back to "My
  Trip"; no destination fields filled shows "Destination TBD"; no start
  date shows "Date TBD" and doesn't crash computing days-left; a
  network failure on Create (e.g. airplane mode) shows the inline error
  rather than crashing or silently doing nothing.

## Stories (new) — self-only, 24h photos, first-look QA needed

Entry point is the top-right avatar on the Home tab (`HomeTab`). I could
not drive this myself this pass (same Simulator-blocking dialog as the
status line — see the gotcha note above), so this needs a genuine
first-look pass, not a regression check.

- **No active story**: avatar has no colored ring, no "+" badge. Tapping
  it opens the add-photo bottom sheet (Choose from library / Take a
  photo — same two options as the existing trip Photos flow).
- **Adding a story**: picking or taking a photo uploads it and should
  make the ring appear around the avatar shortly after (loading state
  while uploading — check nothing crashes if you background the app or
  tap away mid-upload).
- **Active story present**: ring appears around the avatar, plus a small
  "+" badge at its bottom-right corner. Tapping the avatar itself (not
  the badge) opens the full-screen viewer; tapping the "+" badge opens
  the add-photo flow directly without opening the viewer first.
- **Viewer**: progress-bar segments across the top (one per photo),
  auto-advancing roughly every 5 seconds; tapping the right half of the
  screen skips to the next segment immediately, tapping the left half
  goes back a segment (or restarts the first segment if already on it).
  Viewer closes automatically after the last segment finishes. Close
  (X) button in the top-right always works.
- **Deleting from the viewer**: trash icon shows a confirm dialog
  ("Delete this story?"); confirming removes just that photo and
  continues to the next one (or closes the viewer if it was the only
  one left); cancelling resumes playback where it left off (should not
  reset to the beginning of that segment).
- **Persistence**: added stories should survive a force-quit/relaunch
  (confirms it's actually a Supabase Storage upload + DB row, not just
  local state) — and should NOT be visible to a different signed-in
  account on the same device (RLS is strictly owner-only; this is
  worth a real cross-account spot-check if two test accounts are
  available).
- **24h expiry**: not practical to wait a full day out in a QA pass, but
  worth sanity-checking the logic isn't inverted — a story added "now"
  should show as active; if there's any way to backdate a test row's
  `created_at` via the Supabase dashboard to >24h ago, confirm it
  disappears from the avatar/viewer on next load (and gets cleaned up
  from Storage, not just hidden).
- No `RenderFlex overflow`/crash on any screen size when the ring or
  "+" badge is showing (the badge sits slightly outside the avatar's
  own bounds via `Positioned` with negative offsets — worth confirming
  it doesn't get clipped or overlap the greeting text on smaller
  simulator sizes).

## Profile status line (new) — self-only, not shown elsewhere yet

A persistent "About"-style line the user sets on their own profile
(`profiles.status_text`), edited from the Profile tab. Not yet shown
anywhere else in the app (Trip Detail's member rows are still
placeholder/mock data unrelated to the real signed-in profile — see
`PROGRESS.md` for why). I could not visually drive this myself this
pass (an unrelated system dialog blocked the Simulator screen), so
this needs a full first-look QA pass, not just a regression check.

- Profile tab: below the name, shows "Add a status" in italic when
  `status_text` is empty; tapping it (or the small pencil icon) opens
  a dialog with a text field pre-filled with the current status.
- Entering text and tapping Save: dialog closes, the Profile tab
  immediately shows the new text (not italic anymore), and it persists
  across app restart (i.e. actually wrote to Supabase, not just local
  state — check by force-quitting and relaunching signed in as the
  same account).
- Tapping Cancel (or dismissing without Save): no change, previous
  status (or "Add a status" if none) still shows.
- Clearing the text field to empty and saving: goes back to showing
  "Add a status", not an empty line.
- 60-character limit is enforced (the field should stop accepting
  input at 60, not silently truncate on save or error out).
- No crash if this is tapped rapidly / while a previous save is still
  in flight (there's a busy-state guard disabling the tap while
  saving — worth trying to double-tap quickly to confirm it holds).

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
  cold launch → onboarding → Home (now: **create a group first** — there's
  no seeded trip to walk through anymore) → Trip Detail → Chat → back →
  Trips tab → Balances tab → Add Expense → Settle Now → Settle Up → back.
  ("Expand a past trip" from the old version of this checklist is still
  reachable — the date picker in step 1 allows picking yesterday as the
  start date, which is enough to make a freshly-created trip show as
  Past immediately; use that to get a real past trip to test against
  rather than needing a Supabase dashboard backdate.)
- No `RenderFlex overflow` or similar layout warnings on any screen at
  standard simulator sizes.
- Text input fields (Add Expense amount/description, Home Address fields,
  Chat input) aren't obscured by the keyboard when focused.
