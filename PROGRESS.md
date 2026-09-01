# Waypoint — Progress Log

Living status file for this session's work. Review this whenever context is
unclear (e.g. after a compaction/restart) before assuming project state.

Repo: https://github.com/Sri-Gautham/waypoint-app (private)
Local path: `/Users/srigautham/Documents/My Projects/Personal Projects/travel-companion-app`

## New feature: Real trip membership (Phase 1) — 1 hardening gap + 2 client bugs found and fixed, back with QA

Follow-up to the status line/stories work, which both had to be scoped
to self-only because trip membership was entirely mock. User asked to
build real membership. This ballooned during scoping into something
much bigger (email invites with auto-join-after-install, App Store
Connect + TestFlight, Google Play Console, Branch.io-style deferred
deep linking) — user chose to sequence this as **Phase 1: real
membership + invite-by-code only, no external dependencies**, with
Phase 2 (stores + deep linking + email invites) scoped separately
later. Full plan is at the (session-local) plan file used to get
approval; this entry documents what actually got built.

**Decisions locked in during scoping**: invite-by-code only in this
phase (no email sending); Charges/Payments migration to real member
ids explicitly deferred (they still reference members by raw name
string — a real but separate follow-up); the 3 hardcoded demo trips
(`Trip.all`) removed entirely, not kept as a local demo alongside real
ones — a fresh account now sees a genuine empty state.

**Database** (all applied + verified live via Supabase MCP, not just
written and assumed correct):
- New `trips` table (name, notes, start/end date, destination fields,
  `cover_preset`, a real unique `join_code`, `created_by`) and
  `trip_members` (trip_id, user_id, role admin/member, joined_at).
- Security-definer helper functions `is_trip_member(trip_id)` /
  `is_trip_admin(trip_id)` avoid the classic RLS-self-reference-
  recursion problem on `trip_members`' own SELECT policy — deliberately
  take no `user_id` parameter (hardcode `auth.uid()` internally)
  after a Plan-agent security review caught that a parameterized
  version would itself be a callable RPC letting anyone probe "is user
  Y on trip X" for an arbitrary pair.
- `trip_members` has **no direct insert/update/delete policy for
  clients at all** — Postgres default-denies with RLS on and no
  matching policy, so every write goes through three RPCs instead:
  `create_trip` (creates the trip + inserts the caller as admin,
  atomically, with a join-code collision-retry loop), 
  `redeem_trip_join_code` (case-insensitive lookup, idempotent
  re-join via `on conflict do nothing`, and a brute-force throttle via
  a small `join_attempts` table — max 10 attempts/user/minute, another
  Plan-review finding), and `leave_trip` (deletes your own row; if
  you're the last member the trip itself is deleted, cascading cleanup
  to `trip_places`/`trip_day_status`; if you're the last admin but not
  last member, auto-promotes the next member by join order).
