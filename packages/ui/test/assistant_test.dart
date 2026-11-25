// P06 T7 (ADR-0087): the assistant on screen, with fake ports.
//   plan       a proposal: each change approved or dismissed on its own, or
//              all at once (D8); nothing approved by itself; a stale change
//              offers "Regenerate"
//   consent    D6: the sheet lists what waits and what is never sent; Send,
//              Send without these, Cancel (nothing sent)
//   outcomes   nothing to plan, no conflicts, declined (no model, privacy,
//              personal space), failures (the cap, the key)
//   history    listed, opened, deleted with Undo
//   ask        the answer streamed; consent; a failure said
//   settings   models: recommended, slow on a phone with a warning first,
//              download with progress and cancel, use, delete, own file;
//              cloud: off by default, key saved but never shown, models
//              listed, cap; hours; language
//   entries    Calendar, a document, Settings; none without an assistant
import 'dart:async';

import 'package:application/application.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:foundation/foundation.dart';
import 'package:ui/src/assistant/assistant_page.dart';
import 'package:ui/src/assistant/assistant_settings.dart';
import 'package:ui/src/documents/document_page.dart';
import 'package:ui/src/l10n.dart';
import 'package:ui/ui.dart';

import 'fake_assistant.dart';
import 'fake_world.dart';
import 'nav.dart';

final day = LocalDate(2026, 11, 5);

AiTurnResult proposed(String session, String proposal) => AiTurnResult(AiTurnOutcome.proposed,
    sessionId: session, proposalId: proposal, site: AiEngineSite.device, model: 'qwen');

