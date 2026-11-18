# ADR-0065: Sharing UI and members' names (schema v15)

- Status: Accepted (P04b task T13, 2026-11-20)
- Date: 2026-11-20
- Deciders: The owner (members' names end to end: option (b), 2026-11-20; the T13 scope as proposed); implementation within B1–B14 of [p04b-plan.md](../roadmap/p04b-plan.md)
- Related: [ADR-0058](0058-sync-ui-and-scheduler.md), [ADR-0062](0062-space-keys.md), [ADR-0063](0063-space-sync.md), [ADR-0064](0064-sharing-commands.md)

## Context
The server knows members only by account id, and it cannot read an email address. The app needs people's names in several places:
- "Lan wants to join as Editor" (B7);
- the members list;
- "assigned to Minh" (B9);
- "changed by Minh, 10:42" (B10).

The owner chose **(b)**, names end to end, over two alternatives. (a) was plain names on the server. (c) was no names at all.

## Decision
1. **Names, end to end.** The server never sees a name.
   - **Asking to join.** The invitation preview gives the owner's public key. The joiner's device seals the profile's name for that key with X25519 + HKDF + AES-GCM (`sealNameFor`), binding it to the space and the sender. The sealed name goes with the request (`accept_invitation(p_code_hash, p_sealed_name)`) into `space_members.sealed_name`. Only the owner's devices open it, so the owner sees who is waiting.
   - **Members.** A name is a **member card**: a new record kind `memberCard` (schema v15, `member_cards`, id `<space>:<account>`). It is in `sharedSpaceKinds`, so it is sealed with the space key and synced like a task.
     - The owner's device writes the cards of the people it lets in, from their sealed names. It also catches up at each refresh, which covers "join at once" members and viewers, whose devices cannot write to a space.
     - An owner's or editor's own device writes its own card. A member may rename themselves (`setMyName`).
     - `MemberCardHandler` lets a member write only their own card, and the owner anyone's.
     - On pull, a card is taken only if its id matches its account.
   - **Limit:** editors can write records, and the server cannot see what a write changes. So a hostile editor's device could still overwrite a card, as it could any task. Names are as trustworthy as the space's editors.
   - Migration `20261120000001_member_names.sql`:
     - `space_members.sealed_name` (at most 1024 bytes);
     - `peek_invitation` returns `owner_public_key`;
     - `accept_invitation` takes the sealed name (optional, so an older app still joins).

     pgTAP `member_names.test.sql` (7). The contract test gains one case on memory and local Supabase.
2. **Ports and providers.**
   - `SharingService` gains `members()` as `SpaceMemberView` (name, role, status, "me"), plus `setMyName`, `memberNames`, `myAccountId` and `rulesOf`.
   - `TaskView` gains `assigneeId`, `changedBy` and `updatedAt`.
   - The UI gets these providers: `spaceServiceProvider`, `sharingServiceProvider` and `spaceSyncProvider` (nullable, as sync is), `spacesProvider`, `shownSharedSpaceProvider`, `canEditShownProvider`, `memberNamesProvider`, `spaceMembersProvider`, `rulesNoticesProvider` and `assignedToMeProvider`.
   - The app wires them in `openSession`. Spaces are always wired. Sharing and the space sync are wired with a server that is a `SpaceGateway`.
3. **The screens** (`screens/spaces_ui.dart`; all text from the ARB file, FF-ARCH-10):
   - **Switcher:** a "Spaces" section in the drawer (Personal, each space with your role, "New space…", "Join with a code…"), and a menu under the profile in the rail. Showing a space re-reads every view and syncs that space at once (B12).
   - **Space bar:** shown above the content while a shared space is shown: its name, your role and how many people, "View only" for a viewer, and what is left after leaving. A tap opens the details.
   - **Details:**
     - rename (owner) and your name in the space;
     - members: let in or turn down someone waiting (by name), change roles, make owner, remove;
     - invite: role and kind (the default from the rules; "join at once" warns), then the code in groups of five, a QR code of the `lifeflow://join/` link, the link, copy buttons, and the open invitations with cancel;
     - rules (owner sets; everyone reads; what the app cannot enforce is said);
     - the rules-changed notice ("Got it");
     - "Sync now", export (by the export rule), leave (with the leaving rule), delete (owner), "Remove this copy" (left).
   - **Join with a code:** a typed, pasted or linked code. The role, the kind and the rules are shown first (SHARE-005); then Join. There is no QR scanner, as decided in P04a.
   - **Move:** "Move to a space…" and "Move to Personal…" are in the menus of a list, a top-level task and an event in the Overview, in the goal page's menu, and in the calendars dialog. A confirmation lists what becomes visible (titles, notes, dates) and says reminders and tracking stay. A blocker is shown as the reason nothing moves.
   - **Task page:** "Assigned to" (owner or editor, or nobody) and "Changed by …, date time". The Overview has "Assigned to me": the tasks assigned to you, with their subtasks and the tasks above them.
   - **Viewers and left copies:** no "+" in the Overview or Goals, and no move entries. Writes are refused by the device and the server anyway, with a message.
4. **The space sync's scheduler** runs for a signed-in account, not only while a space is shown:
   - with Personal shown, it refreshes the spaces and gives a space never synced here its first sync, so its name and members' names are known before it is shown;
   - with a shared space shown, it syncs it (B12).

   `spacesProvider` re-reads after each status change, so a space someone let you into appears within a minute.

## Consequences
- The hosted project needs `20261120000001` (`db push --remote`) before T14. Without it, joining with a name fails, because the function takes no sealed name.
- Not done:
  - A `lifeflow://join/` link opening the app (OS deep links; a code or link pasted works).
  - Hiding every edit control from viewers. The main "+" buttons and moves are hidden; other edits are refused with a message.
  - Assignment on the event or calendar views.
- Tests:
  - `spaces_flow_test.dart` (13 widget tests):
    - drawer and rail;
    - the bar and "View only";
    - new; join, including an invalid code;
    - members: approve, roles, remove;
    - invite with QR and link;
    - rules and the notice;
    - leave and delete with a problem shown;
    - move with preview, and a blocked move;
    - assignee, "changed by", "Assigned to me".
  - App integration test (`shareThroughTheUi`), two accounts through the real UI on the in-memory server:
    1. Lan makes "Family", adds a task, invites;
    2. Minh asks to join (the rules shown first);
    3. Lan sees "Minh" and lets them in;
    4. Minh's device shows the space with the task.

    The server holds no title or name.
  - `sharing_test` names case: who waits is named for the owner only; cards for everyone; renaming oneself; a viewer writes nothing; only the owner names others; a forged card is not taken.
  - `space_keys_test`: a sealed name opens for its owner, space and sender only.
  - Suites: pgTAP 195; schema upgrade loop v2…v14; FF-ARCH-06/09 step `memberCard.create`.
- Mutations: 13 run one at a time; 12 killed, two of them after new tests (the card id check, and the name's binding to space and sender).
  - The one survivor is equivalent: a viewer's device skipping its own card. The write would be refused anyway.

## Amendment: the name is asked when joining (P04b T14 finding 1, 2026-11-04)

- Problem: the name sealed for the owner was the profile's display name. In practice profiles have none: the app gives a guest no name and has no place to set one. Owners and editors could still use "Your name in this space", but a viewer cannot write to the space, so a viewer stayed "A member" for everyone.
- Decision (the owner chose to fix it before the device run): the "Join a space" dialog asks "Your name in this space" after the role and the rules, filled with the profile's name if it has one. The name is required in the dialog and at most 60 characters, as a member card. `SharingService.join(text, {name})` seals the typed name for the owner; without one, the profile's name, as before. Nothing changes on the server or in the schema.
- Rejected: a profile-name setting (a larger change outside sharing, and it would still leave old profiles empty); asking for the name at sign-in (not every profile shares).
- Tests: `sharing_test` "T14 finding 1" (a typed name wins; a blank one falls back to the profile's; 61 characters refused); `spaces_flow_test` (the field starts with the profile's name; a blank name is refused before anything is sent; the trimmed name is sent); `shareThroughTheUi` (the field holds the profile's name).
- Mutations: 8 run one at a time, all killed.

## Amendment 2: a space's "Changes to review" (P04b T14 finding 2, 2026-11-04)

- Problem (found in the owner's two-person run, step 10): notes changed by two people offline merged as SYNC-003 says (the newer change kept, a review item written in the space), but nothing showed the item. The only list was the personal sync's (Settings → Sync), which reads the personal workspace's items, and the space sync (`SyncRunner`) could not list or close its own.
- Decision:
  - A new port, `SpaceSyncRunner` (`SyncRunner` with `reviews()` and `resolveReview()`), which `DriftSpaceSyncService` implements. It lists the shown space's open items. It closes one with the same `SyncReviewHandler` the personal sync uses, run as the member: taking the other value back is an edit in the space, so a viewer cannot do it and "changed by" names who did.
  - The UI says it where the space is: the space bar adds "1 change to review", and the space page shows the items at the top with "Keep this" and "Take the other". The personal sync screen's card is now `ReviewCard`, shared by both.
  - The review view (`syncReviewViewOf`) moved out of `DriftSyncService` so both syncs build it the same way.
- Rejected: listing the space's items in Settings → Sync (that screen is the personal sync's, and taking a value back must happen as the member in the space); a list of every space's items at once (the space sync syncs only the shown space, B12).
- Tests: `space_sync_test` "T14 finding 2" (the second device to sync has the item; "Take the other" puts the other notes back, as the member, and they reach the first device; a closed item cannot be closed again; with the personal workspace shown, no space items); `spaces_flow_test` (the bar says it; the page lists it; "Take the other" closes it).
- Mutations: 12 run one at a time, all killed.
