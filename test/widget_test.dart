import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';

void main() {
  testWidgets('Planner form loads and can spin for suggestions', (
    WidgetTester tester,
  ) async {
    // The form (age slider, kid/parent interest chips, budget, car switch,
    // spin button) is taller than the default 800x600 test surface, so it
    // scrolls the "Spinna" button below the fold. A ListView's offstage
    // children exist in the widget tree but are excluded by finders'
    // default skipOffstage behavior, so grow the surface to fit everything.
    await tester.binding.setSurfaceSize(const Size(800, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GorabraApp());
    await tester.pumpAndSettle();

    expect(find.text('Görabra'), findsOneWidget);
    expect(find.text('Spinna'), findsOneWidget);

    await tester.tap(find.text('Spinna'));
    await tester.pumpAndSettle();

    // Either a result card or the "no matches" message should appear.
    final hasResult = find.byType(Card).evaluate().isNotEmpty;
    final hasNoMatchMessage =
        find.text('Inga aktiviteter matchar dina val just nu.').evaluate().isNotEmpty;
    expect(hasResult || hasNoMatchMessage, isTrue);
  });
}
