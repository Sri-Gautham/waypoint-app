# Waypoint — QA checklist

What to validate on a simulator build, by feature area. Update this file
whenever new screens/flows land; treat it as the source of truth for what
"done" means functionally, alongside `test_report.json`'s automated results.

Known tooling gotcha: `xcrun simctl io screenshot` has produced misleading
captures in this environment — a correctly-sized, fixed-size widget rendered
as a wildly stretched rectangle in the screenshot while the actual on-screen
content (confirmed via `simctl io recordVideo` + a QuickLook thumbnail) was
correct. If a screenshot shows a widget stretched/distorted in a way that
seems physically implausible given the code, cross-check with a video-frame
capture or the live simulator before filing it as a bug.

## Onboarding (`OnboardingFlow`)

- Create account: first/last name, email, phone accept input; "Continue"
  advances to Verify Email.
- Verify Email / Verify Phone (shared `VerifyCodeStep`): the 6 OTP boxes
  auto-advance focus as digits are typed; "Continue" is disabled until all 6
  digits are filled; back button returns to the previous step without losing
  entered data.
- Home Address: "Use current location" instantly fills street/city/state/zip;
  "Finish" advances to All Set.
- All Set: shows the entered first name (or "there" if blank); "Get started"
  navigates to the Home dashboard (`MainShell`) and the back stack is cleared
  (no way to swipe back into onboarding).

## Home tab (`HomeTab`)

- Greeting shows the right first name and initials avatar.
- "Next trip" hero card: landscape art renders (not blank/broken), correct
  trip name/destination/date, avatar stack caps at 2 visible + a "+N"
  overflow badge matching the actual remaining member count.
- Tapping the hero card opens Trip Detail for that trip.
- "Create a group" / "Join with code" are visibly disabled — confirm they
  don't crash or silently no-op with a stray console error.
- Recent activity list renders all sample items.

## Trip Detail (`TripDetailScreen`)

- Hero image shows the days-left badge (top-right) and destination + date +
  ETA (bottom-left) — values match the `Trip` passed in.
- "Start" button shows a snackbar placeholder, no crash (real navigation
  deep-link is a future task).
- Weather card shows the trip's temp/condition.
- Members section: admin (You) + every `TripMember`, each with the correct
  status badge (Admin/Member/Invited) and distance text.
- Chat icon opens `ChatScreen` for the same trip.

## Chat (`ChatScreen`)

- Seeded conversation renders; sender name shows only on received messages,
  never on your own.
- Subtitle lists You + accepted (`MemberStatus.member`) members only —
  Invited members are excluded.
- Typing text and tapping send (or the keyboard's send action) appends a
  right-aligned bubble, clears the input, and scrolls to the new message.
- Back returns to Trip Detail.

## Trips tab (`TripsTab`)

- Upcoming section: one hero card per upcoming `Trip`, correct cover art per
  trip (they should look visibly different, not all the same palette),
  avatar overlap + overflow badge correct per trip.
- Tapping an Upcoming card opens Trip Detail: for the trip matching Home's
  current `activeGroup`-equivalent (Lake Tahoe Crew) it should show the same
  data as Home's card; for a *different* trip it should construct fresh
  detail data without crashing or showing stale/wrong info.
- Past section: one bordered card per past `Trip`.
- Play button opens the full-screen photo slideshow — confirm tapping Play
  does **not** also toggle the card's inline expansion (tap-target
  isolation/`stopPropagation` check).
- Tapping the card body (not Play) toggles inline expansion: Members,
  Photos, Activity.
- Members list shows You + every trip member.
- Photos grid: existing photos render as square thumbnails (see the
  screenshot-tool caveat above); the "+" tile opens a Library/Camera choice
  sheet and a real picked photo is added to the grid immediately.
- Tapping an existing photo thumbnail opens the slideshow starting at that
  photo's index (not always index 0).
- Slideshow Previous/Next wrap around correctly; both are disabled (not
  crashing) when there's only 1 photo; the "N / total" counter is correct.

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
- "Add expense": rejects empty description, non-numeric/zero/negative
  amount, and an empty split selection; on success the sheet closes and both
  the trip's balance and the Balances tab's overall balance update
  immediately, no navigation needed to see the new number.
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

## Cross-cutting

- No uncaught exceptions/red screens in the console across the full flow:
  cold launch → onboarding → Home → Trip Detail → Chat → back → Trips tab →
  expand a past trip → Balances tab → Add Expense → Settle Now → Settle Up →
  back.
- No `RenderFlex overflow` or similar layout warnings on any screen at
  standard simulator sizes.
- Text input fields (Add Expense amount/description, Home Address fields,
  Chat input) aren't obscured by the keyboard when focused.
