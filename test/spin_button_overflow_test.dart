import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/screens/planner_screen.dart';
import 'package:gorabra/services/weather_lookup.dart';

void main() {
  testWidgets(
    'Spin button row does not overflow on a narrow phone with scaled text',
    (WidgetTester tester) async {
      // Pumps the real PlannerScreen (not a hand-copied widget tree) at the
      // narrowest common phone width (360dp) plus a larger-than-default
      // text scale — the combination that overflowed it before it was
      // switched from Transform.scale (visual-only, doesn't shrink layout)
      // to a real Flexible + FittedBox. Using the real widget means this
      // test keeps guarding the actual button (icon, spinner, wording)
      // instead of drifting out of sync with it.
      await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: PlannerScreen(
              positionFetcher: () async => null,
              weatherFetcher: () async => const WeatherForecast(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(
        const Duration(milliseconds: 350),
      ); // let weather settle

      expect(tester.takeException(), isNull);

      // Tap spin and check mid-flight too — the loading state swaps the
      // icon for a CircularProgressIndicator inside the same Row, which is
      // exactly the layout this test exists to guard.
      await tester.tap(find.text('Ge mig tips!'));
      await tester.pump(); // enter loading state (spinner shown)
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(milliseconds: 300)); // clear spin delay
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
