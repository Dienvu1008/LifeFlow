import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart' hide Block;
import 'package:flutter_test/flutter_test.dart';
import 'package:s07_quill/main.dart';

void main() {
  testWidgets('the probe shows the sample, loads 50 pages and round-trips', (tester) async {
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
    expect(find.textContaining('Chuyến đi Đà Nẵng', findRichText: true), findsWidgets);
    await tester.tap(find.text('Round trip'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Round trip OK'), findsOneWidget);
    await tester.tap(find.text('50 pages'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Loaded 50 pages: 550 blocks'), findsOneWidget);
    // ignore: avoid_print
    print(tester.widget<Text>(find.textContaining('Loaded 50 pages')).data);
    await tester.tap(find.text('Round trip'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Round trip OK'), findsOneWidget);
  });
}
