// P06b W4 (ADR-0088): the Assistant destination and its free chat, with
// fake ports.
//   place     a destination after Documents; before a first message: what it
//             can do, the day's tools, the history
//   chat      the message shows at once, then the answer; the next turn goes
//             on in the same chat; "New chat" starts again
//   proposal  under its answer; approved each or all (D8)
//   consent   D6: asked before; Send sends with them; Cancel sends nothing and
//             keeps the words
//   outcomes  declined or failed: said, the words kept
//   history   a chat opens again and goes on
//   other     the day's tools start at once; the options menu; not wired
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ui/src/assistant/assistant_page.dart';
import 'package:ui/src/assistant/assistant_settings.dart';
import 'package:ui/src/assistant/chat_view.dart';
import 'package:ui/src/search/search_page.dart';
import 'package:ui/ui.dart';

import 'fake_assistant.dart';
import 'fake_world.dart';
import 'nav.dart';

const _note = AiContextItem(ref: RecordRef('aichat', 'chat1'), classification: DataClassification.confidential, title: 'Earlier messages of this chat');

AiTurnResult answered(String text) => AiTurnResult(AiTurnOutcome.answered, site: AiEngineSite.device, model: 'qwen', text: text);

void main() {
  late List<String> calls;
  late FakeHistory history;
  late FakeAssistant ai;
  late FakeSetup setup;

  setUp(() {
    calls = [];
    history = FakeHistory(calls);
    ai = FakeAssistant(calls, history);
    setup = FakeSetup(calls);
  });

  Future<FakeWorld> app(WidgetTester tester, {bool wired = true, double width = 1200}) async {
    tester.view.physicalSize = Size(width, 1200);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final w = FakeWorld(tasks: {'A': []}, profiles: [profile('A', 'Dien')], activeId: 'A');
    addTearDown(w.dispose);
    await tester.pumpWidget(appWith(w,
        extra: wired
            ? [
                aiAssistantProvider.overrideWithValue(ai),
                aiHistoryProvider.overrideWithValue(history),
                aiSetupProvider.overrideWithValue(setup),
              ]
            : const []));
    await tester.pumpAndSettle();
    return w;
  }

  Future<void> say(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('ai-chat-field')), text);
    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pumpAndSettle();
  }

  /// Sends [text] and waits for the consent sheet (the turn is still busy).
  Future<void> sayToSheet(WidgetTester tester, String text) async {
    await tester.enterText(find.byKey(const Key('ai-chat-field')), text);
    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  String fieldText(WidgetTester tester) => tester.widget<TextField>(find.byKey(const Key('ai-chat-field'))).controller!.text;

  testWidgets('a destination after Documents, on the rail and in the drawer', (tester) async {
    await app(tester);
    final rail = tester.widget<NavigationRail>(find.byType(NavigationRail));
    final labels = [for (final d in rail.destinations) (d.label as Text).data];
    expect(labels.indexOf('Assistant'), labels.indexOf('Documents') + 1);
    await goToTab(tester, 'Assistant');
    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(tester.widget<NavigationRail>(find.byType(NavigationRail)).selectedIndex, 4);

    await tester.pumpWidget(const SizedBox.shrink());
    await app(tester, width: 400);
    await openDrawer(tester);
    expect(find.descendant(of: find.byKey(const Key('nav-drawer')), matching: find.text('Assistant')), findsOneWidget);
  });

  testWidgets('before a first message: what it can do, the day\'s tools, the history', (tester) async {
    history.seed('Kế hoạch ngày 5/11', [change('t1', '"Viết báo cáo": 10:30–12:00')]);
    await app(tester);
    await goToTab(tester, 'Assistant');
    expect(find.byKey(const Key('ai-chat-intro')), findsOneWidget);
    expect(find.byKey(const Key('ai-chip-plan')), findsOneWidget);
    expect(find.byKey(const Key('ai-chip-fix')), findsOneWidget);
    expect(find.text('Kế hoạch ngày 5/11'), findsOneWidget);
    expect(find.byKey(const Key('ai-new-chat')), findsNothing);
  });

  testWidgets('a message shows at once, then the answer; the chat goes on; "New chat" starts again', (tester) async {
    ai.results.add(() => answered('Anh có hai việc về thuế.'));
    await app(tester);
    await goToTab(tester, 'Assistant');

    ai.hold = Completer<void>();
    await tester.enterText(find.byKey(const Key('ai-chat-field')), 'Tôi có việc gì về thuế?');
    await tester.tap(find.byKey(const Key('ai-chat-send')));
    await tester.pump();
    expect(find.descendant(of: find.byKey(const Key('ai-pending')), matching: find.text('Tôi có việc gì về thuế?')), findsOneWidget);
    expect(find.byKey(const Key('ai-stop')), findsOneWidget);
    expect(fieldText(tester), isEmpty);
    await tester.tap(find.byKey(const Key('ai-stop')));
    ai.hold!.complete();
    ai.hold = null;
    await tester.pumpAndSettle();
    expect(calls, contains('ai.stop'));

    expect(find.byKey(const Key('ai-chat-intro')), findsNothing);
    expect(find.text('Tôi có việc gì về thuế?'), findsOneWidget);
    expect(find.text('Anh có hai việc về thuế.'), findsOneWidget);
    expect(find.text('On this device · qwen'), findsOneWidget);
    expect(calls.where((c) => c.startsWith('ai.chat:')), ['ai.chat:Tôi có việc gì về thuế?:-::false']);

    await say(tester, 'Còn gì nữa?');
    expect(calls.last, 'ai.chat:Còn gì nữa?:chat1::false', reason: 'the same chat');
    expect(find.text('Còn gì nữa?'), findsOneWidget);

    await tester.tap(find.byKey(const Key('ai-new-chat')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ai-chat-intro')), findsOneWidget);
    expect(find.text('Còn gì nữa?'), findsNothing);
    await say(tester, 'Xin chào');
    expect(calls.last, 'ai.chat:Xin chào:-::false', reason: 'a new chat');
  });

  testWidgets('a proposal under its answer, approved each or all (D8)', (tester) async {
    ai.chatChanges = [change('c1', 'Việc mới: "Mua hoa"'), change('c2', '"Gọi mẹ": 20:00–20:20')];
    ai.results.add(() => const AiTurnResult(AiTurnOutcome.proposed,
        proposalId: 'px', site: AiEngineSite.device, model: 'qwen', text: 'Em đề xuất như sau.'));
    await app(tester);
    await goToTab(tester, 'Assistant');
    await say(tester, 'Nhắc em gọi mẹ và mua hoa');
    expect(find.byKey(const ValueKey('ai-proposal-px')), findsOneWidget);
    expect(find.text('Việc mới: "Mua hoa"'), findsOneWidget);
    expect(calls.where((c) => c.startsWith('h.approve')), isEmpty, reason: 'nothing approved by itself');
    await tester.tap(find.text('Approve all'));
    await tester.pumpAndSettle();
    expect(calls, contains('h.approveAll:px'));
  });

  testWidgets('consent first (D6): Send sends with them; Cancel sends nothing and keeps the words', (tester) async {
    AiTurnResult ask() => const AiTurnResult(AiTurnOutcome.needsConsent,
        site: AiEngineSite.cloud, lines: [AiEgressLine(_note, AiEgress.needsConsent, sent: false)]);
    ai.results.addAll([ask, () => answered('Vâng.'), ask]);
    await app(tester);
    await goToTab(tester, 'Assistant');
    await sayToSheet(tester, 'Nhắc lại giúp em');
    expect(find.byKey(const Key('ai-consent-sheet')), findsOneWidget);
    expect(find.text('Earlier messages of this chat'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ai-consent-send')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.startsWith('ai.chat:')).last, 'ai.chat:Nhắc lại giúp em:-:aichat:chat1:false');
    expect(find.text('Vâng.'), findsOneWidget);

    await sayToSheet(tester, 'Một lần nữa');
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.startsWith('ai.chat:Một lần nữa')), hasLength(1), reason: 'not sent again');
    expect(fieldText(tester), 'Một lần nữa', reason: 'the words are kept');
  });

  testWidgets('declined or failed: said, the words kept', (tester) async {
    ai.results.addAll([
      () => const AiTurnResult(AiTurnOutcome.declined, reason: 'no assistant engine is set up'),
      () => const AiTurnResult(AiTurnOutcome.failed, failure: AiEngineFailureKind.network),
    ]);
    await app(tester);
    await goToTab(tester, 'Assistant');
    await say(tester, 'Xin chào');
    expect(find.byKey(const Key('ai-message')), findsOneWidget);
    expect(fieldText(tester), 'Xin chào');
    await say(tester, 'Xin chào');
    expect(find.descendant(of: find.byKey(const Key('ai-message')), matching: find.textContaining('connection')), findsOneWidget);
    expect(fieldText(tester), 'Xin chào');
  });

  testWidgets('a chat from the history opens again and goes on', (tester) async {
    ai.results.add(() => answered('Chào anh.'));
    await app(tester);
    await goToTab(tester, 'Assistant');
    await say(tester, 'Xin chào');
    await tester.tap(find.byKey(const Key('ai-new-chat')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('ai-session-chat1')));
    await tester.pumpAndSettle();
    expect(find.byType(AiChatPage), findsOneWidget);
    expect(find.text('Chào anh.'), findsOneWidget);
    await say(tester, 'Còn gì nữa?');
    expect(calls.last, 'ai.chat:Còn gì nữa?:chat1::false');
  });

  testWidgets('the day\'s tools start at once', (tester) async {
    ai.results.add(() => const AiTurnResult(AiTurnOutcome.nothingToDo, reason: 'no open task to plan'));
    await app(tester);
    await goToTab(tester, 'Assistant');
    await tester.tap(find.byKey(const Key('ai-chip-plan')));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantPage), findsOneWidget);
    expect(calls.where((c) => c.startsWith('ai.plan:')), hasLength(1));
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-chip-fix')));
    await tester.pumpAndSettle();
    expect(calls.where((c) => c.startsWith('ai.fix:')), hasLength(1));
  });

  testWidgets('the options menu: Search first, then the assistant\'s settings', (tester) async {
    await app(tester);
    await goToTab(tester, 'Assistant');
    await tester.tap(find.byKey(const Key('screen-options')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('ai-open-settings')));
    await tester.pumpAndSettle();
    expect(find.byType(AssistantSettingsScreen), findsOneWidget);
    await goToTab(tester, 'Assistant');
    await openSearchFromMenu(tester);
    expect(find.byType(SearchPage), findsOneWidget);
  });

  testWidgets('not wired: said, no chat', (tester) async {
    await app(tester, wired: false);
    await goToTab(tester, 'Assistant');
    expect(find.byKey(const Key('ai-not-available')), findsOneWidget);
    expect(find.byKey(const Key('ai-chat-field')), findsNothing);
  });
}
