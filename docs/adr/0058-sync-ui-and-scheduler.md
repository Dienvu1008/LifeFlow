# ADR-0058: The sync UI and when sync runs

- Status: Accepted (P04 task T5, 2026-11-16)
- Date: 2026-11-16
- Deciders: Implementation, within the owner's decisions D4, D5, D8–D11, D15 of [p04-plan.md](../roadmap/p04-plan.md); owner decision 2026-11-16: no QR scanner
- Related: [ADR-0019](0019-ui-state-management-and-navigation.md), [ADR-0054](0054-sync-keys-recovery-key-and-passphrase.md), [ADR-0056](0056-sync-engine.md), [ADR-0057](0057-joining-and-leaving-sync.md), [ADR-0045](0045-ui-foundation-theme-density-i18n.md)

## Decision
1. **The sync status under the profile (D9).** The drawer header shows a line with a sync icon under "Signed in with …", and the rail's profile button includes it in its label. The line reads "Synced 10:42", "Syncing…", "1 change to send", "Can't reach the server · will try again", "Signed out · sign in to sync", "Update LifeFlow to keep syncing", "Set up again on another device · turn sync off and on", "The synced copy was deleted", "Sync failed · will try again", and adds "· N changes to review" when items wait. There is no line while sync is off. The status is live: `SyncService.watchStatus()` emits on every change to the outbox, the sync state, the review items and the join snapshot, and when a sync starts or ends.
2. **Settings → Sync** (`/settings/sync`):
   - The switch. Off → on opens the setup page; on → off asks first.
   - The status with "Sync now".
   - A notice for an update needed, a new key, or a deleted server copy.
   - "When to sync".
   - "Changes to review".
   - "Undo joining" (while possible).
   - "Delete my data from the server" (asks first).

   A guest profile, or one that is signed out, is asked to sign in first. A build without a Supabase project shows sync as unavailable (`syncServiceProvider` is null).
3. **Turning sync on (D5, D15).** The setup page asks the service what to do:
   - **New account:** the user chooses a recovery key (recommended) or a passphrase.
     - Recovery key: the 24 words are shown numbered with their QR code, can be saved to a text file, and are confirmed by typing two of them.
     - Passphrase: typed twice, at least 12 characters, not a common one.
   - **Account that already syncs:** the device joins with the 24 words (typed or pasted) or the passphrase. It chooses "Add it to the synced data" (the default) or "Use only the synced data". With the second, the export of this device's data is offered to save as a file right away.
   - **No QR scanner** (owner decision): `mobile_scanner` uses Google ML Kit on Android, which is under Google's terms, not an open-source license (VS-46). The QR code is for keeping the key on paper or a photo; typing the words always works.
