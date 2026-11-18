// P04b T13 (ADR-0065; p04b-plan.md B1–B14): the sharing UI with fake ports.
//   switcher  the spaces in the drawer and in the rail; showing one syncs it
//   bar       name, role, people; "View only" for a viewer; no "+" there
//   new/join  a named space; a code: the role and the rules first, then join
//   details   members (approve, roles, remove, hand over), invite (code, QR,
//             link), rules (owner sets; the notice), export, leave, delete
//   move      "Move to a space…": what becomes visible, then it moves
//   task      assigned to, changed by; "Assigned to me"
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_spaces.dart';
import 'fake_world.dart';
import 'nav.dart';

FakeWorld world({List<TaskView>? tasks}) => FakeWorld(
      tasks: {'A': tasks ?? [task('t', 'A task')]},
      profiles: [profile('A', 'Dien', bound: true, provider: 'github')],
      activeId: 'A',
    );

Future<void> pumpApp(WidgetTester tester, FakeWorld w, FakeSpaces s, {Size size = const Size(1000, 1000)}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w, spaces: s, sharing: s, spaceSync: s));
  await tester.pumpAndSettle();
}

Future<void> tapKey(WidgetTester tester, String key) async {
  final f = find.byKey(Key(key));
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
  await tester.tap(f);
  await tester.pumpAndSettle();
}

SpaceView shownAs(SpaceView s, {SpaceRole? role, SpaceLeft left = SpaceLeft.no, bool rulesChanged = false}) => SpaceView(
    id: s.id, shared: s.shared, isShown: true, name: s.name, role: role ?? s.role, members: s.members, left: left,
    rulesChanged: rulesChanged);

const personalHidden = SpaceView(id: 'personal', shared: false, isShown: false);

