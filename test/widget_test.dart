// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:gitsnap_flutter/main.dart';
import 'package:gitsnap_flutter/services/update_service.dart';

void main() {
  testWidgets('Home screen exposes the pull request tab',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GitSnapApp());
    await tester.pump();

    expect(find.text('Pull request'), findsOneWidget);
  });

  testWidgets('Version appears in footer and author is absent from app bar',
      (WidgetTester tester) async {
    await tester.pumpWidget(const GitSnapApp());
    await tester.pump();

    expect(
      find.text('GitSnap · Versione ${UpdateService.version.split('+').first}'),
      findsOneWidget,
    );
    expect(find.text('Realizzato da M. Contursi'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.textContaining('Contursi'),
      ),
      findsNothing,
    );
    expect(find.text('GitSnap – Confronto Ambienti'), findsOneWidget);
  });
}