4. **The views follow a join.** A join or its undo moves the profile to another workspace id. Every per-profile view read its workspace when it subscribed, so the UI invalidates the active profile after either, and every view subscribes again. The app integration test caught this: without it, the joined device showed only its own tasks until a restart.
5. **Changes to review (D6, D7, D9).** Each item shows the kind and the title (the record's own, or its task's or event's), the reason, the kept value and the other value. For a whole value (a schedule, a reminder, the settings), each value shows only the fields that differ.
   - "Keep this" closes the item.
   - "Take the other" (only for a value changed on both devices, on a record that is not in the trash) puts the other value back as a new change: version + 1 and a pending outbox row, through the new `SyncReviewHandler` command (`ResolveSyncReview`; FF-ARCH-06 steps added). It then syncs like any edit.
   - A delete against an edit can only be closed. The record is in the trash with the edits, and restoring it from the trash is the way back (D7), so a resolve cannot break the task hierarchy rules.
   - An unreadable record can only be closed.
6. **When sync runs (D8): `SyncScheduler`.** "When to sync" is a device setting (`sync.when` in the encrypted registry; not synced, not exported), read before every automatic sync. Automatic (the default) syncs at these moments:
   - when the profile opens (not awaited: opening never waits for the network, LF-INV-SEC-002);
   - when the app comes back to the front (`WidgetsBindingObserver` in the root);
   - 5 seconds after a change waits to be sent (the status shows pending changes and no sync running);
   - every 5 minutes while open;
   - after an offline or failed sync, again after `syncBackoff` (5 s, 15 s, 1 min, 5 min, then 15 min), with the count reset by the next success.

   An outcome only the user can fix (signed out, a new key, the server copy deleted, an update needed) gets no fast retries. "Only when I tap Sync now" turns all of this off. `syncNow()` waits for a running sync instead of starting a second one. The scheduler stops before the next profile opens and when the session closes, and starts again if a profile switch fails. Nothing runs while the app is closed.
7. **Wiring.** The app builds the `HttpRemoteGateway` from the build's Supabase URL and publishable key. Its access token comes from `SupabaseAuthGateway.accessTokenFor(account)`, which is refreshed when it is within a minute of expiry. The token is given only while the signed-in account is the profile's own bound account and the profile is not signed out. Otherwise the call is "signed out", so another account's session can never sync this profile. Workspace keys use the secure-storage slots of `secureKeyStoreFor` (`lifeflow.sync.key.<workspace>`).

## Rejected
- **A QR scanner** (above).
- **A device name in Settings → Sync** (listed in D9). Nothing would show it yet: there is no list of devices, and merges break ties with the device id. It is left for when a device list exists (P04b), and stated in the handoff.
- **Syncing in the background** after the app closes: Android and Windows limit background work (D8).
- **Polling the status on a timer**: the status follows the store's table updates instead.

## Consequences
- New strings in `app_en.arb` (`sy…`, FF-ARCH-10: no raw strings in the new files).
- New dependencies: `qr_flutter` 4.1.0 and `qr` 3.0.3 (BSD-3-Clause, in the license inventory, VS-46).
- The `SyncService` port gains `watchStatus`, `reviews` and `resolveReview`; `SettingsService` gains `syncWhen`/`setSyncWhen`; `SyncStatus` gains `syncing`; `SyncSetupProblem` gains `reviewGone`.
- Not covered headless: the token check against the real Supabase session (`accessTokenFor`) and the return-to-the-app hook. Both are part of the owner's two-device check in T6.
- Tests:
  - `sync_review_test.dart` (13): a notes conflict listed, kept, taken back and synced to the other device; a whole value taken back; a delete or an unreadable item only closed; the live status; one sync at a time; the device setting; the scheduler (start, after a change, Only Sync now, backoff and reset, sync off, stopped).
  - The review steps in `atomic_set_test.dart`.
  - `sync_flow_test.dart` (11 widget tests with a fake service): no sync in the build, a guest, the drawer line, recovery key shown, saved and confirmed, passphrase, offline then Try again, join with a wrong then the right key, use only the synced data with the export saved and undo, Changes to review, When to sync, Sync now and the update notice, turning off and deleting asked first.
  - An app integration test on real stores and the in-memory server: device A turns sync on with a recovery key through the UI; device B signs in, joins with the 24 words and shows both tasks.
- Mutations: 24 of 24 killed. This needed a test that an unreadable or delete item cannot be taken back on a live record, and one that the scheduler makes no call when sync is off. A duplicate stopped check was removed.

## T6 finding (2026-11-16): schema v12, the outbox key with the kind
On the owner's two devices, neither showed the other's tasks after "Sync now". The server held one workspace with the records of both devices, so the join and the upload had worked.
- **Cause.** An occurrence's exception and its completion have the same id (`task:<id>@<date>`). That happens for a habit occurrence that is moved or edited and then done. The outbox key was (operation, record id), so a pulled page holding both broke the key, and the whole page was refused (`UNIQUE constraint failed: outbox.operation_id, outbox.entity_id`). The same pair under one join or one restore would have hit the same error; the join's upload skipped the second row silently.
- **Second bug.** The store error was not a `RemoteFailure`, so it escaped `syncNow()` as an exception. "Sync now" showed nothing and the status kept its old result.
- **Fix:**
  - Schema v12: the outbox key is (operation, kind, record id). The upgrade rebuilds the table with its rows and index (`TableMigration`). The export's duplicate check uses the same key.
  - The engine reports any other error as `failed`, keeping only the error type: a store error can quote the values it was writing. The cursor does not move, because the page's transaction rolled back.
  - `DriftSyncService` writes every sync that is not up to date to the device's local log as `[sync] SyncReport(...)`, with counts only.
- **Sealed records still say schema 11.** `AppDatabase.recordSchemaVersion` is the last schema that changed a synced record. v12 changed only the local outbox, so a device on v11 still reads what a v12 device sends, without "Update LifeFlow".
- **Tests:**
  - The case reproduced: an occurrence moved and done reaches the other device.
  - An unexpected error is a failed sync with a log line, and the next sync goes on.
  - A v11 store upgrades with its outbox rows kept and accepts both kinds under one id; the v2–v11 upgrade loop covers the rest.
  - Mutations 2 of 2 killed.

## T6 finding 2 (2026-11-16): base64 line breaks from the server
After the v12 fix, the owner's "Sync now" on Windows logged `SyncReport(failed, pushed 0, pulled 0, ...) error: FormatException`.
- **Cause.** `pull_records` returns the sealed bytes with Postgres `encode(..., 'base64')`, which breaks the text into lines of 76 characters. Dart's `base64Decode` refuses the line breaks, so any record over 57 bytes could not be pulled: every real record. The contract test passed only because its test records were a few bytes long. This was most likely what both devices hit from the first sync on; the outbox key bug above was real too.
- **Fix.** `HttpRemoteGateway.pull` drops whitespace before decoding. No server change is needed.
- **Test.** A contract case pushes and pulls a 5000-byte record, on the in-memory server and on local Supabase (CI job `supabase-db`). It fails without the fix.