- **Tightened `trip_places`/`trip_day_status`** in the same feature —
  both previously used deliberately loose "any signed-in user"
  policies as an explicit interim placeholder until membership existed
  for real. Verified both tables were empty (0 rows) before altering
  `trip_id` from `text` to a real `uuid` FK against `trips(id)`, then
  replaced ALL their policies (not just the ones that were `true`-
  qualified — the INSERT policies were already scoped to the acting
  user but not to trip membership, a second gap closed here) with
  `is_trip_member`-based checks. **Caught and fixed a real mistake
  mid-migration**: a first pass at dropping the old policies used
  guessed policy names that didn't match the real ones, so `DROP
  POLICY IF EXISTS` silently no-op'd and the loose policies were still
  live — caught by re-querying `pg_policies` immediately after instead
  of assuming the migration did what it said, fixed with the real
  names in a follow-up migration, verified clean afterward.
- `trip_members.user_id` points at `public.profiles(id)`, not
  `auth.users(id)` — needed so PostgREST's embedded-select
  (`trip_members(...profiles(first_name,last_name))`) can actually
  detect the join; `auth.users` isn't exposed to PostgREST at all.
  Safe 1:1 swap since every account gets a `profiles` row via the
  existing `handle_new_user` trigger.

**App code**:
- `lib/models/trip.dart` — `Trip`/`TripMember` rewritten around real
  data: `TripMember` gains `userId`, drops the mock `distance` field;
  `MemberStatus.invited` removed entirely (a `trip_members` row only
  ever exists once someone has actually redeemed a code — no
  pending/invited state in this phase); `status`/`daysLeft` become
  computed getters from a real `startDate` instead of stored fields;
  new `Trip.fromRow` factory parses a Supabase embedded-select row,
  splitting the roster into `myRole` (the signed-in user's own role)
  and `members` (everyone else — kept as "everyone but you" to match
  the convention chat/balances/trips-tab already assumed, avoiding a
  much bigger ripple). All 3 hardcoded demo trips removed. `weatherTemp`/
  `weatherCondition`/`etaLabel` stay as placeholder strings (no real
  weather source — explicit non-goal); AI-generated cover bytes are
  NOT persisted (`cover_preset` name is, actual generated image is
  only kept for the current in-memory session right after creation).
- `lib/services/trips_service.dart` (new) — `fetchMyTrips`,
  `createTrip`, `redeemJoinCode`, `leaveTrip`, all thin wrappers over
  the RPCs/embedded-select above.
- `lib/state/app_data.dart` — was fully synchronous, seeded from
  `Trip.all` (doc comment literally said "no backend yet"); now has a
  `loading` flag and an async `loadTrips()`, `nextTrip` is nullable
  (genuinely no trips is now a real, reachable state, not something
  that could never happen with mock data always present).
  `chargesByTrip`'s old seed data (`lib/data/sample_charges.dart`) was
  keyed entirely to the now-deleted mock trip ids — deleted as
  orphaned rather than left dead; `chargesByTrip` now starts empty.
- `lib/main.dart` — `_StartupGate` awaits `AppData.loadTrips()` after
  loading the profile (deliberately after that await, not before —
  `AppDataScope.of(context)` can't be called synchronously during
  `initState`).
- `lib/screens/group/create_group_flow.dart` /
  `steps/group_invite_step.dart` — "Create group" now calls the real
  `TripsService.createTrip` (async, with a loading/error state) instead
  of building a `Trip` purely in memory. The invite step lost its
  entire previous purpose (a fake, never-persisted "invite code", plus
  a contact-picker/manual-invitee UI that instantly fabricated fake
  `MemberStatus.invited` "members" who'd never actually joined
  anything — actively wrong under a real-membership model, not just
  outdated) and is now a lightweight review-before-create step; the
  real join code is surfaced afterward, from Trip Detail, once the
  trip genuinely exists. `sample_contacts.dart` deleted as orphaned
  (was only ever used by the removed contact picker).
  `GroupDraft.manualInvitees`/`selectedContactIds` removed (unused).
- `lib/screens/home/home_tab.dart` — the previously-dead "Join with
  code" button now works: a dialog prompts for a code, calls
  `AppData.joinTripWithCode`, navigates into the trip on success. Added
  a loading state and a genuine "No trips yet" empty state for
  `AppData.nextTrip` now being nullable.
- `lib/screens/trips/trips_tab.dart` — added the same loading/empty
  handling; the existing member-rendering code needed no changes since
  `Trip.members`' shape/convention was deliberately preserved.
- `lib/screens/trip/trip_detail_screen.dart` — the "You (Admin)" row
  was hardcoded and the screen didn't even take a current-user param;
  now resolves the real signed-in user's name/initials via
  `AuthService.instance.loadProfile()` (matching the exact pattern
  `_shareMyEta` in this same file already used, rather than threading a
  new required param through every screen that constructs this one).
  Added an "Invite" action (admin-only) opening a dialog with the
  trip's real join code + copy button. `_MemberRow` dropped `distance`
  and the `invited` badge case. Incidental correctness fix while
  already touching "who is the current user" in this file: `_EtaSection`
  previously hardcoded the literal string `'You'` as the self row's
  name in its ETA list — since real ETA shares are written under your
  actual profile name (see `_shareMyEta`), that self row would never
  match after actually sharing an ETA with a real name set, silently
  showing "Not shared yet" forever. Now passed the real resolved name.
- `lib/screens/trip/chat_screen.dart` — dropped a
  `.where((m) => m.status == MemberStatus.member)` filter that existed
  to exclude fake invited-but-not-joined members; no longer needed
  since every member row is real now.

**Verification status**: `flutter analyze lib` clean throughout (fixed
2 `use_build_context_synchronously` lints along the way — both genuine
async-gap `BuildContext` uses after a `showDialog`/`await`, fixed with
`mounted` checks, not suppressed). Full arm64 build succeeds, app
installs and launches without crashing. Went further than the usual
build-and-launch check given the stakes here (real RLS, real RPCs, a
full model rewrite): used the established "temporarily render a screen
directly from `main()`" technique to visually confirm, with fake data,
that (1) `TripDetailScreen`'s new Members section renders the real
"You" row with correct Admin badge, other members with correct Member
badges, the right total count, and the admin-only "Invite" link, all
without overflow; (2) Home's new empty state ("No trips yet" +
enabled "Create a group"/"Join with code" buttons, both previously
one of them dead) renders correctly; (3) Trips tab's empty-state
message renders correctly. Reverted the debug harness cleanly each
time (`git diff` confirmed no leftover diff in `main.dart` beyond the
real `_StartupGate` change).

**What's NOT verified and needs a real signed-in session** (standing
constraint all session — no live session reachable via automation by
me or QA so far): the actual `create_trip` → real join code →
`redeem_trip_join_code` round trip end-to-end between two real
accounts; that a third, uninvolved account genuinely cannot see a
trip it's not a member of; that the join-code throttle actually
triggers after 10 attempts; that `leave_trip`'s last-admin-promotion
and last-member-deletes-the-trip paths behave as designed. Schema/RLS
were verified directly via Supabase MCP (`list_tables`, `pg_policies`)
the same way `trip_places`/`profiles` were earlier this session, which
is a real but partial substitute — it confirms the policies exist and
read correctly, not that the RPCs behave correctly under real
concurrent use.

**QA pass on `0daafd5` — deep audit given the stakes, 1 hardening gap
+ 2 client-side bugs found, all fixed.** QA matched the scope of the
review to how security-sensitive this feature is: full schema/RLS/RPC
audit via Supabase MCP, including **empirical anonymous-HTTP probing**
(real `curl` calls with the anon key, no session) rather than just
reading policy text. Confirmed correct, matching this doc exactly: the
`trip_members` no-direct-write-policy design, the parameterless
`is_trip_member`/`is_trip_admin` functions, that the old loose
`trip_places`/`trip_day_status` policies are actually gone (not just
superseded), the `join_code` unique index blocking a crafted-collision
insert, and all 3 RPCs' `SECURITY DEFINER` + pinned `search_path`.

**Hardening gap found**: all 5 new functions were `EXECUTE`-granted to
`anon`, not just `authenticated` — Supabase grants this by default on
new `public`-schema functions, not something the migrations had
explicitly addressed. QA confirmed empirically this wasn't currently
exploitable (`is_trip_member` returns `false` harmlessly for a null
`auth.uid()`; `create_trip`/`redeem_trip_join_code` both fail on a
`NOT NULL` violation before anything is written) — but it's protection
by accident (a constraint happening to catch it), not by design, and
the `redeem_trip_join_code` failure path leaked the `join_attempts`
table/column name in its raw Postgres error text back to an
unauthenticated caller. **Fixed**: `REVOKE EXECUTE ... FROM anon`
explicitly on all 5 functions (a first attempt revoking only from
`PUBLIC` didn't work — confirmed via `information_schema.routine_
privileges` that `anon` still had it, since Supabase grants directly to
`anon`, not merely via `PUBLIC` inheritance; fixed with an explicit
per-role revoke and reverified `anon` is gone from every row). This
also closes the `join_attempts` error-text leak for free, since `anon`
can no longer call the function at all.

Also noted, not changed: the join code is 6 *hex* characters
(`upper(substr(md5(...),1,6))`), i.e. ~16.7M possible codes, smaller
than "6-character code" might suggest at a glance. Left as-is — at the
existing 10-attempts/minute throttle, brute-forcing one account's
budget through that space would take on the order of thousands of
years, so the actual entropy isn't the binding constraint here.

**Client-side bugs found (both from code-reading — same standing
constraint on dynamic reproduction as everything else)**:
1. `AppData.joinTripWithCode` unconditionally inserted into `trips` and
   reset `chargesByTrip[trip.id] = []` whenever a redeem call returned
   a trip — but `redeem_trip_join_code` is deliberately idempotent
   server-side (re-joining a trip you're already in is a harmless
   no-op that still returns the trip id). So re-joining would duplicate
   the trip in the local list (a real duplicate card in Trips tab) and
   silently wipe any local-only charges already held for it. **Fixed**:
   guard the insert/reset behind `!trips.any((t) => t.id == trip.id)`.
2. Throttle and invalid-code failures were indistinguishable to the
   user — `TripsService.redeemJoinCode` caught every failure into a
   bare `null`, and `HomeTab` showed exactly one hardcoded message
   either way, contradicting this doc's/the checklist's own claim that
   throttling should show a distinct message. **Fixed**: replaced the
   nullable return with a `JoinCodeResult`/`JoinCodeFailureReason`
   result type (mirroring the existing `EtaResult`/`EtaUnavailableReason`
   pattern in `eta_service.dart`, not inventing a new convention) that
   distinguishes `invalidCode`/`throttled`/`notSignedIn`/`requestFailed`
   by matching the RPC's raised error text, propagated through
   `AppData.joinTripWithCode` up to `HomeTab`, which now shows a
   distinct message per reason.

`flutter analyze lib` clean, arm64 build succeeds, app launches
without crashing. Sent back to QA to confirm both the grant fix and
the two client-side fixes.

## New feature: Stories (24h photos) — self-only, QA-verified, done

Third and last in the agreed build order (dark mode → status line →
stories). Originally scoped as "global, across all your trips" during
brainstorming, but that assumed real trip-membership data existed to
compute visibility from — the status-line work above found it doesn't
(`Trip.members` is hardcoded placeholder data, no real `user_id`).
Asked the user how to proceed; **decision: scope stories down to
self/local for now** — no cross-user visibility at all, same
retrenchment as the status line. Content is photos-only, no view
tracking, per the original brainstorming decisions (both still hold).

Asked one more scoping question before building: should stories persist
to Supabase (survive reinstall/new device) or be purely on-device like
trip Photos/receipts today? **User chose backend-persisted.**

**What's built**:
- New Supabase migration `create_stories_table_and_storage` — `stories`
  table (id, user_id, image_path, created_at) with **strictly
  owner-only RLS** (`auth.uid() = user_id` on SELECT/INSERT/DELETE, no
  UPDATE policy needed — stories are never edited, only added/removed).
  This is tighter than `trip_places`/`trip_day_status`'s interim
  looseness on purpose: there's no cross-user case to allow for here at
  all, unlike those tables which are loose only because trip membership
  isn't enforceable yet. Also created a private `stories` Storage
  bucket with `storage.objects` RLS scoped by matching the object
  path's first folder segment to `auth.uid()` — this is the app's
  first use of Supabase Storage (trip photos/receipts have always been
  local-`File`-only).
- `lib/models/story_item.dart` — id/imagePath/createdAt, with
  `isExpired` computed as `createdAt + 24h < now()` (no separate
  `expires_at` column — kept it to one source of truth).
- `lib/services/stories_service.dart` — `fetchMyStories()` (returns
  only active stories, opportunistically purges any expired rows/files
  it finds along the way — fire-and-forget, no scheduled cleanup job),
  `addStory()` (uploads to Storage then inserts the row),
  `deleteStory()`, `downloadImage()` (bytes via the authenticated
  client, not a public/signed URL — bucket is private, no need for one
  at this scale).
- `lib/screens/home/story_viewer_screen.dart` — full-screen,
  Instagram-style viewer: top progress-bar segments auto-advancing
  every 5s, tap-left/tap-right to go back/skip, a delete button (same
  `AlertDialog` confirm pattern as deleting an expense) that removes
  the current item and continues, close button. Image bytes are
  fetched lazily per segment (not all up front) and cached for the
  screen's lifetime.
- `lib/screens/home/home_tab.dart` — converted from `StatelessWidget`
  to `StatefulWidget` to hold story state locally (same pattern
  `TripsTab` already uses for its own local photo state, not lifted
  into `AppData` since stories are user-level, not trip-level). The
  existing top-right initials avatar now doubles as the story entry
  point: an accent-colored ring appears around it when an active story
  exists; tapping it opens the viewer if one exists, or the add-photo
  flow (reused the exact gallery/camera bottom-sheet pattern from
  `TripsTab._addPhoto`) if not. A small "+" badge on the avatar (only
  shown once a story is active) lets you add another photo without
  first opening the viewer.

**Verification status**: `flutter analyze lib` clean, full arm64
build succeeds, installed and launched without crashing. Could NOT
visually verify the actual add/view/delete flow — same blocker as the
status line work: the Simulator screen is being covered by an
unrelated OS-level "Apple Account Verification" dialog on every
launch attempt (confirmed persistent across multiple rebuilds, not a
one-off), and there's no Accessibility permission available to this
environment to dismiss it via automation. This needs a genuine
first-look QA pass — added a "Stories (new)" section to
`docs/QA_CHECKLIST.md`. Worth a real signed-in-session spot check of
the Storage bucket + RLS too, same open item as `trip_places`' still-
unverified live write/read/remove round trip.

**QA pass on `fa779b9` — one real bug found, since fixed; everything
else clean.** Schema/RLS confirmed correct via Supabase MCP (`stories`
strictly owner-only on SELECT/INSERT/DELETE, the `stories` Storage
bucket's objects policies scoped to the first path segment matching
`auth.uid()`, matching `addStory()`'s `<user_id>/<timestamp>.jpg`
convention — first use of Storage in this app went in cleanly). 24h
expiry math checked correct. Home tab's no-active-story entry point
(the only path testable without a real session) confirmed clean: no
ring, no "+" badge, tap opens the add-photo sheet, dismisses without
error.

**Bug**: `story_viewer_screen.dart`'s `_confirmDelete()` calls
`_controller.stop()` before the confirm dialog opens, and only ever
resumes it (`.forward()`) on Cancel or on a successful delete — a
*failed* delete (`if (!ok) return;`) left the method returning with
the controller still stopped and nothing left to resume it. QA
confirmed this dynamically (not just by reading): `deleteStory()`
against an unauthenticated client fails every time, which made the
failure path directly reproducible without a real session — opened
the viewer, let autoplay start, triggered a delete that failed,
then sampled the progress bar for 6+ seconds (more than a full 5s
segment) and it never moved. Not a rare edge case either — any
transient network hiccup during a real delete hits this same path,
since `deleteStory()` swallows exceptions and just returns `false`.
Manual tap-left/right still worked fine throughout (goes through
`_loadAndPlay`, which does resume the controller) — it was
specifically autoplay that got stuck, silently, until a manual tap.

**Fix**: resume the controller on the failure path too
(`_controller.forward()` before returning), same as the existing
Cancel branch. `flutter analyze lib` clean, arm64 build succeeds.

**Re-check on `58a8bf1` — confirmed fixed.** QA reran the same repro:
segment-0 progress went from stopped (0.0533, held during the dialog
and the failed delete) to 1.0 after the 6s wait instead of staying
frozen. `flutter analyze lib` still clean. **Stories is done.**

Still not verifiable by anyone via automation (standing constraints,
not new): the native photo-picker UI itself (same class of blocker as
Apple/Google sign-in), the active-story path end-to-end (ring, "+"
badge, playback of a real photo, restart-persistence — all need a
real signed-in session with a real photo added), and a cross-account
RLS spot-check (needs two real accounts). The static RLS policy read
is the best available substitute for that last one and it looks
correct.

## New feature: Persistent status line — QA-verified, done

Second in the agreed build order (dark mode → status line → stories).
User asked for a WhatsApp/Instagram-style personal status alongside
24h stories (stories not started yet — see below). This is the
persistent "About"-style line only, not stories.

**Real architectural finding surfaced mid-build**: went to wire the
status line into "wherever members appear" (Trip Detail's member
list, etc.) and found there is currently no real trip-membership
backend at all — `Trip.members` (`lib/models/trip.dart`) is a
hardcoded `static const` list of name/initials/status/distance
strings with no `user_id`, and `TripDetailScreen`'s own "You (Admin)"
row is likewise a hardcoded placeholder (`name: 'You (Admin)',
initials: 'ME'`), not wired to the real signed-in user's profile at
all — `TripDetailScreen` doesn't even take an `OnboardingData`
parameter. Confirmed `profiles`' live RLS is also strictly
owner-only (`auth.uid() = id` on SELECT/UPDATE/INSERT) — even if the
member data were real, nothing could read another user's status under
today's policies. **Scoped down accordingly**: this feature is
self-only for now — a real, backend-persisted status editable on your
own Profile tab. Displaying it on other members anywhere is not
buildable without first building real trip membership (a bigger,
separate piece of work) — flagging this now since it also directly
affects the stories feature's already-agreed "global, across shared
trips" visibility scoping, which assumed real trip co-membership data
that turns out not to exist yet.

**What's built**:
- New Supabase migration `add_status_text_to_profiles` — nullable
  `status_text text` column on `profiles`. No RLS change needed
  (existing owner-only policies already cover it).
- `AuthService.loadProfile`/new `setStatusText` — mirrors the existing
  `setFaceIdEnabled` pattern (dedicated single-field update rather than
  routing through the full `saveProfile` form-save call).
- `OnboardingData.statusText` — new field, empty by default.
- `ProfileTab`: an editable line under the user's name — "Add a
  status" (italic placeholder) when empty, the status text otherwise,
  small edit icon, tap opens an `AlertDialog` with a 60-char-limited
  `TextField` (same `AlertDialog` pattern already used for the delete-
  expense confirmation in `balances_tab.dart`).

**Verification status**: `flutter analyze lib` clean, full arm64 build
succeeds. Could NOT visually verify the edit flow this time — tried
the usual "temporarily render the screen directly from `main()`"
technique used earlier this session, but every screenshot attempt was
blocked by an unrelated OS-level "Apple Account Verification" system
dialog covering the whole Simulator screen (tied to the Mac's own
signed-in Apple ID, not to Waypoint), and this environment has no
Accessibility permission for UI automation to dismiss it — confirmed
via `osascript`/System Events returning zero windows for the
`Simulator` process. Reverted the temporary debug harness cleanly (no
diff left in `main.dart`).

**QA pass on `c6df126` — found a real, high-severity bug, since fixed.**
`_editStatus` called `controller.dispose()` synchronously right after
`await showDialog<String>(...)` resolved — a classic Flutter race:
`AlertDialog`'s exit transition can still be rendering a frame bound to
that `TextField`'s controller when the dispose runs, throwing "A
TextEditingController was used after being disposed." QA's frame-by-
frame instrumentation showed the Profile tab's widget count collapsing
from ~1500+ to 91 the frame after — the screen goes effectively blank
on every single Cancel/Save, not just a scary console line. Confirmed
via QA's isolated repro (`app/integration_test/profile_status_repro_test.dart`
in their worktree) that this is inherent to the pattern (manually-
created controller + dispose right after an awaited `showDialog`), not
a test-harness artifact — no other `showDialog` call in the app pairs
a controller with an immediate post-await dispose this way, so it's
new with this feature, not a pre-existing footgun elsewhere.

**Fix**: dropped the manual `controller.dispose()` call entirely. It's
a short-lived, one-shot controller with nothing referencing it once
`_editStatus` returns (the dialog route is gone, the local variable
goes out of scope) — leaving it for GC instead of an explicit dispose
is safe and sidesteps the race outright, rather than trying to
sequence the dispose after the exit transition finishes. Also added a
small spinner to the status row while `_statusBusy` is true (QA
flagged this as a minor inconsistency — the Face ID toggle on the same
screen already shows one, the status edit didn't). `flutter analyze
lib` clean, arm64 build succeeds. Sent back to QA to confirm the fix
and finish the rest of the checklist (60-char limit, whitespace-only
save reverting to placeholder, keyboard "done" submit) that the bug
had blocked.

**Re-check on `7a8b06f` — clean, full checklist passes.** QA reran the
same frame-by-frame repro (zero exceptions across 10 stepped frames,
widget count holds at 1346 through settle vs. the 91 it collapsed to
before) confirming the disposal race is actually gone, then ran the
full checklist clean in one pass: empty-state placeholder, dialog
prefill (both empty and re-opening after a save), Cancel discarding
typed text, Save persisting and rendering non-italic, the 60-char
limit enforced on entry, a whitespace-only save trimming back to the
placeholder, and keyboard "done"/IME submit saving the same as tapping
Save. `flutter analyze lib` clean, busy-spinner addition confirmed
matching the Face ID toggle. **Status line is done.** Standing open
item, unchanged: the full restart-persistence round-trip against live
Supabase (does `status_text` really survive a force-quit) is still
unverified end-to-end — no real authenticated Simulator session
reachable by anyone via automation so far this session; schema/RLS
were already confirmed via Supabase MCP and nothing in the bugfix
touched that path.

## New feature: Dark mode — QA-verified, done

User asked for light/dark mode support defaulting to the device's OS
setting, alongside a bigger ask (personal status + 24h stories,
scoped globally across all a user's trips — see the section below,
not yet started). Agreed build order: dark mode → status line →
stories. This section covers dark mode only.

**What changed**: `lib/theme/app_colors.dart`'s `AppColors` went from
a `static const` color class to a `ThemeExtension<AppColors>` with
`AppColors.light`/`AppColors.dark` palettes (`copyWith`/`lerp`
implemented). Access changed from static `AppColors.xxx` references to
a `context.colors.xxx` extension getter (`AppColorsContext` at the
bottom of the same file), since a `ThemeExtension` can only be read at
runtime via `Theme.of(context)`. `lib/theme/app_theme.dart`'s
`AppTheme` now builds both `light()`/`dark()` off one shared `_build`
that takes an `AppColors` + `Brightness`. `lib/main.dart` gained
`darkTheme: AppTheme.dark()` and `themeMode: ThemeMode.system` on the
`MaterialApp` — no manual in-app toggle, purely OS-driven per the ask.

This forced a full mechanical sweep of every screen/widget file that
referenced the old static `AppColors.xxx` (26 files) to the new
`context.colors.xxx` form, which in turn broke every `const` expression
that had captured one of those references (a `ThemeExtension` lookup
isn't compile-time-constant) — 161 `flutter analyze` errors
(`invalid_constant`) across 24 files, fixed by removing just the
specific `const` keyword on each affected constructor, file by file
(never a blind regex/sed — an earlier bulk-sed attempt at the
`AppColors.` → `context.colors.` rename itself briefly corrupted both
theme files by not correctly excluding them; caught and fixed before
it went further). One distinct bug surfaced in the same sweep, in
`trip_detail_screen.dart`'s `_MemberRow`: a `StatelessWidget` doesn't
get an implicit `context` (unlike `State`), so a plain getter
referencing `context.colors.xxx` had an undefined `context` — fixed by
converting the getter into a method taking an explicit `BuildContext`
parameter, called from `build()`.

**Verification status**: `flutter analyze lib` clean (0 issues), full
arm64 build succeeds, installed and launched on the Simulator without
crashing. Visually confirmed myself via `simctl io screenshot` in both
appearance modes (`simctl ui <udid> appearance light|dark`) — light
mode renders unchanged from before the refactor, dark mode renders
correctly (dark background, light text, visible borders/accent, no
unstyled or white-flash elements) on the sign-in screen. Have NOT
visually walked every screen this way (no tap automation) — the
`const`-removal fixes were applied per-file by reading each one.

**QA pass on `3f8d73c` — clean, no bugs found.** Rather than relying on
`simctl` screenshots (documented as unreliable in this environment), QA
read the resolved `AppColors` `ThemeExtension` directly off the live
widget tree (`Theme.of(context).extension<AppColors>()`) and compared
it field-by-field against `AppColors.light`/`.dark` — exact, not a
visual judgment call. Confirmed: zero remaining static `AppColors.xxx`
references anywhere outside the theme files (mechanical migration
complete); every one of the ~30 hardcoded `Colors.white`/`Colors.black`
references in `lib/` audited and found legitimate/theme-independent by
design (photo+scrim overlays, text on accent-colored buttons, Apple's
required Sign in with Apple branding, full-screen black lightbox
viewers) — none are a stale light-mode leak; cold launch in both dark
and light resolves every screen (Sign-in, Home, Trip Detail, Chat,
Trips tab collapsed+expanded, Balances tab, Add Expense sheet, Group
creation) to the exact expected palette, light mode pixel-for-pixel
unchanged from before the refactor; semantic colors (moneyOwe vs
moneyOwed, successBg vs pendingBg, chat bubble self/other) stay
genuinely distinct in dark mode; and — the one check that needed a real
running app, not just a resolved value — flipping the Simulator's OS
appearance *while the app was already running* (`simctl ui <udid>
appearance dark`, no restart) triggered a live repaint to the exact
dark palette, confirming `ThemeMode.system` actually works, not just
that the static values are correct. Dark mode is done.

## New feature: "Things to do nearby" — not yet QA-verified

User's own idea, brainstormed and scoped via a couple of question rounds
before building (not from the earlier competitive-research batch). Lets a
member browse Foursquare-sourced venues within 10 miles of a trip's
destination and save any number to the trip's shared list, visible to the
whole group, each with a Navigate (device Maps app) and Remove action.

**Decisions locked in during brainstorming**: suggestions-list scope for
v1 (not a full day-by-day itinerary builder — that's a natural follow-up
if this lands well); Foursquare Places API over Google Places (free tier)
or OSM/Overpass (harder to work with); lives in the Trips tab's
expandable card (same place as Members/Photos/Activity/Memories), not
Trip Detail; shared group-wide via Supabase, not local-only like Photos;
Navigate hands off to the device's Maps app rather than an in-app
MapKit-style estimate.

**Real architectural finding surfaced mid-build**: the existing
expandable-card pattern (tap to reveal Members/Photos/Activity/Memories)
only existed on PAST trip cards — Upcoming trips in the Trips tab were
just a plain, non-expandable hero card. Since planning things to do is
inherently a pre-trip activity, extended Upcoming trip cards to also be
expandable (a separate "Details" toggle below the existing hero card,
NOT overloading the hero card's own tap — that's still tap-to-open-Trip-
Detail, unchanged), showing Members + Things to do nearby (deliberately
NOT Photos/Activity/Memories, which are past-trip concepts). This was my
own call, flagged to the user rather than silently expanding scope.

**What's built**:
- New Supabase table `trip_places` (trip_id, fsq_id, name, category,
  address, lat/lng, added_by, added_by_name; unique on trip_id+fsq_id so
  re-adding the same venue no-ops instead of duplicating). RLS is the
  same deliberately-loose interim policy as `trip_day_status` (any
  signed-in user can read/add/remove any trip's rows) — noted in the
  migration, same caveat as ETA: revisit once trips have real backend
  membership.
- `lib/services/nearby_places_service.dart` — Foursquare Places API
  search, `ll`+`radius`, no category filter so results come back
  naturally varied. **User registered a key and it's wired in
  (`89bc8cb`)** — but the FIRST version of this service used
  Foursquare's OLD `api.foursquare.com/v3/places/search` endpoint
  (raw-key auth, nested `geocodes.main` lat/lng), which turned out to
  return `410 Gone` — Foursquare had migrated their API entirely.
  Confirmed the new shape directly with curl against the live API
  rather than guessing again: new base URL
  `places-api.foursquare.com/places/search`, `Authorization: Bearer
  <key>` (not the raw key), a required `X-Places-Api-Version` dated
  header, `fsq_place_id` instead of `fsq_id`, and top-level
  `latitude`/`longitude` per result instead of nested under
  `geocodes.main`. Verified end-to-end against real Lake Tahoe
  coordinates before considering it done — got back a genuinely varied
  set (a lake, a state park, a scenic lookout, a bar).
- `lib/services/trip_places_service.dart` — the Supabase read/add/remove
  calls.
- `lib/screens/trips/nearby_places_picker_screen.dart` — full-screen
  browse+multi-select+add flow, geocodes the trip's destination
  (reusing the `geocoding` package already added for ETA) before
  searching.
- `trips_tab.dart` restructured: new `_UpcomingTripCard` (hero card +
  separate Details toggle + expanded Members/Things-to-do), `_PastTripCard`
  gained the same Things-to-do section (view/remove only, no Browse
  button — no adding new plans to a trip that's already happened), new
  shared `_ThingsToDoSection` widget used by both.
- `url_launcher` added as a new dependency for the Navigate button
  (hands off to `https://maps.apple.com/?daddr=...` on iOS,
  `https://www.google.com/maps/dir/...` on Android — both plain https
  universal links, no custom URL scheme / Info.plist entries needed).

