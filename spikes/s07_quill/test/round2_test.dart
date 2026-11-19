import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:flutter_test/flutter_test.dart';
import 'package:s07_quill/main.dart';

void main() {
  testWidgets('round 2: B switches bold on, then off again (step 5)', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(localizationsDelegates: [
      GlobalMaterialLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      FlutterQuillLocalizations.delegate,
    ], home: Probe()));
    await tester.pumpAndSettle();
    final c = tester.widget<QuillEditor>(find.byType(QuillEditor)).controller;
    c.updateSelection(const TextSelection(baseOffset: 0, extentOffset: 6), ChangeSource.local);
    bool bold() => c.getSelectionStyle().attributes.containsKey(Attribute.bold.key);
    expect(bold(), isFalse);
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(bold(), isTrue);
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(bold(), isFalse);
  });
}
