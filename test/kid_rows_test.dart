import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';

void main() {
  testWidgets('Kid rows can be added up to the cap and removed down to one', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2000));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GorabraApp());
    await tester.pumpAndSettle();

    // Starts with exactly one kid row — no remove control shown.
    expect(find.text('Barn 1: 4 år'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);

    final addButton = find.text('Lägg till barn');

    // Add up to the cap of 4 kids.
    for (var i = 2; i <= 4; i++) {
      await tester.tap(addButton);
      await tester.pumpAndSettle();
      expect(find.text('Barn $i: 4 år'), findsOneWidget);
    }

    // "+" is disabled at the cap.
    final addButtonWidget = tester.widget<TextButton>(
      find.ancestor(of: addButton, matching: find.byType(TextButton)),
    );
    expect(addButtonWidget.onPressed, isNull);

    // Remove down to one kid; remove control disappears at exactly one.
    expect(find.byIcon(Icons.close), findsNWidgets(4));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.byIcon(Icons.close).first);
      await tester.pumpAndSettle();
    }
    expect(find.text('Barn 1: 4 år'), findsOneWidget);
    expect(find.byIcon(Icons.close), findsNothing);
  });
}
