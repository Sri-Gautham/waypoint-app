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
- Bundle id: `com.waypoint.waypoint`.

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
- **Onboarding** (`lib/screens/onboarding/`): 5 steps (Create account,
  Verify email, Verify phone, Home address, All set) as real Flutter
  widgets. `OnboardingData` model holds the form state, passed through to
  `MainShell` on "Get started".
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

## IN PROGRESS RIGHT NOW — do not lose this

Refactoring from static `Trip.all` (a const list) to a shared, mutable
app-wide state object, because **group creation** (the next feature) needs
to be able to add a new trip that shows up everywhere (Home, Trips tab,
Balances tab) — static data can't support that.

- **Created** `lib/state/app_data.dart`: `AppData extends ChangeNotifier`
  (holds `trips`, `chargesByTrip`, `payments`; methods `addTrip`,
  `addCharge`, `addPayment`, all calling `notifyListeners()`) +
  `AppDataScope extends InheritedNotifier<AppData>` with a static `.of(context)`.
  **Important**: `AppDataScope` is wired in `main.dart` ABOVE
  `MaterialApp` (wrapping it, not inside a route) — this is deliberate,
  because an `InheritedWidget` placed inside one route's subtree does NOT
  propagate to sibling routes pushed via the same `Navigator`. It must sit
  above the `Navigator` (i.e. above `MaterialApp`) so every pushed screen
  can reach it.
- **Done**: `main.dart` now a `StatefulWidget` (`_WaypointAppState`)
  holding one `AppData` instance, wraps `MaterialApp` in `AppDataScope`.
- **Done**: `HomeTab` now reads `AppDataScope.of(context).nextTrip`
  instead of the old `Trip.sampleNextTrip`; "Create a group" button now
  navigates to `CreateGroupFlow` (not yet created — see below).
- **Done**: `TripsTab` now reads `appData.upcoming` / `appData.past`
  instead of static `Trip.upcoming` / `Trip.past`.
- **Done**: `BalancesTab` migrated off local `_chargesByTrip`/`_payments`
  State fields onto `AppDataScope.of(context)` — `_addExpense` now calls
  `appData.addCharge(...)` instead of local `setState`; `_openBalancesByPerson`
  no longer passes data via constructor (just pushes the route).
- **IN PROGRESS, NOT YET DONE**: `balances_by_person_screen.dart` still
  has the OLD constructor signature (`chargesByTrip`, `payments`,
  `tripNames` as required params) and reads `widget.chargesByTrip` /
  `widget.payments` / `widget.tripNames` throughout. **Next action**:
  rewrite it to take NO constructor params, read
  `AppDataScope.of(context)` directly in `build()`, and derive
  `tripNames` from `appData.trips` instead of a passed-in map. The call
  site in `balances_tab.dart` (`_openBalancesByPerson`) has ALREADY been
  updated to call `const BalancesByPersonScreen()` with no args, so this
  file is currently broken/non-compiling until the rewrite is finished.

### Not started yet (planned)

- `lib/screens/group/create_group_flow.dart` + `lib/screens/group/steps/`
  (basics/destination/invite, 3-step wizard) + a `GroupDraft` model +
  `lib/data/sample_contacts.dart` — matching the design prototype's group
  creation flow. On completion: build a new `Trip`, call
  `AppDataScope.of(context).addTrip(...)`, navigate into its
  `TripDetailScreen`.
- After that: run `flutter analyze lib`, verify on simulator (temporary
  main.dart swap + video capture method), revert main.dart, commit only
  `app/lib/` files (never sweep in the other agent's `app/test/` files
  with a broad `git add app/`), push.
- Update `docs/QA_CHECKLIST.md` with a new "Group creation" section once
  built.

## Git hygiene reminder

When staging: use explicit paths (`git add app/lib/... app/pubspec.yaml
docs/...`), never `git add app/` or `git add -A`, because the other
agent's `app/test/`, `app/test_report.json`, `app/run_tests_and_report.sh`
are untracked-but-intentional and not mine to commit.
