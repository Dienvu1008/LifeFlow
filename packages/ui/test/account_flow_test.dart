// Sign-in / bind / sign-out flows in the UI (ADR-0008, OQ-S7, GS-22).
import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_world.dart';

FakeWorld world({bool withData = true}) => FakeWorld(
      tasks: {
        'A': withData ? [task('t', 'Guest task')] : [],
      },
      profiles: [profile('A', 'Guest')],
      activeId: 'A',
    );

Future<void> openProfiles(WidgetTester tester, FakeWorld w) async {
  tester.view.physicalSize = const Size(1000, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  addTearDown(w.dispose);
  await tester.pumpWidget(appWith(w));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('rail-profile')));
  await tester.pumpAndSettle();
}

Future<void> chooseGitHub(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Continue with GitHub'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a guest sees the guest message and a Sign in button',
      (tester) async {
    await openProfiles(tester, world());
    expect(find.byKey(const Key('account-card')), findsOneWidget);
    expect(find.textContaining('Using LifeFlow as a guest'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsOneWidget);
  });

  testWidgets('an empty guest is signed in without a move question',
      (tester) async {
    final w = world(withData: false);
    await openProfiles(tester, w);
    await chooseGitHub(tester);
    expect(find.text('Move your data to this account?'), findsNothing);
    expect(w.calls, ['signIn:github']);
    expect(find.text('Signed in with GitHub.'), findsOneWidget);
    expect(find.widgetWithText(OutlinedButton, 'Sign out'), findsOneWidget);
  });

  testWidgets('a guest with data is asked; "Move my data" keeps this profile',
      (tester) async {
    final w = world();
    await openProfiles(tester, w);
    await chooseGitHub(tester);
    expect(find.text('Move your data to this account?'), findsOneWidget);
    await tester.tap(find.text('Move my data'));
    await tester.pumpAndSettle();
    expect(w.calls, ['signIn:github', 'completeBind:true']);
    expect(w.activeId, 'A');
    expect(find.text('Signed in with GitHub.'), findsOneWidget);
  });

  testWidgets('"New space" switches to a new profile and the guest stays',
      (tester) async {
    final w = world();
    await openProfiles(tester, w);
    await chooseGitHub(tester);
    await tester.tap(find.text('New space'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'completeBind:false');
    expect(w.activeId, isNot('A'));
    // The guest profile is still listed.
    expect(find.text('Guest'), findsOneWidget);
    expect(find.textContaining('Switched to this account'), findsOneWidget);

    // The task list now shows the new, empty space (ID-002).
    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Guest task'), findsNothing);
    expect(find.textContaining('No tasks yet'), findsOneWidget);
  });

  testWidgets('Cancel on the choice signs out of the pending session',
      (tester) async {
    final w = world();
    await openProfiles(tester, w);
    await chooseGitHub(tester);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(w.calls, ['signIn:github', 'cancelPendingBind']);
    expect(find.textContaining('Using LifeFlow as a guest'), findsOneWidget);
  });

  testWidgets('email sign-in validates input before calling the service',
      (tester) async {
    final w = world(withData: false);
    await openProfiles(tester, w);
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();
    final dialog = find.byType(AlertDialog);
    await tester.tap(find.descendant(
        of: dialog, matching: find.widgetWithText(FilledButton, 'Sign in')));
    await tester.pumpAndSettle();
    expect(find.text('Enter your email and password.'), findsOneWidget);
    expect(w.calls, isEmpty);

    await tester.enterText(find.widgetWithText(TextField, 'Email'), 'a@example.com');
    await tester.enterText(find.widgetWithText(TextField, 'Password'), 'pw');
    await tester.tap(find.descendant(
        of: dialog, matching: find.widgetWithText(FilledButton, 'Sign in')));
    await tester.pumpAndSettle();
    expect(w.calls, ['signIn:email']);
    expect(find.text('Signed in with email.'), findsOneWidget);
  });

  testWidgets('a failed sign-in shows the message and stays a guest',
      (tester) async {
    final w = world()..signInFailure = 'You appear to be offline.';
    await openProfiles(tester, w);
    await chooseGitHub(tester);
    expect(find.text('You appear to be offline.'), findsOneWidget);
    expect(find.textContaining('Using LifeFlow as a guest'), findsOneWidget);
  });

  testWidgets('sign-out asks first, then keeps the data (OQ-S7)',
      (tester) async {
    final w = world(withData: false);
    await openProfiles(tester, w);
    await chooseGitHub(tester);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
    await tester.pumpAndSettle();
    expect(w.calls.contains('signOut'), isFalse);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(w.calls.last, 'signOut');
    // Now on a guest; the account's profile is listed as locked (ADR-0024).
    expect(find.textContaining('Using LifeFlow as a guest'), findsOneWidget);
    expect(find.textContaining('signed out. Sign in to open it.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in to open'), findsOneWidget);
  });

  testWidgets('"Sign in to open" with the same account returns to its data',
      (tester) async {
    final w = world(withData: false);
    await openProfiles(tester, w);
    await chooseGitHub(tester); // empty guest A binds to GitHub
    w.calls.clear();
    // Give A some data, then sign out.
    await w.create('Mine');
    await tester.tap(find.widgetWithText(OutlinedButton, 'Sign out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Sign out'));
    await tester.pumpAndSettle();
    expect(w.activeId, isNot('A'));

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in to open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue with GitHub'));
    await tester.pumpAndSettle();
    expect(w.activeId, 'A');
    expect(find.text('Move your data to this account?'), findsNothing);
    expect(find.text('Signed in with GitHub.'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.checklist_outlined));
    await tester.pumpAndSettle();
    expect(find.text('Mine'), findsOneWidget);
  });

  testWidgets('a locked profile offers no Switch button', (tester) async {
    final w = FakeWorld(
      tasks: {'A': [], 'B': [task('b', 'B data')]},
      profiles: [
        profile('A', 'Guest'),
        ProfileView(
            id: 'B', displayName: 'Work', isActive: false, isBound: true,
            provider: 'github', isSignedOut: true),
      ],
      activeId: 'A',
    );
    await openProfiles(tester, w);
    expect(find.widgetWithText(FilledButton, 'Switch'), findsNothing);
    expect(find.widgetWithText(FilledButton, 'Sign in to open'), findsOneWidget);
    expect(find.byIcon(Icons.lock_outline), findsOneWidget);
  });

  testWidgets('a build without sign-in says so instead of hiding it',
      (tester) async {
    final w = world()..signInAvailable = false;
    await openProfiles(tester, w);
    expect(find.text('Sign-in is not configured in this build.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Sign in'), findsNothing);
  });
}
