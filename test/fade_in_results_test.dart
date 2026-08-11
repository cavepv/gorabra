import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';

/// Result cards fade+slide in staggered (1, 2, 3) after each spin — see
/// planner-ui spec. Verifies the stagger ordering and that cards end up
/// fully visible, without depending on the private _FadeInCard widget.
void main() {
  testWidgets('Result cards fade in staggered after a spin', (WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(const GorabraApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350)); // let weather lookup fail/settle

    await tester.tap(find.text('Ge mig tips!'));
    await tester.pump(); // start _spin's loading state
    await tester.pump(const Duration(milliseconds: 300)); // clear artificial spin delay
    await tester.pump(); // build result cards, animation starts at t=0

    final cards = find.byType(Card);
    expect(cards.evaluate().length, greaterThanOrEqualTo(1));

    Opacity opacityOfCard(int index) => tester.widget<Opacity>(
      find.ancestor(of: cards.at(index), matching: find.byType(Opacity)).first,
    );

    // Shortly after the cards appear, earlier cards (smaller stagger delay)
    // must be at least as visible as later ones — enforces the 1, 2, 3
    // reveal order rather than all cards fading in unison.
    await tester.pump(const Duration(milliseconds: 60));
    final opacities = List.generate(cards.evaluate().length, (i) => opacityOfCard(i).opacity);
    for (var i = 1; i < opacities.length; i++) {
      expect(
        opacities[i - 1],
        greaterThanOrEqualTo(opacities[i]),
        reason: 'card $i should not be more visible than card ${i - 1} mid-stagger',
      );
    }

    // Once settled, every card is fully visible.
    await tester.pumpAndSettle();
    for (var i = 0; i < cards.evaluate().length; i++) {
      expect(opacityOfCard(i).opacity, 1.0);
    }
  });
}
