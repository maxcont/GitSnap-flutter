import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gitsnap_flutter/services/update_service.dart';
import 'package:gitsnap_flutter/widgets/app_footer.dart';

void main() {
  Widget app(double width) => MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(width: width, child: const AppFooter()),
          ),
        ),
      );

  final version =
      find.text('GitSnap · Versione ${UpdateService.version.split('+').first}');
  final author = find.text('Realizzato da M. Contursi');

  testWidgets('wide footer places version left and author right',
      (tester) async {
    await tester.pumpWidget(app(700));
    expect(tester.getTopLeft(version).dx, 0);
    expect(tester.getTopRight(author).dx, 700);
    expect(tester.getCenter(author).dy, tester.getCenter(version).dy);
    expect(find.textContaining('+3'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('narrow footer stacks author below version without overflow',
      (tester) async {
    await tester.pumpWidget(app(240));
    expect(tester.getTopLeft(author).dy,
        greaterThan(tester.getBottomLeft(version).dy));
    expect(tester.getTopLeft(author).dx, tester.getTopLeft(version).dx);
    expect(tester.takeException(), isNull);
  });
}
