# P04b T14: two people on real devices

The owner's check of sharing on the hosted project (`dudcmcjuxyvjgjcrvsfd`) with two accounts: account A (the owner's) on Windows, account B on Android. The build is `main` at `cb8d8c4` or later. Plan row: [p04b-plan.md](../roadmap/p04b-plan.md) T14. Status: **in progress**.

Migrations on the hosted project: `20261117000001_spaces.sql`, `20261118000001_record_key_id.sql`, `20261120000001_member_names.sql` (pushed by the owner; the agent checked on 2026-11-04 that `space_members.sealed_name` and `accept_invitation(p_code_hash, p_sealed_name)` exist).

## Setup

- Account B: the hosted project confirms email sign-ups by email (`mailer_autoconfirm` is off), and the built-in email reaches only the project's team, and the app has no sign-up screen. So B is made in the dashboard: Authentication → Users → Add user → Create new user, with "Auto Confirm User".
- Windows: A, signed in, sync on (as after P04a).
- Android: Profiles → "Sign out" (A's profile is locked, its data kept). Then "Sign in" with B's email and password. If asked "Move your data to this account?", choose "New space" (a new profile for B). Then Settings → Sync → turn sync on with a recovery key. A space needs the account's keys, and they come with sync (B5).
- Both: "When to sync" is "Automatic".

Known limits for this run (ADR-0065): the `lifeflow://join/` link and the QR do not open the app (the code is pasted); the owner's members list is read when the space page opens or on its "Sync now"; not every edit control is hidden for a viewer (the change is refused).

## Steps and results

| # | Step | Expected | Result |
|---|---|---|---|
| 1 | A: drawer → "New space…" → a name → "Create" | The space is shown; the space bar says "Owner · 1 person" | |
| 2 | A: space bar → "Invite someone": Editor, "I approve who joins" → "Make the invitation"; copy the code to Android | Code, link and QR; "For one person, valid for 7 days." | |
| 3 | B: drawer → "Join with a code…" → paste → "Look" → type B's name in "Your name in this space" → "Join" | "You are invited as Editor.", the rules; without a name, "Type your name…"; then "You asked to join. The owner lets you in." | |
| 4 | A: space page → "Sync now" → B "Asks to join · Editor" → "Let in" | B becomes an editor | |
| 5 | B: wait, or return to the app | The space appears in B's drawer as Editor (time it) | |
| 6 | B and A: space page → "Your name in this space" | After a sync each sees the other's name under Members | |
| 7 | A: a personal task → "Move to a space…" → "Move" | The dialog lists what moves; B sees the task (time it) | |
| 8 | B: rename it and tick it done | A sees both (time it); A's task page says "Changed by …" | |
| 9 | Space page "Sync now" on both sides after an edit | The change is there at once (time it) | |
| 10 | Android offline: both change the same task's notes; Android online; "Sync now" on both | A "Changes to review" item; "Keep this" / "Take the other" works; both end the same | |
| 11 | A: task page → "Assigned to" → B | B: Overview → "Assigned to me" shows the task | |
| 12 | A: Members → B → "Make Viewer" | B within 1 minute: "View only"; no add buttons; a change is refused and A sees nothing change | |
| 13 | A: "Make Editor" | B can edit again | |
| 14 | A: Rules → "Who can export" → "Every member" | B sees "The owner changed the rules of …" with "Got it" | |
| 15 | A: remove B (rule "The space disappears") | B within 1 minute: the space is gone from the drawer; B's personal data is untouched | |
| 16 | B: the code from step 2 again | "That code is not valid: it was used, cancelled or has expired." | |
| 17 | A: rule "They keep a read-only copy"; invitation "Join at once"; B joins | B is in at once, with no approval | |
| 18 | A: remove B again | B keeps a read-only copy ("A read-only copy: you are no longer in this space"); "Remove this copy" removes it | |
| 19 | Android: sign out B; "Sign in to open" A's profile | A's personal data is back on Android, and syncs | |

## How soon changes appear (B12)

Expected: sent about 5 s after the change; the other device gets it within 1 minute while the app is open (the space shown), at once on its "Sync now" or on return to the app.

| Change | Measured |
|---|---|
| Approval → the space on B (step 5) | |
| A's change → B (step 7) | |
| B's change → A (step 8) | |
| With "Sync now" (step 9) | |
| Role change → B (step 12) | |
| Removal → B (step 15) | |

## Findings

1. **A member's name is empty at joining.** The name sealed for the owner (ADR-0065) is the profile's display name, and profiles get none in practice (the app passes no name to a guest and has no way to set one). Owners and editors can set "Your name in this space"; a viewer cannot, so a viewer shows as "A member". Found while preparing this run. **Fixed before the run** (the owner's choice, 2026-11-04): "Join a space" asks "Your name in this space", filled with the profile's name if any ([ADR-0065 amendment](../adr/0065-sharing-ui-and-member-names.md)).
