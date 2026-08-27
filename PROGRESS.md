# Waypoint — Progress Log

Living status file for this session's work. Review this whenever context is
unclear (e.g. after a compaction/restart) before assuming project state.

Repo: https://github.com/Sri-Gautham/waypoint-app (private)
Local path: `/Users/srigautham/Documents/My Projects/Personal Projects/travel-companion-app`

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
2. ~~**Supabase dashboard** (Google)~~ **DONE**, see above. **Apple still
   needs its own dashboard entry** (Authentication > Providers > Apple) —
   not yet done as of this writing.
3. **Apple Developer portal** — the `DEVELOPMENT_TEAM` (C8M2XYZHB3) is
   already set in the project, and the entitlement is wired. **App ID
   didn't exist there at all yet** (only ever built for Simulator, which
   doesn't need one) — user tried creating it manually with the old bundle
   ID and hit "not available" (already taken by someone else's app on a
   different account, `com.waypoint.waypoint` being generic enough to
   collide) — resolved by the bundle ID rename, item 5. Still needs: create
   the App ID fresh under the NEW bundle id with "Sign In with Apple"
   capability checked, then the Apple-side Service ID / key for Supabase's
   Apple provider config (item 2).
4. **Unsplash API key** (Android covers) — register a free app at
   https://unsplash.com/oauth/applications, paste the Access Key into
   `lib/config/unsplash_config.dart` (currently empty — Android cover
   generation silently falls back to presets until this is filled in).
5. **Bundle ID rename**: `com.waypoint.waypoint` -> `com.srigautham.waypoint`
   (user's choice, prompted by the Apple identifier collision in item 3).
   Done on my end: `PRODUCT_BUNDLE_IDENTIFIER` in `project.pbxproj` (all 6
   Runner/RunnerTests config entries), Android `namespace`/`applicationId`
   in `build.gradle.kts`, `MainActivity.kt`'s package + its directory moved
   to match (`android/.../kotlin/com/srigautham/waypoint/`), both
   MethodChannel name strings (Dart + Swift, must match each other exactly
   — arbitrary string, didn't strictly need to change, renamed for
   consistency), and this file's own references. **Still needs, user-side**:
   edit the existing iOS OAuth client in Google Cloud Console (Credentials
   > that iOS client > Bundle ID field) from the old value to
   `com.srigautham.waypoint` — Google's iOS SDK checks this at sign-in time,
   so leaving it stale would break Google Sign-In on iOS again.

None of the above block iOS Simulator testing of the rest of the app —
the Apple button will fail to complete sign-in until steps 2-3 are done
(existing account UX degrades to "sign-in failed, try again", no crash),
and Android cover generation will fall back to presets until step 4 is
done (iOS cover generation is separately gated on real Apple Intelligence
hardware, unrelated to any of these steps — Simulator can't satisfy that
regardless).

## Git hygiene reminder

When staging: use explicit paths (`git add app/lib/... app/pubspec.yaml
docs/...`), never `git add app/` or `git add -A`, because the other
agent's `app/test/`, `app/test_report.json`, `app/run_tests_and_report.sh`
are untracked-but-intentional and not mine to commit.
