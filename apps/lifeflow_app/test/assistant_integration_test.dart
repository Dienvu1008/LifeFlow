// P06 T7 (ADR-0087): the assistant in the app, over the real store and the
// real wiring (no model: none is downloaded in tests).
//   - the Calendar opens the assistant; with no task, "nothing to plan";
//     with a task and no model, "set up a model first", and nothing changed
//   - Settings → Assistant lists this platform's models; the cloud is off;
//     a key saved goes to the key store, never to the screen
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infrastructure/infrastructure.dart';
import 'package:application/application.dart';

import 'app_integration_test.dart' show World, finish, pumpApp, settle, tapAddTask;

void main() {
  testWidgets('the assistant from the Calendar, over the real store', (tester) async {
    final w = await pumpApp(tester, StoragePlatform.windows, width: 1200);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Calendar')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('calendar-assistant')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ai-plan-day')));
    await settle(tester);
    expect(find.text('There is no open task without a time to plan that day.'), findsOneWidget);
    await tester.pageBack();
    await settle(tester);

    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Overview')));
    await settle(tester);
    await tapAddTask(tester);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Viết báo cáo');
    await tester.tap(find.widgetWithText(FilledButton, 'Add'));
    await settle(tester);

    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Calendar')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('calendar-assistant')));
    await settle(tester);
    await tester.tap(find.byKey(const Key('ai-plan-day')));
    await settle(tester);
    expect(find.text('Set up a model first: Settings → Assistant.'), findsOneWidget);
    expect(find.byKey(const Key('ai-no-history')), findsOneWidget, reason: 'nothing was kept: no model answered');
    await tester.pageBack();
    await settle(tester);
    await finish(tester, w);
  });

  testWidgets('Settings → Assistant: this platform\'s models, the cloud off, a key kept out of sight', (tester) async {
    final World w = await pumpApp(tester, StoragePlatform.windows, width: 1200);
    await tester.tap(find.descendant(of: find.byType(NavigationRail), matching: find.text('Settings')));
    await settle(tester);
    await tester.scrollUntilVisible(find.byKey(const Key('assistant-settings')), 300, scrollable: find.byType(Scrollable).last);
    await tester.tap(find.byKey(const Key('assistant-settings')));
    await settle(tester);
    for (final m in localModelCatalog.where((m) => m.platforms.contains(LocalPlatform.windows))) {
      expect(find.byKey(ValueKey('ai-model-${m.id}')), findsOneWidget, reason: m.name);
    }
    expect(find.byKey(const Key('ai-provider')), findsNothing);

    await tester.tap(find.byKey(const Key('ai-cloud-switch')));
    await settle(tester);
    await tester.enterText(find.byKey(const Key('ai-key')), 'sk-test-123');
    await tester.ensureVisible(find.byKey(const Key('ai-save-key')));
    await tester.tap(find.byKey(const Key('ai-save-key')));
    await settle(tester);
    expect(w.aiKeys.values[CloudProvider.openai], 'sk-test-123');
    expect(find.text('sk-test-123'), findsNothing);
    expect(find.text('A key is saved for this provider'), findsOneWidget);
    await finish(tester, w);
  });
}
