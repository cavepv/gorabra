import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/screens/planner_screen.dart';
import 'package:gorabra/services/weather_lookup.dart';

/// Regression test: centering the body/appbar in a ConstrainedBox for the
/// desktop layout must not break the hourly weather strip's horizontal
/// scroll (it needs a bounded — not shrink-wrapped — width to lay out its
/// `Expanded`/`SingleChildScrollView`).
void main() {
  testWidgets(
    'Hourly weather strip stays scrollable on a wide (desktop) window',
    (WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(1400, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final now = DateTime.now();
      final hourly = [
        for (var h = 0; h < 24; h++)
          HourlyPoint(
            time: DateTime(now.year, now.month, now.day, h),
            temperatureC: 15,
            apparentTemperatureC: 15,
            precipitationMm: 0,
            weatherCode: 0,
            windSpeedMs: 2,
          ),
      ];

      await tester.pumpWidget(
        MaterialApp(
          home: PlannerScreen(
            weatherFetcher: () async =>
                WeatherForecast(today: hourly, tomorrow: hourly),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350)); // let weather load

      final scrollFinder = find.byWidgetPredicate(
        (w) =>
            w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(scrollFinder, findsOneWidget);

      final scrollable = find.descendant(
        of: scrollFinder,
        matching: find.byType(Scrollable),
      );

      // Mouse click-drag specifically — the default ScrollBehavior excludes
      // PointerDeviceKind.mouse from dragDevices, so a touch-kind drag (the
      // TestGesture default) would pass even if desktop/mouse users are
      // silently unable to scroll the strip at all.
      final before = tester.state<ScrollableState>(scrollable).position.pixels;
      final gesture = await tester.startGesture(
        tester.getCenter(scrollable),
        kind: PointerDeviceKind.mouse,
      );
      await gesture.moveBy(const Offset(-200, 0));
      await tester.pump();
      await gesture.up();
      final after = tester.state<ScrollableState>(scrollable).position.pixels;

      expect(after, greaterThan(before));
    },
  );
}
