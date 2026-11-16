// P04 T5 (ADR-0058; p04-plan.md D4, D5, D8–D11, D15): the sync UI with a
// fake SyncService: the status under the profile, Settings → Sync, turning
// sync on (recovery key, passphrase), joining (merge, use the account's
// data with the export saved), undo, Changes to review, When to sync, the
// update notice, turning off and deleting the server copy.
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_sync.dart';
import 'fake_world.dart';
import 'nav.dart';

FakeWorld world({bool bound = true}) => FakeWorld(
      tasks: {'A': [task('t', 'A task')]},
      profiles: [profile('A', 'Dien', bound: bound, provider: bound ? 'github' : null)],
      activeId: 'A',
    );

Future<void> pumpApp(WidgetTester tester, FakeWorld w, SyncService? sync, {Size size = const Size(1000, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  if (sync is FakeSync) addTearDown(sync.dispose);
  await tester.pumpWidget(appWith(w, sync: sync));
  await tester.pumpAndSettle();
}

Future<void> openSync(WidgetTester tester) async {
  await goToTab(tester, 'Settings');
  // Through the position: a drag in the middle may land on a slider.
  final list = tester.state<ScrollableState>(find.byType(Scrollable).last).position;
  for (var i = 0; i < 20 && find.byKey(const Key('sync-settings')).evaluate().isEmpty; i++) {
    list.jumpTo((list.pixels + 400).clamp(0, list.maxScrollExtent));
    await tester.pumpAndSettle();
  }
  await tester.ensureVisible(find.byKey(const Key('sync-settings')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('sync-settings')));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('without sync in the build: Settings says so, no line under the profile', (tester) async {
    await pumpApp(tester, world(), null);
    await openSync(tester);
    expect(find.text('Sync is not available in this build of LifeFlow.'), findsOneWidget);
    expect(find.byKey(const Key('sync-switch')), findsNothing);
  });

  testWidgets('a guest is asked to sign in first', (tester) async {
    await pumpApp(tester, world(bound: false), FakeSync());
    await openSync(tester);
    expect(find.text('Sign in to an account to sync this profile.'), findsOneWidget);
    await tapKey(tester, 'sync-open-profiles');
    expect(find.byKey(const Key('account-card')), findsOneWidget);
  });

  testWidgets('the status is under the profile in the drawer, and follows the sync', (tester) async {
    final sync = FakeSync(on: true)
      ..lastResult = SyncOutcome.upToDate
      ..lastSyncAt = DateTime.now();
    await pumpApp(tester, world(), sync, size: const Size(400, 800));
    await openDrawer(tester);
    expect(find.descendant(of: find.byKey(const Key('drawer-sync-line')), matching: find.textContaining('Synced')),
        findsOneWidget);
    sync
      ..lastResult = SyncOutcome.offline
      ..pending = 2;
    sync.changed();
    await tester.pumpAndSettle();
    expect(find.text("Can't reach the server · will try again"), findsOneWidget);
    sync
      ..lastResult = SyncOutcome.updateNeeded
      ..reviewItems.add(SyncReviewView(
          id: 'r', recordKind: 'task', recordId: 't', reason: SyncReviewKind.changedOnBoth, field: 'notes', createdAt: DateTime(2026)));
    sync.changed();
    await tester.pumpAndSettle();
    expect(find.text('Update LifeFlow to keep syncing · 1 change to review'), findsOneWidget);
    sync.on = false;
    sync.changed();
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('drawer-sync-line')), findsNothing, reason: 'nothing when sync is off');
  });

  testWidgets('turning on with a recovery key: shown, saved, confirmed by two words', (tester) async {
    final w = world();
    final sync = FakeSync();
    await pumpApp(tester, w, sync);
    await openSync(tester);
    expect(find.text('Off · your data stays on this device'), findsNothing);
    await tapKey(tester, 'sync-switch');
    expect(find.text('How do you want to protect your data?'), findsOneWidget);
    await tapKey(tester, 'setup-recovery-key');
    expect(find.text('1. word1'), findsOneWidget);
    expect(find.text('24. word24'), findsOneWidget);
    expect(find.bySemanticsLabel('QR code of your recovery key'), findsOneWidget);
    await tapKey(tester, 'setup-save-key');
    expect(w.calls, contains('save:lifeflow-recovery-key.txt'));
    await tapKey(tester, 'setup-next');
    expect(find.text('Type words 3 and 17 of your recovery key.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setup-word-1')), 'word3');
    await tester.enterText(find.byKey(const Key('setup-word-2')), 'word18');
    await tapKey(tester, 'setup-turn-on');
    expect(find.text("Those words don't match. Check the words at those positions."), findsOneWidget);
    expect(sync.on, isFalse);
    await tester.enterText(find.byKey(const Key('setup-word-2')), 'word17');
    await tapKey(tester, 'setup-turn-on');
    expect(sync.on, isTrue);
    expect(find.text('Sync is on.'), findsOneWidget);
    expect(find.byKey(const Key('sync-now')), findsOneWidget);
    expect(sync.calls, ['prepare', 'offer', 'startKey:word3:word18', 'startKey:word3:word17']);
  });

  testWidgets('turning on with a passphrase: both must match; the minimum is explained', (tester) async {
    final sync = FakeSync();
    await pumpApp(tester, world(), sync);
    await openSync(tester);
    await tapKey(tester, 'sync-switch');
    await tapKey(tester, 'setup-passphrase');
    await tester.enterText(find.byKey(const Key('setup-pass-1')), 'short');
    await tester.enterText(find.byKey(const Key('setup-pass-2')), 'shorter');
    await tapKey(tester, 'setup-turn-on');
    expect(find.text('The two passphrases are not the same.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setup-pass-2')), 'short');
    await tapKey(tester, 'setup-turn-on');
    expect(find.text('Use at least 12 characters.'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('setup-pass-1')), FakeSync.passphrase);
    await tester.enterText(find.byKey(const Key('setup-pass-2')), FakeSync.passphrase);
    await tapKey(tester, 'setup-turn-on');
    expect(sync.on, isTrue);
  });

  testWidgets('offline before anything is set up: the problem and Try again', (tester) async {
    final sync = FakeSync()..prepareProblem = SyncSetupProblem.offline;
    await pumpApp(tester, world(), sync);
    await openSync(tester);
    await tapKey(tester, 'sync-switch');
    expect(find.text("Can't reach the server. Check your connection and try again."), findsOneWidget);
    sync.prepareProblem = null;
    await tapKey(tester, 'setup-retry');
    expect(find.text('How do you want to protect your data?'), findsOneWidget);
  });

  testWidgets('joining: merge is the default; a wrong key is refused', (tester) async {
    final sync = FakeSync(start: const SyncStartJoin(SyncUnlock.recoveryKey));
    await pumpApp(tester, world(), sync);
    await openSync(tester);
    await tapKey(tester, 'sync-switch');
    expect(find.text('Join your synced data'), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-key')), 'not the key');
    await tapKey(tester, 'join-submit');
    expect(find.text("That recovery key doesn't open this account's data."), findsOneWidget);
    await tester.enterText(find.byKey(const Key('join-key')), FakeSync.words.join(' '));
    await tapKey(tester, 'join-submit');
    expect(sync.calls.last, 'join:mergeThisDevice');
    expect(find.text('This device now syncs with your account.'), findsOneWidget);
  });

  testWidgets('joining with "use only the synced data": the export is saved; then undo', (tester) async {
    final w = world();
    final sync = FakeSync(start: const SyncStartJoin(SyncUnlock.passphrase));
    await pumpApp(tester, w, sync);
    await openSync(tester);
    await tapKey(tester, 'sync-switch');
    await tester.enterText(find.byKey(const Key('join-passphrase')), FakeSync.passphrase);
    await tapKey(tester, 'join-replace');
    await tapKey(tester, 'join-submit');
    expect(sync.calls.last, 'join:useAccountOnly');
    expect(w.calls, contains('save:before-sync.lifeflow.json'));
    expect(find.textContaining("This device's earlier data was saved to a file."), findsOneWidget);

    await tapKey(tester, 'sync-undo-join');
    await tapKey(tester, 'confirm-action');
    expect(sync.calls.last, 'undoJoin');
    expect(find.text('This device is back as it was before it joined.'), findsOneWidget);
  });

  testWidgets('Changes to review: keep, take the other, and a delete is only closed', (tester) async {
    final sync = FakeSync(on: true)..lastResult = SyncOutcome.upToDate;
    sync.reviewItems.addAll([
      SyncReviewView(
          id: 'n', recordKind: 'task', recordId: 't', reason: SyncReviewKind.changedOnBoth, field: 'notes',
          title: 'Pay the rent', kept: 'From A', other: 'From B', canTakeOther: true, createdAt: DateTime(2026)),
      SyncReviewView(
          id: 'd', recordKind: 'event', recordId: 'e', reason: SyncReviewKind.deletedAndEdited, field: 'deletedAt',
          title: 'Dentist', createdAt: DateTime(2026)),
      SyncReviewView(
          id: 's', recordKind: 'schedule', recordId: 'task:t', reason: SyncReviewKind.changedOnBoth, field: '*',
          kept: 'startDate: 2026-11-20', other: 'startDate: 2026-11-21', canTakeOther: true, createdAt: DateTime(2026)),
    ]);
    await pumpApp(tester, world(), sync);
    await openSync(tester);
    await tester.ensureVisible(find.byKey(const Key('review-n')));
    await tester.pumpAndSettle();
    expect(find.text('Task: Pay the rent'), findsOneWidget);
    expect(find.text('From A'), findsOneWidget);
    expect(find.text('From B'), findsOneWidget);
    expect(find.byKey(const Key('review-other-d')), findsNothing, reason: 'a delete is restored from the trash');
    expect(find.textContaining('restore it from the trash'), findsOneWidget);
    await tapKey(tester, 'review-other-n');
    await tapKey(tester, 'review-keep-d');
    await tapKey(tester, 'review-keep-s');
    expect(sync.calls, containsAllInOrder(['resolve:n:other', 'resolve:d:kept', 'resolve:s:kept']));
    expect(find.byKey(const Key('sync-no-reviews')), findsOneWidget);
  });

  testWidgets('When to sync, Sync now and the update notice', (tester) async {
    final w = world();
    final sync = FakeSync(on: true)
      ..lastResult = SyncOutcome.updateNeeded
      ..lastSyncAt = DateTime.now();
    await pumpApp(tester, w, sync);
    await openSync(tester);
    expect(find.text('Update LifeFlow'), findsOneWidget);
    await tapKey(tester, 'sync-when-manual');
    expect(w.calls, contains('syncWhen:onlySyncNow'));
    await tapKey(tester, 'sync-now');
    expect(sync.calls, contains('syncNow'));
    expect(find.text('Update LifeFlow'), findsNothing, reason: 'the sync was up to date');
  });

  testWidgets('turning off and deleting the server copy ask first', (tester) async {
    final sync = FakeSync(on: true)..lastResult = SyncOutcome.upToDate;
    await pumpApp(tester, world(), sync);
    await openSync(tester);
    await tapKey(tester, 'sync-delete-server');
    expect(find.text('Delete your data from the server?'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(sync.calls, isNot(contains('deleteServerData')));
    await tapKey(tester, 'sync-delete-server');
    await tapKey(tester, 'confirm-action');
    expect(sync.calls.last, 'deleteServerData');
    expect(find.text('Your data was deleted from the server.'), findsOneWidget);

    sync
      ..on = true
      ..changed();
    await tester.pumpAndSettle();
    await tapKey(tester, 'sync-switch');
    expect(find.text('Turn sync off?'), findsOneWidget);
    await tapKey(tester, 'confirm-action');
    expect(sync.calls.last, 'turnOff');
    expect(find.text('Sync is off. Your data stays on this device.'), findsOneWidget);
  });
}
