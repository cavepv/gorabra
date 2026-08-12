import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';
import 'package:gorabra/services/location_lookup.dart';

/// Back/forward spin history: enabled/disabled state must track the
/// current position, and changing a filter must wipe history (see
/// planner-ui spec — history follows browser-tab semantics).
void main() {
  testWidgets('Back/forward buttons track spin history and reset on filter change', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GorabraApp(positionFetcher: () async => const UserPosition(lat: 57.7089, lng: 11.9746)),
    );
    await tester.pumpAndSettle();

    // "Stanna hemma" lives behind the collapsed "Fler filter" section.
    await tester.tap(find.byKey(const Key('moreFiltersTile')));
    await tester.pumpAndSettle();

    bool backEnabled() =>
        tester.widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_back)).onPressed !=
        null;
    bool forwardEnabled() =>
        tester
            .widget<IconButton>(find.widgetWithIcon(IconButton, Icons.arrow_forward))
            .onPressed !=
        null;

    // No history yet — both disabled.
    expect(backEnabled(), isFalse);
    expect(forwardEnabled(), isFalse);

    // First spin: one history entry, still nothing to go back/forward to.
    await tester.tap(find.text('Ge mig tips!'));
    await tester.pumpAndSettle();
    expect(backEnabled(), isFalse);
    expect(forwardEnabled(), isFalse);

    // Second spin: two entries, sitting on the newest — back enabled.
    await tester.tap(find.text('Nya förslag'));
    await tester.pumpAndSettle();
    expect(backEnabled(), isTrue);
    expect(forwardEnabled(), isFalse);

    // Step back: now forward should light up too.
    await tester.tap(find.byIcon(Icons.arrow_back));
    await tester.pumpAndSettle();
    expect(backEnabled(), isFalse);
    expect(forwardEnabled(), isTrue);

    // Step forward again: back to the newest entry.
    await tester.tap(find.byIcon(Icons.arrow_forward));
    await tester.pumpAndSettle();
    expect(backEnabled(), isTrue);
    expect(forwardEnabled(), isFalse);

    // Changing a filter wipes history entirely.
    await tester.tap(find.text('Stanna hemma'));
    await tester.pumpAndSettle();
    expect(backEnabled(), isFalse);
    expect(forwardEnabled(), isFalse);
    expect(find.text('Ge mig tips!'), findsOneWidget);
  });
}
