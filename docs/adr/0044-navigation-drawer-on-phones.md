# ADR-0044: A navigation drawer on phones, with the profile as its header

- Status: Accepted (owner request, 2026-11-11, during the P03 exit review)
- Date: 2026-11-11
- Deciders: Project owner
- Related: [ui-ux-architecture.md](../architecture/ui-ux-architecture.md) §2 (amended), [ADR-0019](0019-ui-state-management-and-navigation.md), p03-plan.md D12, [ADR-0042](0042-focus-ui-bar-notification-recovery.md) (focus bar)

## Context
In the compact layout (window narrower than 600 dp, phones) the five tabs were in a bottom navigation bar. With the focus bar (D4), a bottom bar takes a lot of the phone's height. The owner asked for the tabs in a navigation drawer, with Profiles first, as the drawer's header with the profile's picture.

## Decision
- **Compact layout:**
  - No bottom bar. The tabs are in a Material 3 **navigation drawer**, opened with the menu button at the start of each tab's app bar (tooltip "Open navigation menu") or by swiping from the left edge.
  - **Header:** the active profile, with a round picture (the initials until profiles have a photo), the name and how it is signed in ("Guest · on this device", "Signed in with GitHub", "Signed out of …"). A tap opens Profiles. It is one spoken button: "Profile: <name>, <status>. Open profiles".
  - **Destinations,** in order: Tasks, Calendar, Goals, Settings. The current one is marked; on Profiles none is. Choosing one closes the drawer.
- **Medium and expanded layouts** (tablets, Windows) are unchanged: the navigation rail keeps all five destinations, Profiles included, and there is no menu button.
- **Unchanged:** the routes, the branch order and the indexes (Tasks 0, Calendar 1, Goals 2, Profiles 3, Settings 4). Pages opened on top (editors, habit, focus and goal pages) keep their own Close or Back button. The focus bar stays at the bottom of the content.
- **Implementation:** `AdaptiveScaffold` owns the drawer; a `ShellMenuScope` lets a tab's app bar add the menu button (`shellMenuButton(context)`). The UI stays on application ports only (FF-ARCH-04).

## Consequences
- On a phone, switching tabs takes two taps instead of one; the content gains the bar's height.
- A profile photo needs a stored image per profile (not in the MVP); the header already has its place.

## Verification
- `packages/ui/test/shell_test.dart`:
  - compact has a drawer, with no bottom bar and no rail;
  - the header is first, with picture, name and status (guest and signed in), and one spoken label;
  - each destination and the header report their index, and the drawer closes;
  - the current tab is marked, and none is on Profiles;
  - rails have no menu button; resizing switches the layout.
- Phone-width flows reach their tabs through the drawer: the calendar flows, Goals with a large font, and the storage banner on a phone (shared `test/nav.dart`). All 186 UI tests and 25 app tests pass.
- Device check: in the owner's P03 device pass.

- **Amended by [ADR-0050](0050-navigation-habits-and-manual-results.md) (2026-11-13):** six destinations (Overview, Timeline, Calendar, Habits, Goals, Settings); the profile is also on top of the rail.
