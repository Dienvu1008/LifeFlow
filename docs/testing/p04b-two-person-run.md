# P04b T14: two people on real devices

The owner's check of sharing on the hosted project (`dudcmcjuxyvjgjcrvsfd`) with two accounts: account A (the owner's) on Windows, account B on Android. The build is the branch `p04b/t14-two-person-run` at `c987efa` (finding 1 fixed). Plan row: [p04b-plan.md](../roadmap/p04b-plan.md) T14. Status: **run by the owner 2026-11-04; finding 2 fixed, step 10 to run again**.

Migrations on the hosted project: `20261117000001_spaces.sql`, `20261118000001_record_key_id.sql`, `20261120000001_member_names.sql` (pushed by the owner; the agent checked on 2026-11-04 that `space_members.sealed_name` and `accept_invitation(p_code_hash, p_sealed_name)` exist).

## Setup

- Account B: the hosted project confirms email sign-ups by email (`mailer_autoconfirm` is off), and the built-in email reaches only the project's team, and the app has no sign-up screen. So B is made in the dashboard: Authentication → Users → Add user → Create new user, with "Auto Confirm User".
- Windows: A, signed in, sync on (as after P04a).
- Android: Profiles → "Sign out" (A's profile is locked, its data kept). Then "Sign in" with B's email and password. If asked "Move your data to this account?", choose "New space" (a new profile for B). Then Settings → Sync → turn sync on with a recovery key. A space needs the account's keys, and they come with sync (B5).
- Both: "When to sync" is "Automatic".

Known limits for this run (ADR-0065): the `lifeflow://join/` link and the QR do not open the app (the code is pasted); the owner's members list is read when the space page opens or on its "Sync now"; not every edit control is hidden for a viewer (the change is refused).

## Steps and results

| # | Step | Expected | Result (owner, 2026-11-04) |
|---|---|---|---|
| 1 | A: drawer → "New space…" → a name → "Create" | The space is shown; the space bar says "Owner · 1 person" | as expected |
| 2 | A: space bar → "Invite someone": Editor, "I approve who joins" → "Make the invitation"; copy the code to Android | Code, link and QR; "For one person, valid for 7 days." | as expected |
| 3 | B: drawer → "Join with a code…" → paste → "Look" → type B's name in "Your name in this space" → "Join" | "You are invited as Editor.", the rules; without a name, "Type your name…"; then "You asked to join. The owner lets you in." | as expected |
| 4 | A: space page → "Sync now" → B "Asks to join · Editor" → "Let in" | B becomes an editor | as expected |
| 5 | B: wait, or return to the app | The space appears in B's drawer as Editor (time it) | under 1 s |
| 6 | B and A: space page → "Your name in this space" | After a sync each sees the other's name under Members | as expected |
| 7 | A: a personal task → "Move to a space…" → "Move" | The dialog lists what moves; B sees the task (time it) | about 10 s |
| 8 | B: rename it and tick it done | A sees both (time it); A's task page says "Changed by …" | about 45 s |
| 9 | Space page "Sync now" on both sides after an edit | The change is there at once (time it) | Sync now on Windows: on Android at once. Sync now on Android: on Windows about 20 s later |
| 10 | Android offline: both change the same task's notes; Android online; "Sync now" on both | A "Changes to review" item; "Keep this" / "Take the other" works; both end the same | **no review shown**; both ended with one side's notes (finding 2) |
| 11 | A: task page → "Assigned to" → B | B: Overview → "Assigned to me" shows the task | as expected |
| 12 | A: Members → B → "Make Viewer" | B within 1 minute: "View only"; no add buttons; a change is refused and A sees nothing change | as expected |
| 13 | A: "Make Editor" | B can edit again | as expected |
| 14 | A: Rules → "Who can export" → "Every member" | B sees "The owner changed the rules of …" with "Got it" | as expected |
| 15 | A: remove B (rule "The space disappears") | B within 1 minute: the space is gone from the drawer; B's personal data is untouched | as expected |
| 16 | B: the code from step 2 again | "That code is not valid: it was used, cancelled or has expired." | as expected |
| 17 | A: rule "They keep a read-only copy"; invitation "Join at once"; B joins | B is in at once, with no approval | as expected |
| 18 | A: remove B again | B keeps a read-only copy ("A read-only copy: you are no longer in this space"); "Remove this copy" removes it | as expected |
| 19 | Android: sign out B; "Sign in to open" A's profile | A's personal data is back on Android, and syncs | as expected |

## How soon changes appear (B12)

Expected: sent about 5 s after the change; the other device gets it within 1 minute while the app is open (the space shown), at once on its "Sync now" or on return to the app.

| Change | Measured |
|---|---|
| Approval → the space on B (step 5) | under 1 s |
| A's change → B (step 7) | about 10 s |
| B's change → A (step 8) | about 45 s |
| With "Sync now" (step 9) | Windows → Android at once; Android → Windows about 20 s |

**The owner's decision (2026-11-04): the 1-minute delay is acceptable; Realtime is left for later.** Every time is within B12's 1 minute. A "Sync now" sends this device's changes and fetches the others' at once. It does not tell the other device, which fetches at its next minute (or when it returns to the app, or on its own "Sync now"). So 0–60 s on the other side is the design, and the times above (under 1 s to 45 s) are where each change fell in that minute. Step 9's difference between the two directions has the same cause. B12's alternative (Supabase Realtime as a "something changed" signal) is for the owner to decide if a minute is too slow.

## Findings

1. **A member's name is empty at joining.** The name sealed for the owner (ADR-0065) is the profile's display name, and profiles get none in practice (the app passes no name to a guest and has no way to set one). Owners and editors can set "Your name in this space"; a viewer cannot, so a viewer shows as "A member". Found while preparing this run. **Fixed before the run** (the owner's choice, 2026-11-04): "Join a space" asks "Your name in this space", filled with the profile's name if any ([ADR-0065 amendment](../adr/0065-sharing-ui-and-member-names.md)).
2. **A shared space's "Changes to review" were never shown (step 10).** The merge did its part: notes changed on both sides kept the newer change and wrote a review item in the space (SYNC-003). But the only "Changes to review" list was the personal sync's (Settings → Sync), which reads the personal workspace's items, and the space sync had no way to list or close its own. So the item was there and nobody saw it. Reproduced headless (`space_sync_test` "T14 finding 2": the second device to sync has one item, kept "By train", other "By bus"). **Fixed** (2026-11-04, [ADR-0065 amendment 2](../adr/0065-sharing-ui-and-member-names.md)): the space bar says "1 change to review", and the space page lists the items with "Keep this" and "Take the other". To run again: step 10.
   - **Run again by the owner (2026-11-04), from `1c208d1`:** the same: both ended with the notes of the device that synced first, and no item was seen ("Nothing to review." was shown; that text is only on Settings → Sync, the personal sync's list). The agent then checked the real stack: `space_sync_supabase_e2e_test` "T14 step 10" (local Supabase, the real HTTP gateway, two accounts) gives the later device one item with both notes, and "Take the other" reaches the first device. So the engine, the server and the review list work; open: whether the run made a true conflict. Two edits conflict only if both start from the same version. If Windows pulled Android's notes (its 1-minute sync) before its own edit, that edit comes after Android's and simply replaces it, which is right and gives no review. To run again with both devices offline while editing (below).
