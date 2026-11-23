// P05b T4 (ADR-0078; p05b-plan.md D5, D6, D7): a document read aloud, with
// fake voices.
//   reading   sentence by sentence; the one read is selected in the editor,
//             which reads only meanwhile; nothing is saved by reading
//   controls  pause (the sentence starts over), stop, previous and next,
//             speed (remembered), voice (remembered per language)
//   language  a Vietnamese document gets a Vietnamese voice, an English one
//             an English voice; none: the reader says so and how to add one
//   leaving   the page stops it; the app in the background pauses it
import 'package:application/application.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:ui/src/documents/read_aloud.dart' show ReadState;

import 'documents_flow_test.dart' show openDocuments, pageState, pumpApp, saves, tapKey, world;
import 'fake_tts.dart';
import 'fake_world.dart';

const viText = 'Họp tổ lúc chín giờ. Mang theo ghế! Ai đến muộn?';

DocumentBody body(List<(String, String)> blocks) =>
    DocumentBody([for (final (id, text) in blocks) DocBlock(id, BlockType.paragraph, runs: [TextRun(text)])]);

Future<(FakeWorld, String)> openDoc(WidgetTester tester, DocumentBody b, {void Function(FakeWorld w)? setUp}) async {
  final w = world();
  final d = w.documents.put('Họp tổ', body: b);
  setUp?.call(w);
  await pumpApp(tester, w);
  await openDocuments(tester);
  await tester.tap(find.byKey(ValueKey('doc-$d')));
  await tester.pumpAndSettle();
  return (w, d);
}

List<String> spoken(FakeWorld w) => [for (final c in w.calls) if (c.startsWith('tts.speak:')) c.substring('tts.speak:'.length)];
String position(WidgetTester tester) => tester.widget<Text>(find.byKey(const Key('tts-position'))).data!;
String selected(WidgetTester tester) {
  final c = pageState(tester).controller!;
  return c.document.toPlainText().substring(c.selection.start, c.selection.end);
}