**Verification status**: `flutter analyze` clean, full build succeeds
(arm64, installed and launched without crashing), the Foursquare API
call itself is confirmed genuinely working end-to-end via direct curl
testing (real varied results for real coordinates). Could NOT visually
verify the in-app UI myself (no OS-level tap automation, same limitation
as always) — this needs a QA pass before considering it fully done. Full
checklist in `docs/QA_CHECKLIST.md` under "Things to do nearby (new)".

**QA pass on `cc5a59e` + `864690b` — clean, one gap identified and
independently closed (`e5d71d5`).** All the pre-key UI (Upcoming card
regression check, tap isolation between hero-card-tap and Details-
toggle, expansion order, empty-state copy on both Upcoming/Past,
Past-card regression check) and the post-key live Browse flow (30
results, 17 distinct categories for the same Lake Tahoe coordinates,
real per-place lat/lng confirmed not falling back to the search
center) all confirmed clean. One gap QA correctly couldn't close: no
live signed-in session in their harness (same structural limitation as
OAuth) meant `TripPlacesService.addPlace`'s actual Supabase write was
unverified.

Tried to close that gap myself the same way — turned out the
simulator's own session had been cleared by earlier reinstalls, so no
live session was available to me either. Instead did a careful
line-by-line cross-check between the LIVE RLS policies (queried
directly, not from memory of what the migration said) and the actual
Dart calls — and that surfaced a real, independent bug neither the
code review nor QA's UI-level testing would have caught:
`addPlace()`'s upsert used Supabase's default merge-on-conflict
behavior, but `trip_places` only has SELECT/INSERT/DELETE RLS policies
— no UPDATE. A merge-style upsert's conflict path needs UPDATE
privileges even to legitimately no-op, so RLS would reject the WHOLE
request outright on any real duplicate (two different members
independently adding the same venue, or any accidental re-add) — not
just skip the duplicate, silently fail the entire add. Fixed with
`ignoreDuplicates: true` (keeps it on the INSERT/`ON CONFLICT DO
NOTHING` path, which only needs the INSERT policy — also a better
semantic match, since re-adding a place shouldn't reassign
`added_by`/`added_by_name`). Cross-checked `trip_day_status`'s similar
ETA upsert against the same pattern — that one does have a real UPDATE
policy (correct, since re-sharing an ETA should genuinely overwrite),
so it wasn't affected. **The actual live end-to-end write/read/remove
round trip is still unverified by anyone** — needs either a real
signed-in test session or a Supabase dashboard spot-check once someone
actually uses the feature for real.