void main() {
  testWidgets('the drawer lists the spaces; showing one shows its bar and syncs it at once (B1, B12)', (tester) async {
    final s = FakeSpaces(spaces: [personalShown, family]);
    await pumpApp(tester, world(), s, size: const Size(400, 800));
    await openDrawer(tester);
    expect(find.byKey(const Key('drawer-spaces')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('drawer-spaces')), matching: find.text('Personal')), findsOneWidget);
    expect(find.descendant(of: find.byKey(const Key('drawer-spaces')), matching: find.text('Owner')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('space-fam')));
    await tester.pumpAndSettle();
    expect(s.calls, containsAllInOrder(['show:fam', 'spaceSync']));
    expect(find.byKey(const Key('space-bar')), findsOneWidget);
    expect(find.textContaining('Owner · 2 people'), findsOneWidget);
  });

  testWidgets('in the rail the spaces are a menu under the profile', (tester) async {
    final s = FakeSpaces(spaces: [personalShown, family]);
    await pumpApp(tester, world(), s);
    await tester.tap(find.byKey(const Key('rail-spaces')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('rail-space-fam')));
    await tester.pumpAndSettle();
    expect(s.calls, contains('show:fam'));
    expect(find.byKey(const Key('space-bar')), findsOneWidget);
  });

  testWidgets('a viewer: "View only", and nothing to add (B4)', (tester) async {
    final s = FakeSpaces(spaces: [personalHidden, shownAs(family, role: SpaceRole.viewer)]);
    await pumpApp(tester, world(), s);
    expect(find.textContaining('View only'), findsOneWidget);
    expect(find.byKey(const Key('add-menu')), findsNothing);
  });

  testWidgets('T14 finding 2: a change to review in the space: said on its bar, closed on its page (SYNC-003)',
      (tester) async {
    final s = FakeSpaces(spaces: [personalHidden, shownAs(family)])
      ..reviewItems = [
        SyncReviewView(
            id: 'rv1', recordKind: 'task', recordId: 't', reason: SyncReviewKind.changedOnBoth, field: 'notes',
            title: 'Plan the trip', kept: 'By train', other: 'By bus', canTakeOther: true, createdAt: DateTime.utc(2026, 11, 4)),
      ];
    await pumpApp(tester, world(), s);
    expect(find.textContaining('1 change to review'), findsOneWidget);
    await tapKey(tester, 'space-bar');
    expect(find.byKey(const Key('space-reviews')), findsOneWidget);
    expect(find.text('By train'), findsOneWidget);
    expect(find.text('By bus'), findsOneWidget);
    await tapKey(tester, 'review-other-rv1');
    expect(s.calls, contains('resolve:rv1:other'));
    expect(find.byKey(const Key('space-reviews')), findsNothing);
  });

  testWidgets('a new space is named and shown', (tester) async {
    final s = FakeSpaces();
    await pumpApp(tester, world(), s, size: const Size(400, 800));
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('space-new')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Family');
    await tester.tap(find.widgetWithText(FilledButton, 'Create'));
    await tester.pumpAndSettle();
    expect(s.calls, contains('create:Family'));
    expect(find.text('The space is ready. Invite someone from its details.'), findsOneWidget);
    expect(find.byKey(const Key('space-bar')), findsOneWidget);
  });

  testWidgets('join with a code: the role and the rules first, then join (SHARE-005)', (tester) async {
    final s = FakeSpaces()
      ..invitation = const InvitationPreview(
          workspaceId: 'fam', role: SpaceRole.editor, kind: InviteKind.approve, leave: LeaveRule.keepReadOnly,
          export: ExportRule.ownerOnly);
    await pumpApp(tester, world(), s, size: const Size(400, 800));
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('space-join')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-space-code')), 'lifeflow://join/ABC');
    await tapKey(tester, 'join-space-look');
    expect(find.text('You are invited as Editor.'), findsOneWidget);
    expect(find.text('If you leave or are removed, you keep a read-only copy of what was there.'), findsOneWidget);
    expect(find.textContaining('screenshots'), findsOneWidget, reason: 'what the app cannot enforce is said');
    // T14 finding 1: the profile's name to start with; a name is needed.
    final nameField = find.byKey(const Key('join-space-name'));
    expect(tester.widget<TextField>(nameField).controller!.text, isNotEmpty);
    await tester.enterText(nameField, ' ');
    await tapKey(tester, 'join-space-join');
    expect(find.text('Type your name: the others in the space will know you by it.'), findsOneWidget);
    expect(s.calls.where((c) => c.startsWith('join:')), isEmpty);
    await tester.enterText(find.byKey(const Key('join-space-name')), '  Vy  ');
    await tapKey(tester, 'join-space-join');
    expect(s.calls, containsAllInOrder(['peek:lifeflow://join/ABC', 'join:lifeflow://join/ABC:Vy']));
    expect(find.text('You asked to join. The owner lets you in.'), findsOneWidget);
  });

  testWidgets('a code that is not valid says so', (tester) async {
    final s = FakeSpaces();
    await pumpApp(tester, world(), s, size: const Size(400, 800));
    await openDrawer(tester);
    await tester.tap(find.byKey(const Key('space-join')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('join-space-code')), 'nope');
    await tapKey(tester, 'join-space-look');
    expect(find.byKey(const Key('join-space-problem')), findsOneWidget);
    expect(find.textContaining('That code is not valid'), findsOneWidget);
  });

  testWidgets('details: who waits is named; the owner lets them in, changes roles, removes', (tester) async {
    final s = FakeSpaces(spaces: [personalHidden, shownAs(family)])
      ..memberLists = {
        'fam': const [
          SpaceMemberView(accountId: 'acc-me', name: 'Dien', role: SpaceRole.owner, status: MemberStatus.active, isMe: true),
          SpaceMemberView(accountId: 'acc-lan', name: 'Lan', role: SpaceRole.editor, status: MemberStatus.pending, isMe: false),
          SpaceMemberView(accountId: 'acc-minh', name: 'Minh', role: SpaceRole.editor, status: MemberStatus.active, isMe: false),
        ]
      };
    await pumpApp(tester, world(), s);
    await tester.tap(find.byKey(const Key('space-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('space-page')), findsOneWidget);
    expect(find.text('Dien (you)'), findsOneWidget);
    expect(find.text('Asks to join · Editor'), findsOneWidget);
    await tapKey(tester, 'member-approve-acc-lan');
    expect(s.calls, contains('approve:acc-lan'));
    await tapKey(tester, 'member-menu-acc-minh');
    await tester.tap(find.text('Make Viewer'));
    await tester.pumpAndSettle();
    expect(s.calls, contains('role:acc-minh:viewer'));
    await tapKey(tester, 'member-menu-acc-minh');
    await tester.tap(find.text('Remove from the space').last);
    await tester.pumpAndSettle();
    await tapKey(tester, 'space-confirm');
    expect(s.calls, contains('remove:acc-minh'));
  });

  testWidgets('invite: role and kind, then the code, QR and link; "join at once" warns', (tester) async {
    final s = FakeSpaces(spaces: [personalHidden, shownAs(family)]);
    await pumpApp(tester, world(), s, size: const Size(1000, 1600));
    await tester.tap(find.byKey(const Key('space-bar')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Viewer').first);
    await tester.tap(find.text('Join at once'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Anyone who gets this code'), findsOneWidget);
    await tapKey(tester, 'invite-make');
    expect(s.calls, contains('invite:fam:viewer:joinAtOnce'));
    expect(find.byKey(const Key('invite-qr')), findsOneWidget);
    expect(find.text('ABCDE-FGHJK-LMNPQ-RSTUV-WXYZ2-3'), findsOneWidget);
    expect(find.text('lifeflow://join/ABCDEFGHJKLMNPQRSTUVWXYZ23'), findsOneWidget);
  });

  testWidgets('rules: the owner sets them; the change notice is seen once (SHARE-005)', (tester) async {
    final s = FakeSpaces(spaces: [personalHidden, shownAs(family, rulesChanged: true)]);
    await pumpApp(tester, world(), s, size: const Size(1000, 1600));
    await tester.tap(find.byKey(const Key('space-bar')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('space-rules-changed')), findsOneWidget);
    await tapKey(tester, 'space-rules-seen');
    expect(s.calls, contains('rulesSeen:fam'));
    await tester.ensureVisible(find.byKey(const Key('rule-export')));
    await tester.pumpAndSettle();
    await tester.tap(find.descendant(of: find.byKey(const Key('rule-export')), matching: find.byType(PopupMenuButton<ExportRule>)));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Every member').last);
    await tester.pumpAndSettle();
    expect(s.calls, contains('rules:disappear:everyMember:approve'));
  });

  testWidgets('leave and delete ask first; a problem is said', (tester) async {
    final s = FakeSpaces(spaces: [personalHidden, shownAs(family)])..nextProblem = SharingProblem.ownerMustHandOver;
    await pumpApp(tester, world(), s, size: const Size(1000, 1600));
    await tester.tap(find.byKey(const Key('space-bar')));
    await tester.pumpAndSettle();
    await tapKey(tester, 'space-leave');
    await tapKey(tester, 'space-confirm');
    expect(s.calls, contains('leave:fam'));
    expect(find.text('Make someone else the owner before you leave.'), findsOneWidget);
    await tapKey(tester, 'space-delete');
    await tapKey(tester, 'space-confirm');
    expect(s.calls, contains('delete:fam'));
  });

  testWidgets('"Move to a space…": what becomes visible is shown, then it moves (B3, PRIV-002)', (tester) async {
    final s = FakeSpaces(spaces: [personalShown, family])
      ..preview = const MovePreview(
          kind: 'task', id: 't', to: 'fam', counts: {'task': 2}, titles: ['A task', 'Its subtask'], hasNotes: true,
          hasDates: true, confirmation: ['task:t:1', 'task:s:1']);
    await pumpApp(tester, world(), s);
    await tester.tap(find.byTooltip('Actions for A task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to a space…'));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('move-confirm')), findsOneWidget);
    expect(find.text('Everyone in Family will see:'), findsOneWidget);
    expect(find.text('Its subtask'), findsOneWidget);
    expect(find.byKey(const Key('move-has-notes')), findsOneWidget);
    expect(find.text('Reminders and tracking stay with you.'), findsOneWidget);
    await tapKey(tester, 'move-confirm-yes');
    expect(s.calls, containsAllInOrder(['preview:task:t:fam', 'move:task:t:fam']));
    expect(find.text('Moved.'), findsOneWidget);
  });

  testWidgets('a move that cannot happen says why, and nothing moves', (tester) async {
    final s = FakeSpaces(spaces: [personalShown, family])
      ..preview = const MovePreview(
          kind: 'task', id: 't', to: 'fam', counts: {}, titles: [], hasNotes: false, hasDates: false, confirmation: [],
          blocker: 'a tracked task moves only after its tracking is turned off');
    await pumpApp(tester, world(), s);
    await tester.tap(find.byTooltip('Actions for A task'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Move to a space…'));
    await tester.pumpAndSettle();
    expect(find.textContaining('tracking is turned off'), findsOneWidget);
    expect(s.calls.where((c) => c.startsWith('move:')), isEmpty);
  });

  testWidgets('a task of a space: assigned to, changed by; "Assigned to me" (B9, B10)', (tester) async {
    final s = FakeSpaces(spaces: [personalHidden, shownAs(family)])
      ..names = {'fam': {'acc-me': 'Dien', 'acc-lan': 'Lan'}}
      ..memberLists = {
        'fam': const [
          SpaceMemberView(accountId: 'acc-me', name: 'Dien', role: SpaceRole.owner, status: MemberStatus.active, isMe: true),
          SpaceMemberView(accountId: 'acc-lan', name: 'Lan', role: SpaceRole.editor, status: MemberStatus.active, isMe: false),
        ]
      };
    final w = world(tasks: [
      task('t', 'Bins', assignee: 'acc-lan', changedBy: 'acc-lan'),
      task('u', 'Dishes', assignee: 'acc-me'),
    ]);
    await pumpApp(tester, w, s);
    await tester.tap(find.byKey(const Key('assigned-to-me')));
    await tester.pumpAndSettle();
    expect(find.text('Dishes'), findsOneWidget);
    expect(find.text('Bins'), findsNothing);
    await tester.tap(find.byKey(const Key('assigned-to-me')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bins'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byKey(const Key('task-page-assignee')), matching: find.text('Lan')), findsOneWidget);
    expect(find.textContaining('Changed by Lan'), findsOneWidget);
    await tapKey(tester, 'task-page-assignee');
    await tapKey(tester, 'assign-acc-me');
    expect(s.calls, contains('assign:t:acc-me'));
  });
}