bool enabled(WidgetTester tester, String key) => tester.widget<IconButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  testWidgets('D7: read sentence by sentence, each selected in the editor, which reads only; nothing saved', (tester) async {
    final (w, _) = await openDoc(tester, body([('a', viText), ('b', 'Xong.')]));
    await tapKey(tester, 'doc-read-aloud');
    expect(find.byKey(const Key('doc-reader')), findsOneWidget);
    expect(position(tester), 'Sentence 1 of 4');
    expect(tester.widget<Text>(find.byKey(const Key('tts-voice-name'))).data, 'Microsoft An', reason: 'a Vietnamese voice');
    expect(pageState(tester).controller!.readOnly, isTrue);
    expect(find.byKey(const Key('doc-toolbar')), findsNothing);

    await tapKey(tester, 'tts-play');
    expect(spoken(w), ['Microsoft An:1.0:Họp tổ lúc chín giờ.']);
    expect(selected(tester), 'Họp tổ lúc chín giờ.');
    expect(tester.widget<IconButton>(find.byKey(const Key('tts-play'))).tooltip, 'Pause');

    w.tts.finish();
    await tester.pumpAndSettle();
    expect(position(tester), 'Sentence 2 of 4');
    expect(selected(tester), 'Mang theo ghế!');
    w.tts.finish();
    await tester.pumpAndSettle();
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(selected(tester), 'Xong.', reason: 'the next block');
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(spoken(w), hasLength(4));
    expect(position(tester), 'Sentence 1 of 4', reason: 'at the end it is ready to read again');
    expect(tester.widget<IconButton>(find.byKey(const Key('tts-play'))).tooltip, 'Read');

    await tapKey(tester, 'tts-close');
    expect(find.byKey(const Key('doc-reader')), findsNothing);
    expect(pageState(tester).controller!.readOnly, isFalse, reason: 'editable again');
    expect(pageState(tester).controller!.selection.isCollapsed, isTrue);
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(saves(w), isEmpty, reason: 'reading changes nothing');
  });

  testWidgets('pause stops the voice and starts the sentence over; stop goes back to the start', (tester) async {
    final (w, _) = await openDoc(tester, body([('a', viText)]));
    await tapKey(tester, 'doc-read-aloud');
    await tapKey(tester, 'tts-play');
    w.tts.finish();
    await tester.pumpAndSettle();
    await tapKey(tester, 'tts-play'); // pause
    expect(w.calls.last, 'tts.stop');
    expect(w.tts.speaking, isNull);
    expect(position(tester), 'Sentence 2 of 3');
    expect(find.byKey(const Key('tts-note')), findsNothing, reason: 'a pause is not a failure');
    await tapKey(tester, 'tts-play');
    expect(spoken(w).last, 'Microsoft An:1.0:Mang theo ghế!', reason: 'the same sentence, from its start');
    await tapKey(tester, 'tts-close');
    expect(w.calls.last, 'tts.stop');
    expect(w.tts.speaking, isNull);
  });

  testWidgets('previous and next: while reading they read that sentence; paused they only move', (tester) async {
    final (w, _) = await openDoc(tester, body([('a', viText)]));
    await tapKey(tester, 'doc-read-aloud');
    expect(enabled(tester, 'tts-previous'), isFalse);
    await tapKey(tester, 'tts-next');
    expect(position(tester), 'Sentence 2 of 3');
    expect(spoken(w), isEmpty, reason: 'not reading: only moved');
    await tapKey(tester, 'tts-play');
    await tapKey(tester, 'tts-next');
    expect(spoken(w), ['Microsoft An:1.0:Mang theo ghế!', 'Microsoft An:1.0:Ai đến muộn?']);
    expect(selected(tester), 'Ai đến muộn?');
    expect(enabled(tester, 'tts-next'), isFalse);
    await tapKey(tester, 'tts-previous');
    expect(spoken(w).last, 'Microsoft An:1.0:Mang theo ghế!');
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(spoken(w).last, 'Microsoft An:1.0:Ai đến muộn?', reason: 'reading goes on from there');
  });

  testWidgets('speed and voice: remembered on this device (the voice per language); the sentence starts over with them',
      (tester) async {
    final (w, _) = await openDoc(tester, body([('a', viText)]), setUp: (w) {
      w.speed = 1.25;
      w.tts.list = [an, const TtsVoice(name: 'Google tiếng Việt', locale: 'vi_VN'), zira];
      w.voiceFor['vi'] = 'Google tiếng Việt';
    });
    await tapKey(tester, 'doc-read-aloud');
    expect(tester.widget<Text>(find.byKey(const Key('tts-speed-value'))).data, '1.25×');
    expect(tester.widget<Text>(find.byKey(const Key('tts-voice-name'))).data, 'Google tiếng Việt');
    await tapKey(tester, 'tts-play');
    expect(spoken(w).last, 'Google tiếng Việt:1.25:Họp tổ lúc chín giờ.');
    await tapKey(tester, 'tts-speed');
    await tapKey(tester, 'tts-speed-2.0');
    expect(w.calls, contains('speed:2.0'));
    expect(spoken(w).last, 'Google tiếng Việt:2.0:Họp tổ lúc chín giờ.');
    await tapKey(tester, 'tts-voice');
    await tapKey(tester, 'tts-voice-Microsoft An');
    expect(w.calls, contains('voice:vi:Microsoft An'));
    expect(spoken(w).last, 'Microsoft An:2.0:Họp tổ lúc chín giờ.');
  });

  testWidgets('an English document gets an English voice', (tester) async {
    final (w, _) = await openDoc(tester, body([('a', 'Meeting at nine. Bring a chair.')]));
    await tapKey(tester, 'doc-read-aloud');
    await tapKey(tester, 'tts-play');
    expect(spoken(w), ['Microsoft David:1.0:Meeting at nine.'], reason: 'the first English voice');
    expect(find.byKey(const Key('tts-no-voice')), findsNothing);
  });

  testWidgets('D5: no Vietnamese voice: the reader says so and how to add one; another voice can be picked', (tester) async {
    final (w, _) = await openDoc(tester, body([('a', viText)]), setUp: (w) => w.tts.list = [david, zira]);
    await tapKey(tester, 'doc-read-aloud');
    expect(find.textContaining('This device has no Vietnamese voice.'), findsOneWidget);
    expect(find.textContaining('Android Settings → Text-to-speech output'), findsOneWidget);
    expect(enabled(tester, 'tts-play'), isFalse);
    await tapKey(tester, 'tts-voice');
    await tapKey(tester, 'tts-voice-Microsoft Zira');
    expect(w.calls, contains('voice:vi:Microsoft Zira'));
    await tapKey(tester, 'tts-play');
    expect(spoken(w), ['Microsoft Zira:1.0:Họp tổ lúc chín giờ.']);
  });

  testWidgets('D5 on Windows: how to add a voice there', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.windows;
    try {
      await openDoc(tester, body([('a', viText)]), setUp: (w) => w.tts.list = [zira]);
      await tapKey(tester, 'doc-read-aloud');
      expect(find.textContaining('Windows Settings → Time & language → Speech → Add voices.'), findsOneWidget);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('no voices at all, or nothing to read: said, and nothing can be read', (tester) async {
    await openDoc(tester, body([('a', viText)]), setUp: (w) => w.tts.list = []);
    await tapKey(tester, 'doc-read-aloud');
    expect(find.text('This device has no voices for reading aloud.'), findsOneWidget);
    expect(enabled(tester, 'tts-play'), isFalse);
    expect(find.byKey(const Key('tts-voice')), findsNothing);
  });

  testWidgets('nothing to read', (tester) async {
    await openDoc(tester, body([('a', '   ')]));
    await tapKey(tester, 'doc-read-aloud');
    expect(find.text('There is no text to read in this document.'), findsOneWidget);
    expect(enabled(tester, 'tts-play'), isFalse);
  });

  testWidgets('the voice fails on a sentence: reading pauses there and says so', (tester) async {
    final (w, _) = await openDoc(tester, body([('a', viText)]));
    await tapKey(tester, 'doc-read-aloud');
    await tapKey(tester, 'tts-play');
    w.tts.finish(false);
    await tester.pumpAndSettle();
    expect(find.text('The voice stopped: it could not read this sentence.'), findsOneWidget);
    expect(position(tester), 'Sentence 1 of 3');
    expect(tester.widget<IconButton>(find.byKey(const Key('tts-play'))).tooltip, 'Read');
  });

  testWidgets('D6: leaving the page stops the reading; the app in the background pauses it', (tester) async {
    final (w, _) = await openDoc(tester, body([('a', viText)]));
    await tapKey(tester, 'doc-read-aloud');
    await tapKey(tester, 'tts-play');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pumpAndSettle();
    expect(w.calls.last, 'tts.stop');
    // No frames while hidden: the reader itself says it paused.
    expect(pageState(tester).reader!.state, ReadState.paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(w.tts.speaking, isNull, reason: 'it does not start again by itself');
    expect(tester.widget<IconButton>(find.byKey(const Key('tts-play'))).tooltip, 'Read');

    await tapKey(tester, 'tts-play');
    expect(w.tts.speaking, 'Họp tổ lúc chín giờ.');
    final before = spoken(w).length;
    await tester.pageBack();
    await tester.pumpAndSettle();
    expect(w.tts.speaking, isNull, reason: 'stopped on leaving');
    expect(w.calls.last, 'tts.stop');
    w.tts.finish();
    await tester.pumpAndSettle();
    expect(spoken(w), hasLength(before), reason: 'nothing more is read');
  });

}
