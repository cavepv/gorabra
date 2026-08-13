import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';
import 'package:gorabra/services/location_lookup.dart';

/// Budget slider/textfield: they must stay in sync and both clamp to
/// [0, 10000] kr (see planner-ui spec — "Setting budget via the textfield").
void main() {
  testWidgets('Budget textfield updates and clamps, slider stays in sync', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GorabraApp(positionFetcher: () async => const UserPosition(lat: 57.7089, lng: 11.9746)),
    );
    await tester.pumpAndSettle();

    // Budget lives behind the collapsed "Fler filter" section.
    await tester.tap(find.byKey(const Key('moreFiltersTile')));
    await tester.pumpAndSettle();

    final fieldFinder = find.byKey(const Key('budgetField'));
    expect(fieldFinder, findsOneWidget);

    // Typing a valid in-range amount updates the field as-is.
    await tester.enterText(fieldFinder, '500');
    await tester.pumpAndSettle();
    expect(find.text('500'), findsOneWidget);
    final sliderFinder = find.byKey(const Key('budgetSlider'));
    expect(tester.widget<Slider>(sliderFinder).value, 500);

    // Typing above the 10000 kr ceiling clamps both the field and slider.
    await tester.enterText(fieldFinder, '15000');
    await tester.pumpAndSettle();
    expect(find.text('10000'), findsOneWidget);
    expect(tester.widget<Slider>(sliderFinder).value, 10000);

    // Dragging the slider down to the minimum shows "Gratis", not "0 kr".
    tester.widget<Slider>(sliderFinder).onChanged!(0);
    await tester.pump();
    expect(find.text('Gratis'), findsOneWidget);
    expect(find.text('0'), findsNothing);
    expect(find.text('kr'), findsNothing);
  });
}