## QA pass on `28e9768` (`ef4e789` for the fix) — 1 real bug, 2 clean, 1 blocked

- **Real bug, FIXED**: name fields on `ProfileDetailsStep` (email
  sign-in path) vanished mid-edit — `_needsName` was a live getter
  (`data.firstName.isEmpty && ...`), and the error-clearing `setState`
  in the name field's own `onChanged` triggered a rebuild the moment a
  single character was typed, at which point `_needsName` had already
  flipped to `false` and removed the very field being typed into
  (whatever was typed became permanent, no way to enter a last name at
  all). Fixed: `_needsName` captured once via `late final` at mount
  instead of recomputed live.
- **Cancel button (X) on Add Expense**: confirmed clean — filled a full
  form, tapped X, verified directly against `AppData` (not just the UI)
  that nothing was added.
- **Swipe-to-delete**: confirmed clean — Cancel leaves the charge
  untouched AND still swipeable afterward (not stuck half-swiped);
  Delete removes it from both UI and `AppData` immediately.
- **Email sign-in — blocked by a real Supabase rate limit**, not an app
  bug: `sendEmailOtp` returned a genuine `AuthApiException` (429,
  `over_email_send_rate_limit`) during testing. The graceful-failure
  path worked correctly (inline error shown, no hang/crash), but this
  means the OTP-screen transition, wrong-code handling, resend, and
  back-navigation chain are still unverified live. **Worth checking**:
  Supabase dashboard's Auth rate-limit config (Authentication > Rate
  Limits) — if it's set low enough to bite during normal testing, it'll
  also bite real early users signing up in a short window. No MCP tool
  available for reading/changing this (it's GoTrue/Auth server config,
  not a DB table) — dashboard-only, same as the Apple/Google provider
  setup earlier.

## Post-batch fixes from real user testing (`28e9768`)

User actually used a live build (see "how to view a real build" section
below — this is what made that possible) and reported 3 things:
1. **Google sign-in "did not work properly"** — **mitigation shipped**
   (`28e9768`): email sign-in as a third path — "Continue with email" on
   `SignInStep` -> `EmailSignInStep` (enter email) -> `EmailOtpStep`
   (6-digit code, `AuthService.sendEmailOtp`/`verifyEmailOtp`, Supabase's
   built-in email OTP, no new backend config needed). Since email gives
   no name at all, `ProfileDetailsStep` now conditionally collects
   first/last name when sign-in didn't provide one (`_needsName`).

   **Root cause investigated separately** (`0caf48e`), see the dedicated
   "Google sign-in root-cause investigation" section below for the full
   writeup — short version: it's very likely an iOS Simulator-specific
   `SafariViewService` presentation bug in THIS environment, not an app
   or config bug. Along the way found and fixed a real, unrelated bug:
   the sign-in error handler swallowed every exception silently (no
   logging anywhere), and `signInWithGoogle()` mislabeled ANY failure as
   "cancelled" — both fixed, which is what made this investigation
   possible at all and will make the NEXT one (whatever it's about)
   faster too.
2. Add Expense had no cancel affordance (only way out was submitting a
   dummy expense) — added an X button, pops without adding anything.
3. No way to delete a wrongly-entered expense — swipe-to-delete on
   Activity rows with a confirmation dialog; `AppData.removeCharge()`.

## Google sign-in root-cause investigation (`0caf48e`) — READ BEFORE
## touching Google Sign-In code again, and before assuming it's an app bug

**Method**: couldn't tap through the UI myself (no OS-level tap
automation), so called `AuthService.instance.signInWithGoogle()`
DIRECTLY from `main()` via a temporary `Future.delayed` trigger — same
effect as tapping the button, no UI interaction needed. Captured the
live device log via `xcrun simctl spawn <udid> log stream --predicate
'process == "Runner"'` (started BEFORE the trigger fires) and separately
checked Supabase's own auth logs via `mcp__claude_ai_Supabase__query_logs`.
Both temporary — reverted `main.dart` back to clean before committing;
only the two real fixes below (error logging, honest error message) are
permanent.

**Findings, most to least certain:**

1. **Zero Google sign-in attempts reached Supabase at all** — queried
   `auth_logs` for anything mentioning "google" in the last 24h: nothing.
   Compare: Apple sign-in attempts show up clearly (including two 400s
   with `"error":"invalid request: Passed nonce and nonce in id_token
   should either both exist or not"` right before a successful retry —
   worth knowing that error text if it resurfaces, but it was Apple
   retries here, not Google, and Apple's flow did succeed). This proves
   the failure is 100% client-side, before any token exchange —
   Supabase's Google provider config and the Cloud Console client IDs
   are not implicated by this evidence.
2. **The app's own error handling was actively hiding the problem**: found
   this BEFORE finding the real cause. `SignInStep`'s `catch (_)` never
   logged the actual exception anywhere, and `AuthService.signInWithGoogle()`
   asserted "Google sign-in was cancelled" for ANY null return from the
   native call — but that null return covers a real cancel AND silent
   failures identically, so the message was actively misleading. Both
   fixed (`0caf48e`) — this alone is worth having even if the deeper
   cause below turns out to be environment-specific and unfixable from
   here.
3. **Network connectivity to Google is fine** — `curl
   https://accounts.google.com/.well-known/openid-configuration` from
   this host: HTTP 200 in 77ms. Rules out "no internet access" as an
   explanation.
4. **The native flow does correctly start**: device log shows
   `AppSSOCore`'s `canPerformAuthorizationWithURL` returning NO (so it
   falls back to a full browser-hosted flow, which is normal), then a
   real request to `com.apple.SafariViewService` to host Google's OAuth
   web content, and that request succeeds
   (`FBSSystemService... Request successful: <BSProcessHandle:
   ...SafariViewServi:9953...>`). This rules out a bad client ID or a
   URL-scheme mismatch as the cause — those would show as an immediate
   config-rejection error, not a service that successfully launches.
5. **But the SafariViewService process never actually becomes visible**:
   `RunningBoardServices` reports its state as `running-active-NotVisible`
   — twice, a couple hundred ms apart — and it's never seen transitioning
   to visible before the flow gives up and `signIn()` resolves to null.
   The very first (shorter-delay) run additionally logged a UIKit
   warning: `Attempting to load the view of a view controller while it
   is deallocating is not allowed` (`SFAuthenticationViewController`) and
   `View service session ended with error ... {Message=Invalidation
   requested}` — consistent with the same "starts, never renders, gets
   torn down" pattern.

