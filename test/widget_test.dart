import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';
import 'package:gorabra/services/location_lookup.dart';

void main() {
  testWidgets('Planner form loads and can spin for suggestions', (
    WidgetTester tester,
  ) async {
    // The form (age slider, interest chips, budget, car switch, spin
    // button) is taller than the default 800x600 test surface, so it
    // scrolls the "Ge mig tips!" button below the fold. A ListView's offstage
    // children exist in the widget tree but are excluded by finders'
    // default skipOffstage behavior, so grow the surface to fit everything.
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Real GPS isn't available in the widget-test environment (no platform
    // channel reply ever arrives), so inject a fake fetcher instead of
    // letting PlannerScreen fall through to the real geolocator plugin.
    await tester.pumpWidget(
      GorabraApp(positionFetcher: () async => const UserPosition(lat: 57.7089, lng: 11.9746)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hittepå'), findsOneWidget);
    expect(find.text('Ge mig tips!'), findsOneWidget);
    // Flutter's test HTTP binding always returns 400 for any request, so
    // the weather fetch fails deterministically — the hourly graph's
    // unavailable-fallback message is what should render here.
    expect(find.text('Väder ej tillgängligt just nu.'), findsOneWidget);

    await tester.tap(find.text('Ge mig tips!'));
    await tester.pumpAndSettle();

    // Either a result card or the "no matches" message should appear.
    final hasResult = find.byType(Card).evaluate().isNotEmpty;
    final hasNoMatchMessage =
        find.text('Inga aktiviteter matchar dina val just nu.').evaluate().isNotEmpty;
    expect(hasResult || hasNoMatchMessage, isTrue);

    // Grouped controls (Intressen, Budget, car, Stanna hemma, Avstånd) live
    // behind the collapsed "Fler filter" section — expand it once before
    // interacting with any of them.
    await tester.tap(find.byKey(const Key('moreFiltersTile')));
    await tester.pumpAndSettle();

    // Toggle "Stanna hemma" and re-spin in the same app instance — pumping
    // a second full GorabraApp tree in this test file hangs on the second
    // pumpAndSettle (pre-existing issue unrelated to this toggle), so this
    // reuses the already-pumped tree instead of a second testWidgets block.
    expect(find.text('Stanna hemma'), findsOneWidget);
    await tester.tap(find.text('Stanna hemma'));
    await tester.pumpAndSettle();

    // Toggling "Stanna hemma" clears the previous result, so the button
    // reverts to its initial label.
    await tester.ensureVisible(find.text('Ge mig tips!'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ge mig tips!'));
    await tester.pumpAndSettle();

    final hasResultAfterToggle = find.byType(Card).evaluate().isNotEmpty;
    final hasNoMatchAfterToggle =
        find.text('Inga aktiviteter matchar dina val just nu.').evaluate().isNotEmpty;
    expect(hasResultAfterToggle || hasNoMatchAfterToggle, isTrue);

    // Turn "Stanna hemma" back off so the distance section is enabled, then
    // expand it and toggle "Använd min position" with the injected fake
    // fetcher above — should resolve to a position (no error) and enable
    // the distance slider.
    await tester.ensureVisible(find.text('Stanna hemma'));
    await tester.tap(find.text('Stanna hemma'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Avstånd'));
    await tester.tap(find.text('Avstånd'));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Använd min position'));
    await tester.tap(find.text('Använd min position'));
    await tester.pumpAndSettle();

    expect(find.text('Kunde inte hämta din position.'), findsNothing);
    final sliderFinder = find.descendant(
      of: find
          .ancestor(
            of: find.text('Använd min position'),
            matching: find.byType(ExpansionTile),
          )
          .first,
      matching: find.byType(Slider),
    );
    final slider = tester.widget<Slider>(sliderFinder);
    expect(slider.onChanged, isNotNull);
  });
}