const note = AiContextItem(ref: RecordRef('task', 't1'), classification: DataClassification.confidential, title: 'Nộp quỹ', text: '');
const pulse = AiContextItem(ref: RecordRef('measurement', 'm1'), classification: DataClassification.restricted, title: 'Nhịp tim', text: '');
AiTurnResult needsConsent() => const AiTurnResult(AiTurnOutcome.needsConsent, site: AiEngineSite.cloud, lines: [
      AiEgressLine(note, AiEgress.needsConsent, sent: false),
      AiEgressLine(pulse, AiEgress.deny, sent: false),
    ]);

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

  List<Override> wired() => [
        aiAssistantProvider.overrideWithValue(ai),
        aiHistoryProvider.overrideWithValue(history),
        aiSetupProvider.overrideWithValue(setup),
      ];

  Future<void> pump(WidgetTester tester, Widget page) async {
    tester.view.physicalSize = const Size(1000, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        ...wired(),
        todayProvider.overrideWithValue(() => day),
        activeProfileProvider.overrideWith((ref) async => null),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: page,
      ),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Key key) async {
    await tester.ensureVisible(find.byKey(key));
    await tester.tap(find.byKey(key));
    await tester.pumpAndSettle();
  }

  /// Taps without waiting to settle (a progress bar runs meanwhile).
  Future<void> tapAndPump(WidgetTester tester, Finder f) async {
    await tester.ensureVisible(f);
    await tester.tap(f);
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }
  }

  group('plan my day', () {
    testWidgets('a proposal: each change on its own or all; nothing approved by itself (D8)', (tester) async {
      final (s, p) = history.seed('Kế hoạch', [change('c1', '"A": 10:30–12:00'), change('c2', '"B": 13:30–13:45'), change('c3', '"C": 16:00–16:45')]);
      ai.results.add(() => proposed(s, p));
      await pump(tester, const AssistantPage());
      expect(find.text('Day: $day'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ai-note')), 'Buổi chiều tôi bận.');
      await tap(tester, const Key('ai-plan-day'));
      expect(calls, ['ai.plan:$day:-:Buổi chiều tôi bận.::false']);
      expect(find.text('"A": 10:30–12:00'), findsOneWidget);
      expect(find.textContaining('Nothing changes until you approve it.'), findsOneWidget);
      expect(find.text('On this device · qwen'), findsOneWidget);
      expect(calls.where((c) => c.startsWith('h.')), isEmpty, reason: 'nothing approved by itself');

      await tap(tester, const ValueKey('ai-approve-c1'));
      await tap(tester, const ValueKey('ai-dismiss-c2'));
      expect(find.descendant(of: find.byKey(const ValueKey('ai-change-c1')), matching: find.text('Applied')), findsOneWidget);
      expect(find.byKey(const ValueKey('ai-approve-c1')), findsNothing, reason: 'decided: no buttons');
      expect(find.byKey(const ValueKey('ai-dismiss-c2')), findsNothing);
      expect(find.descendant(of: find.byKey(const ValueKey('ai-change-c2')), matching: find.text('Dismissed')), findsOneWidget);
      expect(find.byKey(const Key('ai-approve-all')), findsNothing, reason: 'one left: approve it on its own');
      await tap(tester, const ValueKey('ai-approve-c3'));
      expect(calls, containsAllInOrder(['h.approve:$p:c1', 'h.dismiss:$p:c2', 'h.approve:$p:c3']));
    });

    testWidgets('approve all; a stale change shows "Regenerate", which plans again in the same conversation', (tester) async {
      final (s, p) = history.seed('Kế hoạch', [change('c1', 'A'), change('c2', 'B')]);
      history.staleOnApprove.add('c2');
      ai.results.add(() => proposed(s, p));
      await pump(tester, const AssistantPage());
      await tap(tester, const Key('ai-plan-day'));
      expect(find.byKey(const Key('ai-regenerate')), findsNothing, reason: 'nothing stale yet');
      await tap(tester, const Key('ai-approve-all'));
      expect(calls, contains('h.approveAll:$p'));
      expect(find.text('Out of date: something changed since'), findsOneWidget);
      await tap(tester, const Key('ai-regenerate'));
      expect(calls.last, 'ai.plan:$day:$s:::false');
    });

    testWidgets('fix conflicts on another day', (tester) async {
      ai.results.add(() => const AiTurnResult(AiTurnOutcome.nothingToDo));
      await pump(tester, AssistantPage(date: day.addDays(2)));
      await tap(tester, const Key('ai-fix-conflicts'));
      expect(calls, ['ai.fix:${day.addDays(2)}:-']);
      expect(find.text('No conflicts that day.'), findsOneWidget);
    });

    for (final (name, result, text) in [
      ('nothing to plan', const AiTurnResult(AiTurnOutcome.nothingToDo), 'There is no open task without a time to plan that day.'),
      ('no model set up', const AiTurnResult(AiTurnOutcome.declined, reason: 'device: not set up; cloud: may not receive'),
          'Set up a model first: Settings → Assistant.'),
      ('privacy', const AiTurnResult(AiTurnOutcome.declined, reason: 'cloud: may not receive what the request is about'),
          'No model you allowed may receive this data, so nothing was sent.'),
      ('a shared space', const AiTurnResult(AiTurnOutcome.declined, reason: 'the assistant works in the personal space only'),
          'The assistant works in your personal space only.'),
      ('the cap', const AiTurnResult(AiTurnOutcome.failed, failure: AiEngineFailureKind.capReached),
          'This would go over your monthly token limit, so it was not sent.'),
      ('a bad key', const AiTurnResult(AiTurnOutcome.failed, failure: AiEngineFailureKind.unauthorized), 'The provider refused the key.'),
      ('placed nothing', const AiTurnResult(AiTurnOutcome.answered, sessionId: 's9'), 'The assistant placed nothing.'),
    ]) {
      testWidgets('said plainly: $name', (tester) async {
        ai.results.add(() => result);
        await pump(tester, const AssistantPage());
        await tap(tester, const Key('ai-plan-day'));
        expect(find.text(text), findsOneWidget);
      });
    }
  });

  group('consent (D6)', () {
    testWidgets('the sheet lists what waits and what is never sent; Send consents to the waiting ones', (tester) async {
      final (s, p) = history.seed('Kế hoạch', [change('c1', 'A')]);
      ai.results
        ..add(needsConsent)
        ..add(() => proposed(s, p));
      await pump(tester, const AssistantPage());
      await tapAndPump(tester, find.byKey(const Key('ai-plan-day')));
      expect(find.byKey(const Key('ai-consent-sheet')), findsOneWidget);
      expect(find.text('Nộp quỹ'), findsOneWidget);
      expect(find.text('Private'), findsOneWidget);
      expect(find.text('Never sent (not allowed)'), findsOneWidget);
      expect(find.text('Nhịp tim'), findsOneWidget);
      expect(calls, hasLength(1), reason: 'nothing sent before the choice');
      await tap(tester, const Key('ai-consent-send'));
      expect(calls.last, 'ai.plan:$day:-::task:t1:false');
      expect(find.text('A'), findsOneWidget);
    });

    testWidgets('Send without these; Cancel sends nothing', (tester) async {
      ai.results
        ..add(needsConsent)
        ..add(() => const AiTurnResult(AiTurnOutcome.declined, reason: 'nothing the request is about may be sent'))
        ..add(needsConsent);
      await pump(tester, const AssistantPage());
      await tapAndPump(tester, find.byKey(const Key('ai-plan-day')));
      await tap(tester, const Key('ai-consent-without'));
      expect(calls.last, 'ai.plan:$day:-:::true');
      expect(find.text('No model you allowed may receive this data, so nothing was sent.'), findsOneWidget);
      calls.clear();
      await tapAndPump(tester, find.byKey(const Key('ai-plan-day')));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, hasLength(1));
    });
  });

  group('history', () {
    testWidgets('listed newest first, opened with its messages and proposal, deleted with Undo', (tester) async {
      history.seed('Cũ', [change('c1', 'A')]);
      history.seed('Mới', [change('c9', 'Z')], note: 'Sáng làm việc khó.');
      await pump(tester, const AssistantPage());
      final titles = [for (final t in tester.widgetList<ListTile>(find.byWidgetPredicate((w) => w is ListTile && '${w.key}'.contains('ai-session-')))) (t.title as Text).data];
      expect(titles, ['Mới', 'Cũ']);
      await tap(tester, const ValueKey('ai-session-s2'));
      expect(find.text('Plan my day'), findsWidgets);
      expect(find.text('Sáng làm việc khó.'), findsOneWidget);
      expect(find.text('Z'), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await tap(tester, const ValueKey('ai-delete-s2'));
      expect(calls, contains('h.trash:s2'));
      expect(find.byKey(const ValueKey('ai-session-s2')), findsNothing);
      await tester.tap(find.text('Undo'));
      await tester.pumpAndSettle();
      expect(calls, contains('h.restore:s2'));
      expect(find.byKey(const ValueKey('ai-session-s2')), findsOneWidget);
    });

    testWidgets('no conversations yet', (tester) async {
      await pump(tester, const AssistantPage());
      expect(find.byKey(const Key('ai-no-history')), findsOneWidget);
    });
  });

  group('ask about a document', () {
    testWidgets('the answer as it comes; the engine named; consent; a failure said', (tester) async {
      ai.results.add(() => const AiTurnResult(AiTurnOutcome.answered, sessionId: 's1', site: AiEngineSite.cloud, model: 'groq:m'));
      await pump(tester, const Scaffold(body: AskAssistantSheet(item: RecordRef('document', 'd1'))));
      ai.hold = Completer<void>();
      await tester.enterText(find.byKey(const Key('ai-ask-question')), 'Hạn nộp là ngày nào?');
      await tester.tap(find.byKey(const Key('ai-ask-send')));
      await tester.pump();
      expect(find.byKey(const Key('ai-ask-stop')), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-ask-stop')));
      ai.hold!.complete();
      await tester.pumpAndSettle();
      expect(calls, ['ai.ask:document:d1:Hạn nộp là ngày nào?:', 'ai.stop']);
      expect(find.text('Ngày 30 tháng 11.'), findsOneWidget);
      expect(find.text('Cloud · groq:m'), findsOneWidget);

      ai.hold = null;
      ai.results
        ..clear()
        ..add(needsConsent)
        ..add(() => const AiTurnResult(AiTurnOutcome.failed, failure: AiEngineFailureKind.network));
      await tapAndPump(tester, find.byKey(const Key('ai-ask-send')));
      await tester.tap(find.byKey(const Key('ai-consent-send')));
      await tester.pumpAndSettle();
      expect(calls.last, 'ai.ask:document:d1:Hạn nộp là ngày nào?:task:t1');
      expect(find.text('No connection to the provider.'), findsOneWidget);
    });
  });

  group('settings', () {
    testWidgets('Windows: the recommended model; download with progress; it is chosen; delete', (tester) async {
      await pump(tester, const AssistantSettingsScreen());
      expect(find.textContaining('Recommended'), findsOneWidget);
      expect(find.textContaining('Slow on this device'), findsNothing);
      expect(find.textContaining('1.3 GB · Apache-2.0 · about 1.4 GB of memory'), findsOneWidget);
      setup.models.gate = Completer<void>();
      await tap(tester, const ValueKey('ai-download-qwen-2'));
      expect(find.textContaining('This downloads 1.3 GB'), findsOneWidget);
      await tester.tap(find.byKey(const Key('ai-confirm')));
      await tester.pump();
      expect(find.textContaining('Downloading… 25%'), findsOneWidget);
      setup.models.gate!.complete();
      await tester.pumpAndSettle();
      expect(calls, containsAllInOrder(['m.download:qwen-2', 'm.select:qwen-2']));
      expect(find.text('In use'), findsOneWidget);
      await tap(tester, const ValueKey('ai-delete-model-qwen-2'));
      expect(calls.last, 'm.delete:qwen-2');
      expect(find.byKey(const ValueKey('ai-download-qwen-2')), findsOneWidget);
    });

    testWidgets('a phone: only the small model, marked slow; a warning before the download; cancel', (tester) async {
      setup = FakeSetup(calls, platform: LocalPlatform.android);
      await pump(tester, const AssistantSettingsScreen());
      expect(find.byKey(const ValueKey('ai-model-qwen-2')), findsNothing);
      expect(find.textContaining('Slow on this device: not recommended'), findsOneWidget);
      setup.models.gate = Completer<void>();
      await tap(tester, const ValueKey('ai-download-qwen-08'));
      expect(find.text('Local models are slow on phones'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty, reason: 'nothing downloaded without "Download anyway"');
      await tap(tester, const ValueKey('ai-download-qwen-08'));
      await tester.tap(find.text('Download anyway'));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('ai-cancel-qwen-08')));
      setup.models.gate!.complete();
      await tester.pumpAndSettle();
      expect(calls, ['m.download:qwen-08']);
      expect(setup.models.installedList, isEmpty);
    });

    testWidgets('a model file: typed, imported and used; not GGUF: said so', (tester) async {
      await pump(tester, const AssistantSettingsScreen());
      await tap(tester, const Key('ai-use-file'));
      await tester.enterText(find.byKey(const Key('ai-model-path')), r'C:\models\notes.txt');
      await tester.tap(find.byKey(const Key('ai-model-path-use')));
      await tester.pumpAndSettle();
      expect(find.text('This is not a GGUF model file.'), findsOneWidget);
      await tap(tester, const Key('ai-use-file'));
      await tester.enterText(find.byKey(const Key('ai-model-path')), r'C:\models\Mine.gguf');
      await tester.tap(find.byKey(const Key('ai-model-path-use')));
      await tester.pumpAndSettle();
      expect(calls, containsAllInOrder([r'm.import:C:\models\Mine.gguf', 'm.select:file-1']));
      expect(find.textContaining('Your own file'), findsOneWidget);
    });

    testWidgets('cloud: off by default; a key saved but never shown; models listed; the cap and this month', (tester) async {
      await pump(tester, const AssistantSettingsScreen());
      expect(find.byKey(const Key('ai-provider')), findsNothing, reason: 'off by default (D2)');
      await tap(tester, const Key('ai-cloud-switch'));
      expect(calls.last, 's.settings:device:true:480-1080:vi');
      expect(find.text('No key saved for this provider'), findsOneWidget);
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('ai-load-models'))).onPressed, isNull, reason: 'no key yet');

      await tester.tap(find.byKey(const Key('ai-provider')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Groq').last);
      await tester.pumpAndSettle();
      expect(find.text('https://console.groq.com/docs/your-data'), findsOneWidget, reason: 'the provider''s terms');
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String?;
        return null;
      });
      await tap(tester, const Key('ai-terms'));
      expect(copied, 'https://console.groq.com/docs/your-data');
      expect(find.text('Link copied: open it in your browser'), findsOneWidget);
      await tester.pumpAndSettle(const Duration(seconds: 5));
      await tester.enterText(find.byKey(const Key('ai-key')), 'gsk-SECRET');
      await tap(tester, const Key('ai-save-key'));
      expect(calls.last, 's.key:groq:set');
      expect(find.text('A key is saved for this provider'), findsOneWidget);
      expect(find.text('gsk-SECRET'), findsNothing, reason: 'the key is never shown again');
      expect(tester.widget<TextField>(find.byKey(const Key('ai-key'))).obscureText, isTrue);

      await tap(tester, const Key('ai-load-models'));
      await tap(tester, const ValueKey('ai-model-choice-model-b'));
      await tester.enterText(find.byKey(const Key('ai-cap')), '200000');
      expect(find.text('1234 tokens used this month'), findsOneWidget);
      await tap(tester, const Key('ai-save-cloud'));
      expect(calls.last, 's.cloud:groq:model-b:null:200000');

      await tap(tester, const Key('ai-forget-key'));
      expect(calls.last, 's.key:groq:forget');
    });

    testWidgets('the engine tried first, the hours, the language', (tester) async {
      await pump(tester, const AssistantSettingsScreen());
      await tap(tester, const Key('ai-prefer-cloud'));
      expect(calls.last, 's.settings:cloud:false:480-1080:vi');
      await tester.tap(find.byKey(const Key('ai-day-start')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('7:00').last);
      await tester.pumpAndSettle();
      expect(calls.last, 's.settings:cloud:false:420-1080:vi');
      await tap(tester, const Key('ai-lang-en'));
      expect(calls.last, 's.settings:cloud:false:420-1080:en');
    });
  });

  group('entries', () {
    Future<FakeWorld> app(WidgetTester tester, {bool assistant = true}) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final w = FakeWorld(tasks: {'A': []}, profiles: [profile('A', 'Dien')], activeId: 'A');
      addTearDown(w.dispose);
      await tester.pumpWidget(appWith(w, extra: assistant ? wired() : const []));
      await tester.pumpAndSettle();
      return w;
    }

    testWidgets('Calendar opens the assistant; Settings has its page; a document asks it', (tester) async {
      final w = await app(tester);
      await goToTab(tester, 'Calendar');
      await tester.tap(find.byKey(const Key('calendar-assistant')));
      await tester.pumpAndSettle();
      expect(find.byType(AssistantPage), findsOneWidget);
      await tester.pageBack();
      await tester.pumpAndSettle();

      await goToTab(tester, 'Settings');
      await tester.scrollUntilVisible(find.byKey(const Key('assistant-settings')), 300, scrollable: find.byType(Scrollable).last);
      await tap(tester, const Key('assistant-settings'));
      expect(find.byType(AssistantSettingsScreen), findsOneWidget);

      final id = w.documents.put('Biên bản');
      await goToTab(tester, 'Documents');
      await tester.tap(find.byKey(ValueKey('doc-$id')));
      await tester.pumpAndSettle();
      expect(find.byType(DocumentPage), findsOneWidget);
      await tester.tap(find.byKey(const Key('doc-ask-assistant')));
      await tester.pumpAndSettle();
      expect(find.byType(AskAssistantSheet), findsOneWidget);
    });

    testWidgets('without an assistant, no entry to it', (tester) async {
      await app(tester, assistant: false);
      await goToTab(tester, 'Calendar');
      expect(find.byKey(const Key('calendar-assistant')), findsNothing);
      await goToTab(tester, 'Settings');
      await tester.scrollUntilVisible(find.byKey(const Key('open-source-licenses')), 300, scrollable: find.byType(Scrollable).last);
      expect(find.byKey(const Key('sync-settings')), findsOneWidget, reason: 'the neighbour is shown');
      expect(find.byKey(const Key('assistant-settings')), findsNothing);
    });
  });
}