**Best-evidence conclusion, not 100% certain**: this looks like an iOS
Simulator-specific bug in how this Xcode/iOS runtime combination (26.6 /
26.5–27.0, all recently-new territory — this project has hit several
OTHER Simulator-specific quirks in exactly this environment already,
see the destination-resolution and arch-exclusion sections elsewhere in
this doc) presents `SafariViewService`'s remote view controller for
`ASWebAuthenticationSession`-style flows. **Apple's own Sign In succeeds
fine** because it goes through native `ASAuthorizationController`
(`sign_in_with_apple`'s actual code path), never touching
SafariViewService at all — so it isn't exposed to whatever this is.

**What would actually confirm or refute this**: someone with real hands
on a device (the user, or QA if it can reach a real device) tapping
"Continue with Google" and directly WATCHING whether a Google login page
ever visibly renders vs. flashes/does nothing vs. shows an error — my
automated trigger can't observe the screen the way a human can. Testing
on a REAL iOS device (not Simulator) would be the most decisive next
step, since this entire failure signature is specifically about
on-screen presentation, which real-device SafariViewService handling may
not share.

## Current phase: differentiation features (from competitive research)
## STATUS: all 4 built (`151aeda`) AND QA-clean — zero real bugs found
## across the whole batch. Only gaps are the usual "real native OS UI,
## can't drive it programmatically" class (permission dialogs, OAuth
## sign-in) — same limitation hit throughout this whole project, not new
## defects. A showcase rundown of the full app (all phases, not just this
## batch) was published as an Artifact for the user to share:
## https://claude.ai/code/artifact/794a0b0b-97a5-43d7-aafd-c3902afc279a


A separate research agent (`personal-projects-7c`) scanned ~11 niche
competitors (group-trip-coordination apps specifically, not general
expense-splitters or solo-itinerary tools) and found weather/ETA/
countdown, cross-trip balances, and AI cover art are things Waypoint
already has that NONE of them do. Full report:
https://claude.ai/code/artifact/484c9740-9e2e-4e63-b96c-d839a0106ae9

**All 4 done as of `00d9d09`.** User picked these, in this order:
1. ~~**Group polls**~~ **DONE** (`d9ad500`) — inline in chat as a message
   type, single-choice, local to the chat session (not backend-synced,
   matches existing chat architecture). See `lib/models/poll.dart` +
   `chat_screen.dart`.
2. ~~**Receipt OCR**~~ **DONE**, but NOT via the originally-planned
   `google_mlkit_text_recognition` package — see "Receipt OCR: why not
   Google ML Kit" below for what happened and why. Ended up as two native
   bridges instead: `ios/Runner/ReceiptScannerBridge.swift` (Apple's
   Vision framework) and `android/.../ReceiptScannerBridge.kt` (Android's
   ML Kit as a direct Gradle dependency, not a Flutter plugin), both
   behind one `lib/services/receipt_scanner_service.dart` (does the
   amount-parsing in Dart, shared across platforms — the native side only
   returns raw recognized text). Wired into `AddExpenseSheet` (a "Scan"
   button, thumbnail preview, prefills the Amount field) and
   `BalancesTab`'s Activity list (a receipt thumbnail, tappable to a
   full-screen viewer). `Charge` gained an optional `receiptImage` field
   (a `File`, matching the existing `TripPhoto` pattern — not persisted
   anywhere beyond the in-memory session, same as the rest of Charges/
   AppData right now).
