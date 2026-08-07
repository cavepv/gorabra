import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';

void main() {
  testWidgets('Planner form loads and can spin for suggestions', (
    WidgetTester tester,
  ) async {
    // The form (age slider, kid/parent interest chips, budget, car switch,
    // spin button) is taller than the default 800x600 test surface, so it
    // scrolls the "Föreslå" button below the fold. A ListView's offstage
    // children exist in the widget tree but are excluded by finders'
    // default skipOffstage behavior, so grow the surface to fit everything.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GorabraApp());
    await tester.pumpAndSettle();

    expect(find.text('Görabra'), findsOneWidget);
    expect(find.text('Föreslå'), findsOneWidget);
    // Flutter's test HTTP binding always returns 400 for any request, so
    // the weather fetch fails deterministically — the hourly graph's
    // unavailable-fallback message is what should render here.
    expect(find.text('Väder ej tillgängligt just nu.'), findsOneWidget);

    await tester.tap(find.text('Föreslå'));
    await tester.pumpAndSettle();

    // Either a result card or the "no matches" message should appear.
    final hasResult = find.byType(Card).evaluate().isNotEmpty;
    final hasNoMatchMessage =
        find.text('Inga aktiviteter matchar dina val just nu.').evaluate().isNotEmpty;
    expect(hasResult || hasNoMatchMessage, isTrue);

    // Toggle "Stanna hemma" and re-spin in the same app instance — pumping
    // a second full GorabraApp tree in this test file hangs on the second
    // pumpAndSettle (pre-existing issue unrelated to this toggle), so this
    // reuses the already-pumped tree instead of a second testWidgets block.
    expect(find.text('Stanna hemma'), findsOneWidget);
    await tester.tap(find.text('Stanna hemma'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Föreslå'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Föreslå'));
    await tester.pumpAndSettle();

    final hasResultAfterToggle = find.byType(Card).evaluate().isNotEmpty;
    final hasNoMatchAfterToggle =
        find.text('Inga aktiviteter matchar dina val just nu.').evaluate().isNotEmpty;
    expect(hasResultAfterToggle || hasNoMatchAfterToggle, isTrue);
  });
}
