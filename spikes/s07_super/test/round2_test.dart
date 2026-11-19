import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:s07_super/main.dart';
import 'package:super_editor/super_editor.dart';

void main() {
  testWidgets('round 2: the two to-dos show as tasks (step 4)', (tester) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(const MaterialApp(home: Probe()));
    await tester.pumpAndSettle();
    expect(find.byType(TaskComponent), findsNWidgets(2));
  });
}