3. ~~**Post-trip memory reveal**~~ **DONE.** Always-available recap card
   (user's choice, not a one-time animated reveal) — new `_MemoryRecapCard`
   in `trips_tab.dart`, the first thing shown when a past trip is expanded
   (above Members/Photos/Activity, same order as before). Reuses the
   existing `TripCoverArt` widget (so it automatically shows a generated
   cover when one exists, same as everywhere else) with a gradient +
   destination/date overlay matching `TripHeroCard`'s visual style, plus
   two stat tiles: total spend (summed from `AppData.chargesByTrip`,
   `TripsTab` didn't touch charges before this) and photo count (already
   had this data, just wasn't surfaced as a headline stat). No new model,
   no backend — matches the "mostly UI composition over existing data"
   plan exactly.
4. ~~**Ad-hoc member ETA**~~ **DONE** — the last of the 4. On trip day
   (`trip.status == upcoming && trip.daysLeft == 0` — none of the 3
   seeded sample trips satisfy this, only a freshly-created one dated
   today will show this section; see QA_CHECKLIST.md for how to test it),
   `TripDetailScreen` shows a "Today's ETAs" card between the weather row
   and Members: a "Share my ETA" button plus a list of every member's
   last-shared ETA (or "Not shared yet").
   - **iOS**: real driving-time ETA via Apple's MapKit — new
     `ios/Runner/EtaBridge.swift` (`MKDirections.calculateETA`), same
     wiring pattern as `ImagePlaygroundBridge.swift`/
     `ReceiptScannerBridge.swift` (manual pbxproj entries, registered in
     `AppDelegate.swift`).
   - **Android**: no MapKit equivalent, so a straight-line-distance
     (`Geolocator.distanceBetween`) + assumed-70kmh estimate instead —
     pure Dart, no native bridge needed on that side.
   - **Current location + destination geocoding**: `geolocator` (current
     position + the distance-between utility, also handles the OS
     permission prompt itself) and `geocoding` (turns `trip.destination`,
     e.g. "Lake Tahoe, CA", into coordinates) — both resolve via Swift
     Package Manager on iOS, no CocoaPods/deployment-target complications
     (unlike the ML Kit detour — see the Receipt OCR section above).
   - **Cross-member sync — the first real trip-data backend piece**: a
     new Supabase table, `trip_day_status` (trip_id, user_id, display_name,
     eta_minutes, computed_at; PK on trip_id+user_id so a repeat share
     upserts in place). RLS is deliberately loose (any signed-in user can
     SELECT all rows, can only INSERT/UPDATE their own) because trips/
     members still have no real backend membership concept to check
     against — noted as an interim policy in the migration's own
     comments, worth tightening if/when trips themselves get a real
     backend home.
   - **Location permission**: just-in-time as planned — only requested
     when "Share my ETA" is actually tapped, nothing upfront.
   - `lib/services/eta_service.dart` holds all of this (both platforms'
     ETA computation + the Supabase read/write), returning typed
     unavailable-reasons (permission denied, location services off,
     geocode failed, not signed in, sync failed) rather than throwing —
     every failure path surfaces a specific message in the UI, matching
     the pattern established by `CoverGenerationResult`/
     `AuthResult`/etc. elsewhere in the codebase.

## Receipt OCR: why not Google ML Kit (real environment blocker, not a
## project bug — read this before adding ANY new iOS CocoaPod)

Originally implemented with `google_mlkit_text_recognition` (the obvious,
cross-platform choice). Hit a genuine dead end on iOS, specific to THIS
environment:

- Google's underlying iOS pods (`GoogleMLKit`/`MLKitCommon`/`MLKitVision`/
  `MLImage`) ship **no arm64 simulator slice** — a long-standing gap in
  their precompiled binaries. Confirmed via `flutter run`'s own error
  message, not a guess.
- The old workaround for that (`EXCLUDED_ARCHS[sdk=iphonesimulator*] =
  arm64`, forcing x86_64-via-Rosetta) does NOT work here: this machine's
  simulator runtimes are iOS 26.5/27.0, and `flutter run` explicitly
  refuses arm64-lacking pods on "Apple Silicon iOS 26+ simulators" —
  Apple has dropped x86_64 simulator support entirely at this OS version,
  so there's no architecture that satisfies both the pods and the
  runtime. No simulator runtime older than 26.5 is installed here either
  (checked `xcrun simctl list runtimes`), so there's no escape-hatch
  device to fall back to.
- **Fix**: dropped the Flutter plugin entirely. Replaced with two native
  bridges, matching the `ImagePlaygroundBridge.swift` pattern already
  established for Image Playground — first-party APIs only, no
  precompiled third-party binaries, so this class of problem can't recur:
  `ios/Runner/ReceiptScannerBridge.swift` (Apple's own Vision framework,
  ships with the OS) and `android/.../ReceiptScannerBridge.kt` (Android's
  ML Kit as a **direct Gradle dependency**, not a Flutter plugin — Android
  isn't affected by any of this, but going direct avoids the iOS
  podspec-per-platform coupling a Flutter plugin would otherwise force).
  One shared `lib/services/receipt_scanner_service.dart` talks to
  whichever platform's bridge is present.

**Separate, also-real environment bug hit along the way**: while
diagnosing the above, `xcodebuild` (any action — `build`, `-showBuildSettings`)
stopped resolving ANY concrete simulator destination (`-destination
id=<udid>`) — always falls back to offering only generic placeholders
("Any iOS Simulator Device"), even though `xcrun simctl` and `xcodebuild
-showdestinations` both see the device correctly. Reproduced with the
project in its known-good, pre-ML-Kit state too, so it's **not caused by
this session's code changes at all** — purely environmental. Ruled out:
stale DerivedData (cleared, still broken), a duplicate "iPhone 17"
simulator name collision (renamed the unused duplicate to "iPhone 17
(unused)", still broken), a stale CoreSimulator cache (restarted the
service, still broken). Best guess, unconfirmed: something related to
now having TWO simulator runtimes installed (26.5 and 27.0) confusing
Xcode 26.6's destination matcher. **Practical impact**: `flutter run -d
<device>` (needed for interactive/video verification) doesn't work right
now in THIS session's environment — but `xcodebuild ... -destination
'generic/platform=iOS Simulator' build` (no concrete device) still works
fine, and IS how the Receipt OCR code above was verified (build succeeds,
`flutter analyze` clean) — just without a live on-screen capture this
round. Worth asking the QA agent whether their launch mechanism hits the
same wall or is unaffected (their session may not have gone through
whatever triggered this). **Update: QA independently confirmed the same
`-destination id=<udid>` resolution bug on their side too — genuinely
environmental, not scoped to one session. Does NOT block QA's actual
mechanism (`flutter test integration_test/... -d <udid>`), which works
fine regardless.**

**Second, related discovery (2026-08-29) — the "generic destination"
verification workaround above was quietly incomplete.** User asked how
to view a full build themselves, which needed an actually-*runnable*
binary, not just a compiling one — that surfaced this: `xcodebuild
-destination 'generic/platform=iOS Simulator'` builds for **x86_64 by
default** (`ARCHS = x86_64` — confirmed via `-showBuildSettings`), and
this machine's simulator runtimes (26.5/27.0 only) can't run x86_64 at
all — Apple dropped that entirely, same fact already established in the
Receipt OCR section above. So every "verified via successful
generic-destination build" claim earlier in this doc proved the *code*
compiles and links correctly, but never proved the binary could actually
*run* here — `xcrun simctl install` on one of those builds fails outright
("Failed to find matching arch for input file"). Root cause: Flutter's
own auto-generated `ios/Flutter/Generated.xcconfig` hardcodes
`EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386 arm64` as a static fallback —
normally corrected dynamically at build time by Flutter's own
`xcode_backend.sh` script phase for a concrete target device, but the
*generic* destination gives that script nothing concrete to correct
*for*, so the static x86_64-only fallback survives uncorrected.

**The fix / how to actually view a real build on this machine**, since
both the concrete-destination CLI path AND the plain generic-destination
path are broken in their own ways:

```bash
# 1. Build for the generic simulator destination, but override the
#    arch exclusion Flutter's Generated.xcconfig hardcodes, and force
#    arm64 explicitly (both on the command line so they win over the
#    xcconfig file):
xcodebuild -workspace Runner.xcworkspace -scheme Runner -configuration Debug \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  'EXCLUDED_ARCHS[sdk=iphonesimulator*]=i386' ARCHS=arm64 build

# 2. Install + launch directly via simctl — a different tool from
#    xcodebuild, unaffected by its broken -destination id=<udid>
#    resolution:
APP=~/Library/Developer/Xcode/DerivedData/Runner-*/Build/Products/Debug-iphonesimulator/Runner.app
xcrun simctl install 607D6413-7714-4C48-9EDE-979E0E97D7F3 "$APP"
xcrun simctl launch 607D6413-7714-4C48-9EDE-979E0E97D7F3 com.srigautham.waypoint
open -a Simulator   # brings the window forward so it's actually visible
```

Confirmed working end-to-end (2026-08-29): built, installed, launched,
video-captured a frame showing the real sign-in screen rendering
correctly. **This is now the standard way to get an interactive,
on-screen build in this environment** — faster and more reliable than
chasing the `flutter run -d <device>` bug further. Retroactive note: this
doesn't cast doubt on any FEATURE's correctness verified earlier via
`flutter analyze` + a successful generic-destination build — those are
still valid proof the code compiles/links right — it just means none of
those checks alone ever proved the binary could run here, which this
method now closes.

## Big picture

1. Designed the whole app first as a clickable prototype using the `design`
   skill (Claude Design canvas), published as an Artifact. That prototype
   (onboarding, home, trip detail, chat, group creation, trips, balances)
   is DONE and is the source of truth for visual/UX design — see the
   `design/onboarding-directions/Main.dc.html` working file in this repo
   if you need to check what something is supposed to look like/behave.
2. Now implementing the real app in Flutter (`app/` directory), screen by
   screen, matching that design. This is the current phase of work.
3. **Two-agent setup**: this session (`personal-projects-ef`) does design
   and development. A second Claude Code session (`personal-projects-8e`)
   was started by the user to do build validation / e2e testing in the iOS
   Simulator — **report-only, it does not fix bugs**. Communication:
   - It reports via `app/test_report.json` (its own test infra under
     `app/test/` — don't touch that, it's the other agent's territory).
   - Either session can reach the other live via `SendMessage` when both
     are running (`ListAgents` to discover the peer's current name — it
     was `personal-projects-8e` as of this writing, but names can change
     session to session).
   - `docs/QA_CHECKLIST.md` is what I hand it to check on every build —
     **update this file whenever a new screen/flow is added**, so the
     other agent's next pass covers it.
   - The prompt originally given to that agent is preserved in this
     conversation's history (search for "You're the QA/build-validation
     agent" if it needs to be reconstituted for a fresh session).

## QA agent communication log (most recent first)

- **Differentiation batch, final QA pass — all 4 features clean, zero
  real bugs.** QA (as `personal-projects-5a`, after a session/naming
  reset — re-established contact via a peer message) went through all 4
  in sequence:
  - Group polls (`d9ad500`): confirmed clean.
  - Receipt OCR (`57d858e`): genuinely verified, not just structurally —
    fed synthetic receipt images with real text straight to
    `ReceiptScannerService.scanTotal()` on-device: correctly extracted
    $8.50 preferring a "Total" line over "Subtotal", correctly fell back
    to the largest amount with no Total line, correctly returned null
    (no crash) on a blank image.
  - Trip Memories recap (`9df2e98`): total spend $210.00 for the seeded
    Napa Wine Tour, exactly matching `sample_charges.dart`'s `t3` entries
    (150+60) — not a stray $0.00. Section order and value-across-
    collapse/re-expand both correct. Photo-count-updates-live case
    couldn't be driven (same native-photo-picker gap as the existing
    Photos grid).
  - Ad-hoc ETA (`00d9d09`): correctly absent on all 3 seeded trips
    (`daysLeft == 0` gate confirmed), correctly appears on a freshly
    created today-dated trip, denied-permission path fully verified
    end-to-end (pre-revoked via `simctl privacy revoke location` before
    install — this makes iOS treat it as already-decided so no system
    dialog blocks the run — correct error message, no crash/hang, button
    stays unrelabeled). Could NOT drive past the first-time permission
    dialog itself (`simctl privacy grant` doesn't survive the fresh
    install `flutter test` does each run — only *revoked* sticks as a
    pre-decided state, not *granted*) — so the real MapKit/geocoding
    compute path is the one untested slice, same native-UI-outside-
    Flutter's-tree class of gap as OAuth/Face ID throughout this project,
    not a new concern.
  - `flutter test` 45/45, `flutter analyze lib test` clean at `151aeda`.
  - Also independently confirmed the `xcodebuild`/`flutter run -d <UDID>`
    concrete-destination bug (see "Receipt OCR: why not Google ML Kit"
    section above) reproduces on QA's side too — environment-level,
    genuinely not scoped to one session — but does NOT block QA's actual
    testing mechanism (`flutter test integration_test/... -d <UDID>`
    works fine regardless).
- **Add Expense stuck-sheet bug — RESOLVED, was never an app bug**
  (`50ed373`). 4 rounds of investigation (below, kept for the "how we got
  there" record) eventually got decisive `NavigatorObserver` evidence
  that `didPop` never fired for the sheet's route, so debugPrint
  instrumentation was shipped (`08d3e1e`) to compare the Navigator/route
  identity at push vs. pop. **The instrumentation itself revealed the
  real story**: `_submit()` was only ever called ONCE per repro run (the
  first, empty-reject tap) — the 2nd and 3rd taps never reached it at
  all. Root cause was QA's OWN test harness: `enterText()` on the amount
  field shifts the sheet's layout via keyboard-avoidance, and QA's taps
  were landing at a screen coordinate computed *before* that shift
  settled — missing the submit button entirely on 2 of 3 attempts (the
  `RenderAbsorbPointer` hit-test warnings from round 4 were the real
  tell, in hindsight). Fixed on QA's side with `tester.ensureVisible()`
  before that tap; all variants (exact repro, double-tap, triple-tap) now
  pass clean. **Cleaned up** (`50ed373`): removed the debugPrint
  instrumentation and the two speculative round-3 fixes (unfocus-before-
  pop, defer-addCharge-a-frame) since neither was fixing anything real.
  **Kept**: the `_submitted` guard (`AddExpenseSheet._submit()`) and
  `_addingExpense` guard (`BalancesTab._addExpense()`) from rounds 1-2 —
  both are genuinely reasonable defensive coding against a real double-
  tap/reentry, independent of this particular investigation, even though
  neither was masking a live bug here.
- **Add Expense stuck-sheet bug, rounds 1-3 (historical)**: QA found it on
  `3fe793f`/`fb51af5`/`64d28ea` pass — reject empty, reject amount=0, then
  a valid submit leaves the sheet's widgets + an extra ModalBarrier stuck
  in the tree (charge does get added to AppData though). Round 1 fix
  (`3fcbc97`): added a `_submitted` guard in `AddExpenseSheet._submit()`
  against a second `Navigator.pop()`. QA re-verified: **fixed the
  rapid-double/triple-tap case, but NOT their original exact repro**
  (deliberate single taps, full `pumpAndSettle` between each — genuinely a
  different bug, `_submitted` never even reaches true on that path). Round
  2 (`a7c2b20`): found the trip card's own "Add expense" trigger button
  shares its label text with both the sheet's title and its submit
  button (three "Add expense" text widgets live in the tree once the
  sheet's open) AND `_addExpense` in `balances_tab.dart` had **no guard
  against being called again** while a sheet from a prior call was still
  open — a second call would stack a second sheet on top of the first,
  which fits the symptom (topmost sheet's valid submit succeeds, an
  older untouched sheet is left stuck underneath). Added an
  `_addingExpense` reentry guard. QA re-verified `a7c2b20`: **still
  reproduces, and definitively ruled out the reentry theory** —
  `find.byType(AddExpenseSheet).evaluate().length == 1` at the stuck
  point (one sheet instance, not stacked), and a clever 4th-tap check
  proved `Navigator.pop(charge)` fires exactly once, its Future resolves,
  and the charge reaches AppData — yet the route's widgets/barrier are
  never actually torn down, with `pumpAndSettle()` returning clean (no
  animation left pending). That signature — logical pop succeeds, visual
  teardown doesn't, only after 2 rejected attempts precede the real one —
  is deep Flutter route-lifecycle territory neither of us can fully
  confirm without a debugger. Round 3 (`325215a`), two independent
  candidate fixes shipped together since both are safe regardless of
  which (if either) is the real mechanism: (1) `FocusManager.instance
  .primaryFocus?.unfocus()` right before the pop — a focused field's
  keyboard-dismiss animation racing the sheet's own closing transition
  is a known cause of exactly this symptom; (2) deferred the
  `AppData.addCharge` call (which synchronously rebuilds the whole
  `BalancesTab` ancestor via `notifyListeners()`) to a
  `WidgetsBinding.instance.addPostFrameCallback`, so it can't interleave
  with the route's own teardown in the same frame. **Unconfirmed as of
  this writing** — if QA reports this still doesn't fix it, next step is
  probably temporary debugPrint instrumentation around the pop/route
  lifecycle (QA has execution access to actually run and observe this;
  I don't), or checking `WidgetsBinding.instance.focusManager
  .primaryFocus` at the stuck point to see if a field is still holding
  focus (would confirm/deny the unfocus theory directly).
- **Pinged with `da35c61`** (group creation + shared state) — explicitly
  flagged that I couldn't verify the actual Create-group button-tap flow
  myself (no OS-level tap automation on my side) and asked it to
  prioritize that. Awaiting response.
- **Full pass on `7fae736` reported clean** — 48/48 of its own unit tests
  passing, walked the whole `QA_CHECKLIST.md` manually + via
  `integration_test` (run from an isolated git worktree so it never
  touched my live working tree), **zero confirmed app bugs**. It also
  triaged 3 things that looked like bugs but weren't (all details in
  conversation history if needed, short version: two were its own
  test-harness flakiness under a long automated action sequence,
  re-confirmed clean on isolated repro; one was — surprise — *another*
  manifestation of the `simctl io screenshot` unreliability, this time
  serving a stale/duplicate frame rather than a stretched one, confirmed
  via direct widget-tree color inspection). Noted gaps it couldn't cover
  yet: the photo-picker add flow and slideshow (both need a real OS photo
  picker interaction it can't automate) — these remain unverified by
  either of us via live UI, though the code path was reviewed and
  `flutter analyze`/unit-testable logic checks out.
- **Resolved**: user said not to commit test files, only the app codebase.
  `app/test/*`, `app/test_report.json`, `app/run_tests_and_report.sh` stay
  untracked (the QA agent's own territory) — never `git add` them.
- Fixed its own stale test files early on (`widget_test.dart`,
  `e2e_flow_test.dart` were asserting the app launches on
  `BalancesByPersonScreen`, a holdover from my temporary debug wiring at
  the time) — this was its own initiative on its own files, not something
  I did or needed to review.
- It's set up a separate git worktree at a pinned commit for driving real
  taps/typing via Flutter's `integration_test` package, kept isolated
  from my live working tree — that's how it plans to do interactive
  verification going forward without colliding with my in-progress edits.

## Environment setup (already done, don't redo)

- Node.js, GitHub CLI (`gh`, authed as Sri-Gautham) installed via
  `~/.local/bin` (added to PATH in `~/.zshrc`).
- Flutter SDK installed at `~/development/flutter` (added to PATH).
- Ruby 3.3.6 via rbenv at `~/.rbenv` (system Ruby was too old for
  CocoaPods) — needed `~/.rbenv/bin` on PATH + `eval "$(rbenv init - zsh)"`.
- CocoaPods installed via that Ruby.
- Xcode installed to `/Applications/Xcode.app`, `xcode-select` pointed at
  it, license accepted.
- **Every `flutter run`/`flutter pub get`/etc. shell command in this
  session needs this preamble** (nvm/node not required for Flutter work,
  only rbenv+flutter):
  ```bash
  export PATH="$HOME/.rbenv/bin:$HOME/development/flutter/bin:$PATH"
  eval "$(rbenv init - zsh)"
  ```
- iOS Simulator device used throughout: iPhone 17, UDID
  `607D6413-7714-4C48-9EDE-979E0E97D7F3`. Boot with
  `xcrun simctl boot 607D6413-7714-4C48-9EDE-979E0E97D7F3` if shut down.
- Bundle id: `com.srigautham.waypoint`.

## IMPORTANT known tooling bug

`xcrun simctl io screenshot` produces **misleading captures** in this
environment — spent a long detour on this. A correctly-sized, fixed
100×100 `Container` rendered as a wildly stretched rectangle in the
screenshot, while the actual on-screen content (confirmed via
`xcrun simctl io recordVideo` + `qlmanage -t` thumbnail extraction) was
correct. Verified via `debugPrint` of layout constraints too — the code
was right, the screenshot tool was wrong. **Never trust `simctl io
screenshot` alone for verifying a suspicious layout; use the video+
qlmanage method instead:**
```bash
xcrun simctl io <udid> recordVideo --codec=h264 /tmp/out.mp4 &
RECORD_PID=$!; sleep 3; kill -INT $RECORD_PID; wait $RECORD_PID
qlmanage -t -s 1200 -o /tmp/ /tmp/out.mp4   # produces /tmp/out.mp4.png
```
This is documented at the top of `docs/QA_CHECKLIST.md` too.

## Verification workflow used throughout

For each new screen: `flutter analyze` (scoped to `lib/` only — running it
unscoped also analyzes the other agent's `test/` files, which aren't mine
to fix), then temporarily point `lib/main.dart`'s `home:` at the new
screen (with dummy sample data if needed), `flutter run -d <udid>`,
capture via the video method above, then **revert `main.dart`** back to
`const OnboardingFlow()` before committing. Always `git diff app/lib/main.dart`
before committing to make sure it's clean (matches HEAD) unless a real
change to the entry point was intended.

## What's built in Flutter so far (all committed & pushed)

- **Theme**: `lib/theme/app_colors.dart`, `app_theme.dart` — oklch values
  from the design converted to hex via a manual OKLab conversion script
  (not a package). `lib/theme/cover_theme.dart` — 4 trip cover palettes
  (Mountain Lake / Beach / Desert / Forest), also oklch→hex converted.
- **Onboarding** (`lib/screens/onboarding/`): originally 5 fake-form/fake-
  OTP steps — **superseded**, see "Backend + auth + Face ID + generated
  covers" below for the current real-auth flow. `OnboardingData` model
  still holds the profile form state, passed through to `MainShell`.
- **Home dashboard** (`lib/screens/home/home_tab.dart`): greeting, hero
  trip card (via shared `TripHeroCard` widget), quick actions, recent
  activity. Trip landscape art is a custom `CustomPainter`
  (`lib/widgets/trip_landscape.dart`) recreating the design's layered
  mountain/lake SVG, not an image.
- **App shell** (`lib/screens/home/main_shell.dart`): bottom nav (Home,
  Trips, Balances, Activity, Profile) via `IndexedStack` +
  `lib/widgets/app_bottom_nav.dart`.
- **Trip Detail** (`lib/screens/trip/trip_detail_screen.dart`): hero with
  days-left badge, destination/date/ETA, Start button (visual only, no
  real maps deep link yet) + weather card, full member list with
  Admin/Member/Invited badges.
- **Chat** (`lib/screens/trip/chat_screen.dart`): real send box, message
  bubbles, correct roster subtitle (accepted members only).
- **Trips tab** (`lib/screens/trips/trips_tab.dart`): Upcoming (hero
  cards) / Past (expandable cards: Members, Photos grid, Activity log)
  split. Photos are REAL — picked via `image_picker` (camera or library),
  not placeholders (this was a deliberate scope decision, since we're
  past the sandboxed-design-canvas stage). Play button opens
  `lib/screens/trips/photo_slideshow_screen.dart` (full-screen viewer,
  Previous/Next, wraps around).
- **Balances tab** (`lib/screens/balances/`): overall balance card +
  "Settle Now", Upcoming/Past filter, per-trip cards expand to
  who-owes-whom + itemized charges + a real **Add Expense** form
  (`add_expense_sheet.dart`). Balances computed LIVE from charges via
  `lib/utils/balance_calculator.dart` (not hardcoded) — sign convention:
  positive net = they owe you, negative = you owe them. "Settle Now"
  opens `balances_by_person_screen.dart`: cross-trip aggregated net per
  person, "Settle up" only shown for people you owe, payment amount is
  capped at what's owed, reduces their balance.
- Data models: `Trip`/`TripMember`/`MemberStatus`/`TripStatus`
  (`lib/models/trip.dart`), `Charge`/`ChargeCategory`
  (`lib/models/charge.dart`), `Payment` (`lib/models/payment.dart`),
  `ActivityLogEntry`, `TripPhoto`, `ChatMessage`, `ActivityItem`,
  `OnboardingData`.
- `lib/data/sample_charges.dart` — seed charge data per trip id (t1 Lake
  Tahoe Crew, t2 Weekend at the Cabin, t3 Napa Wine Tour — same 3 sample
  trips as the design prototype).

## Group creation + shared app state — DONE (commit `da35c61`)

Moved off static `Trip.all` (a const list) onto a shared, mutable app-wide
state object, because group creation needs to add a new trip that shows up
everywhere (Home, Trips tab, Balances tab) — static data can't support
that. All of the following is complete, committed, and pushed:

- `lib/state/app_data.dart`: `AppData extends ChangeNotifier` (holds
  `trips`, `chargesByTrip`, `payments`; methods `addTrip`, `addCharge`,
  `addPayment`, all calling `notifyListeners()`) + `AppDataScope extends
  InheritedNotifier<AppData>` with a static `.of(context)`. **Important**:
  wired in `main.dart` ABOVE `MaterialApp` (wrapping it, not inside a
  route) — deliberate, since an `InheritedWidget` placed inside one
  route's subtree does NOT propagate to sibling routes pushed via the
  same `Navigator`; it must sit above the `Navigator` so every pushed
  screen can reach it.
- `HomeTab`, `TripsTab`, `BalancesTab`, `BalancesByPersonScreen` all read
  from `AppDataScope.of(context)` now (no more static `Trip.all` reads or
  screen-local charges/payments state).
- `lib/screens/group/create_group_flow.dart` + `lib/screens/group/steps/`
  (`group_basics_step.dart`, `group_destination_step.dart`,
  `group_invite_step.dart`) — 3-step wizard, `GroupDraft` model
  (`lib/models/group_draft.dart`), `lib/data/sample_contacts.dart` (5
  sample contacts for the invite step). On "Create group": builds a new
  `Trip`, calls `AppDataScope.of(context).addTrip(...)` (inserted at
  index 0, so it becomes the new `nextTrip`/Home hero card immediately),
  `pushReplacement`s into that trip's `TripDetailScreen`.
- Generalized `lib/widgets/step_header.dart` to take a `total` param
  (default 4, for onboarding) instead of hardcoding "/4" — reused for
  this 3-step wizard with `total: 3`. (Caught and fixed a real bug here
  before it ever ran: my first draft nested a hardcoded `StepHeader` +
  redundant title Row, which would've shown the wrong step total — fixed
  by generalizing the shared widget properly instead of patching around
  it.)
- Verified each step's static rendering via the video-capture method (not
  `simctl io screenshot`) — no exceptions, correct step counters ("1 / 3"
  etc.), correct cover swatch selection, correct destination-mode field
  toggling, correct invite code/contacts/chips rendering. **Not
  verified by me**: the actual button-tap interaction flow (filling all 3
  steps, tapping through, confirming the created trip lands correctly on
  Trip Detail and shows up on Home/Trips/Balances) — I have no OS-level
  tap automation in this environment. Explicitly handed this to the QA
  agent as the priority item for its next pass (see below).
- `docs/QA_CHECKLIST.md` updated with a full "Group creation" section
  (including edge cases: empty name → "My Trip", no destination →
  "Destination TBD", no start date → "Date TBD", zero invitees → just you
  as a member) and a "Shared state" note under Cross-cutting explaining
  `AppData`/`AppDataScope` for whoever's debugging a stale-data-looking
  bug.
- Pinged `personal-projects-8e` (QA agent) with commit hash `da35c61` and
  flagged the untested tap-flow explicitly. Awaiting its next report.

### Not started yet (planned, no other big design-prototype gaps remain)

- "Join with code" on Home is still a disabled stub (never built — this
  wasn't in the original design prototype's scope either, it was always
  a secondary/deferred entry point next to "Create a group").
- No real navigation deep-link from Trip Detail's "Start" button (shows a
  snackbar placeholder) — matches the design prototype's own scope (it
  was explicitly a visual stand-in there too).
- Everything else from the original design canvas prototype (onboarding,
  Home, Trip Detail, Chat, Trips tab incl. real photos, Balances tab incl.
  Add Expense, and now group creation) has a real Flutter implementation.
  Next open-ended work is either: (a) responding to whatever the QA agent
  reports, or (b) whatever new feature/polish the user asks for next —
  check the live conversation for the most recent ask rather than assuming
  this file's "planned" section is exhaustive.

## Backend + auth + Face ID + generated covers — DONE, pending user setup steps

User asked for: real backend (chose **Supabase**), Sign in with Apple/Google,
optional Face ID after first sign-up (session persistence + biometric gate),
and AI-generated trip covers from the destination instead of the 4 static
presets (iOS via Apple's **Image Playground** framework; Android has no
on-device equivalent, so it searches **Unsplash** for a real destination
photo instead — user picked this over Google Places Photos, which needs a
billing account, and over sticking with presets).

- **Supabase project**: created via the `mcp__claude_ai_Supabase__*` tools
  (org "Sri Gautham", project `waypoint`, id `eywyttdqpqfctkruczhb`, region
  us-east-2, free tier). URL/anon key live in `lib/config/supabase_config.dart`
  (safe to ship client-side — RLS locks every table to its owner). Schema so
  far: `public.profiles` (first/last name, email, phone, home address
  fields, avatar_url, auth_provider, face_id_enabled), RLS policies
  (select/update/insert own row only), `handle_new_user()` trigger on
  `auth.users` insert that seeds the row from OAuth metadata — locked down
  (`revoke execute ... from anon, authenticated`) after the security
  advisor flagged it as publicly callable via RPC otherwise. No trip/charge/
  expense data has been moved to Postgres — that's still local `AppData`
  in-memory state; only auth/profile is real-backend now. If asked to
  persist trips/expenses for real, that's a separate, bigger migration.
- **Auth** (`lib/services/auth_service.dart`): `signInWithApple()` /
  `signInWithGoogle()` both go through Supabase's native
  `signInWithIdToken` (not the web OAuth redirect flow) — Apple via
  `sign_in_with_apple` package + a SHA-256 nonce, Google via `google_sign_in`
  package. `AuthResult.isNewUser` compares `createdAt`/`lastSignInAt` to
  know whether to show the Face ID prompt. `loadProfile()`/`saveProfile()`
  read/write the `profiles` row.
- **Onboarding rewrite** (`lib/screens/onboarding/`): replaced the old fake
  manual-form + fake-OTP flow entirely. New flow: `SignInStep` (Apple/Google
  buttons, no manual name/email/phone form — that data now comes from
  OAuth) -> `ProfileDetailsStep` (just phone + home address, since OAuth
  can't give us those) -> `AllSetStep` -> `EnableFaceIdStep` (only shown on
  a first sign-up). Deleted `create_account_step.dart`, `verify_code_step.dart`,
  `home_address_step.dart` (superseded/folded in).
- **Session persistence + Face ID**: `main.dart`'s `_StartupGate` checks
  `AuthService.instance.isSignedIn` (Supabase persists the session locally
  on its own) on cold launch — signed out -> `OnboardingFlow`; signed in
  without Face ID enabled -> straight to `MainShell`; signed in with Face ID
  enabled -> `FaceIdGateScreen` first (`lib/screens/onboarding/
  face_id_gate_screen.dart`). Toggle lives in `ProfileTab` too (Face ID
  switch + a "Sign out" button), backed by `lib/services/
  biometric_service.dart` (wraps `local_auth`).
- **Cover generation** (`lib/services/cover_generation_service.dart`):
  `generate(destination)` branches on platform. iOS calls a native
  MethodChannel (`com.srigautham.waypoint/image_playground`) implemented in
  **`ios/Runner/ImagePlaygroundBridge.swift`** (new file — presents
  `ImagePlaygroundViewController`, iOS 18.1+, Apple-Intelligence-capable
  devices only; gracefully reports unavailable otherwise). Android calls
  Unsplash's search API (`lib/config/unsplash_config.dart` — **empty
  access key, needs the user to fill it in**, see below). Either platform
  falls back to the 4 illustrated presets on failure/unavailability — see
  `GroupDestinationStep`'s "Generate cover" card (added after the City/State
  fields, since destination isn't known yet in `GroupBasicsStep` where the
  preset swatches live) and `GroupBasicsStep`'s swatch row (picking a preset
  clears any generated cover). `Trip.coverImageBytes` (new optional field)
  + `TripCoverArt` widget (new — `lib/widgets/trip_cover_art.dart`) render
  the generated photo when present, else fall back to the existing
  `TripLandscape` CustomPainter; `TripHeroCard` and `TripDetailScreen` both
  switched over to `TripCoverArt`.
- **iOS native wiring done by hand** (no Xcode GUI available in this
  environment): added `ios/Runner/Runner.entitlements`
  (`com.apple.developer.applesignin`), wired `CODE_SIGN_ENTITLEMENTS` into
  all 3 Runner build configs in `project.pbxproj` via a scripted edit (not
  Xcode's "+Capability" button), added the new `ImagePlaygroundBridge.swift`
  file to the pbxproj (`PBXFileReference`/`PBXBuildFile`/group/Sources phase
  entries — this project doesn't use Xcode 16's synchronized-groups
  auto-discovery, so new files need this manual wiring), registered the
  channel in `AppDelegate.swift`'s `didInitializeImplicitFlutterEngine`.
  Ran `pod install` for the first time (only `sign_in_with_apple` needs
  CocoaPods — everything else, including the newly added google_sign_in/
  local_auth, resolves via Swift Package Manager automatically, this
  project's default). **Verified the full Runner target builds green** via
  `xcodebuild -workspace Runner.xcworkspace -scheme Runner -sdk
  iphonesimulator build` (must use the `.xcworkspace`, not the bare
  `.xcodeproj`, now that CocoaPods is involved — building the bare
  `.xcodeproj` fails with "Module 'sign_in_with_apple' not found").
- **Android native wiring**: `MainActivity.kt` changed from `FlutterActivity`
  to `FlutterFragmentActivity` (`local_auth`'s biometric prompt requires a
  FragmentActivity — this would otherwise crash at runtime, not build time).
  Added `INTERNET` and `USE_BIOMETRIC` permissions to the manifest
  (`INTERNET` wasn't there before; debug builds get it implicitly but
  release builds don't, and Supabase/Unsplash both need it). **Not build-
  verified** — this project's established scope is iOS Simulator only (see
  "Two-agent setup" above), no Android build has been run in this
  environment at all, before or after this change.
- `flutter analyze lib` clean throughout.

### User setup steps still needed (I can't do these — external accounts)

1. ~~**Google Cloud Console**~~ **DONE** (commit `fb51af5`) — user created the
   Web app OAuth client (redirect URI
   `https://eywyttdqpqfctkruczhb.supabase.co/auth/v1/callback`) and the iOS
   OAuth client (bundle id was `com.waypoint.waypoint` at the time — **now
   stale, see item 5, the bundle ID rename**), enabled the Google
   provider in Supabase's dashboard with the Web client's ID/secret. I wired
   the Web client ID into `lib/config/google_auth_config.dart` (feeds
   `serverClientId`, matching what Supabase's provider expects as the ID
   token audience) and the iOS client ID both into that same config file
   (passed explicitly as `GoogleSignIn(clientId: ...)`, since there's no
   `GoogleService-Info.plist`) and, reversed, into `ios/Runner/Info.plist`'s
   `CFBundleURLTypes`. **Google Sign-In should now be end-to-end
   functional** — but note real completion needs a human tapping through an
   actual Google account login in a system browser sheet; the QA agent's
   `integration_test` tap automation can't drive that (it's outside
   Flutter's own widget tree), so its check is still just "no crash, right
   buttons show/hide," not a full successful sign-in.
2. ~~**Supabase dashboard** (Google + Apple)~~ **DONE.** Apple provider
   enabled with Client IDs = `com.srigautham.waypoint`, **no Secret Key
   needed** — confirmed Supabase saved it blank, since the app only uses
   the native ID-token flow (audience = Bundle ID), never the web OAuth
   redirect that the key/Team ID/Services ID song-and-dance is actually
   for. Worth remembering if this ever needs revisiting: that whole
   fallback path (Keys > Sign In with Apple > associate with App ID >
   download .p8 > Team ID from Membership details) turned out to be
   unnecessary for us.
3. ~~**Apple Developer portal**~~ **DONE.** App ID `com.srigautham.waypoint`
   created fresh (didn't exist before — only ever built for Simulator,
   which doesn't need one) with "Sign In with Apple" capability checked.
   **Both Apple and Google Sign-In should now be fully configured
   end-to-end** — same caveat as Google though: real completion needs a
   human tapping through native system UI (Face ID/Apple ID prompt or a
   browser sheet), which QA's `integration_test` automation can't drive,
   so "no crash, correct buttons" is still the practical ceiling on
   automated verification here.
4. ~~**Unsplash API key**~~ **DONE** (commit `a7c2b20`) — user registered a
   free app, key is live in `lib/config/unsplash_config.dart`. Android
   cover generation is now fully functional (Demo tier, 50 req/hour — fine
   for testing, would need Unsplash's free "Production" approval before
   real-user launch). **All setup items from this section are now done.**
5. ~~**Bundle ID rename**~~ **DONE**, including the user-side Google Cloud
   Console edit (iOS OAuth client's Bundle ID field updated to
   `com.srigautham.waypoint`, confirmed by user).

Apple and Google Sign-In are both fully configured now (steps 1-3, 5 all
done) — only step 4 (Unsplash) remains, and it doesn't block anything
except Android cover photos, which just fall back to presets without it.
iOS cover generation is separately gated on real Apple Intelligence
hardware, unrelated to any of these steps — Simulator can't satisfy that
regardless.

## Git hygiene reminder

When staging: use explicit paths (`git add app/lib/... app/pubspec.yaml
docs/...`), never `git add app/` or `git add -A`, because the other
agent's `app/test/`, `app/test_report.json`, `app/run_tests_and_report.sh`
are untracked-but-intentional and not mine to commit.
