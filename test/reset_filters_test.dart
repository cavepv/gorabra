import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';
import 'package:gorabra/services/location_lookup.dart';

/// Reset-filters button: hidden while every filter is at its default,
/// appears once a filter is touched, and clears everything back to
/// defaults in one tap (see planner-ui spec).
void main() {
  testWidgets('Reset button appears only when a filter is active and '
      'restores defaults on tap', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GorabraApp(
        positionFetcher: () async =>
            const UserPosition(lat: 57.7089, lng: 11.9746),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('moreFiltersTile')));
    await tester.pumpAndSettle();

    final resetButton = find.byKey(const Key('resetFiltersButton'));
    expect(resetButton, findsNothing);

    // Touch a filter — "Stanna hemma" toggle.
    await tester.tap(find.text('Stanna hemma'));
    await tester.pumpAndSettle();

    expect(resetButton, findsOneWidget);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Stanna hemma'),
          )
          .value,
      isTrue,
    );

    await tester.tap(resetButton);
    await tester.pumpAndSettle();

    expect(resetButton, findsNothing);
    expect(
      tester
          .widget<SwitchListTile>(
            find.widgetWithText(SwitchListTile, 'Stanna hemma'),
          )
          .value,
      isFalse,
    );
  });
}
