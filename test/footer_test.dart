import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/main.dart';
import 'package:gorabra/services/location_lookup.dart';

/// Footer: version + copyright shown at the bottom of the page.
void main() {
  testWidgets('Shows version and copyright footer', (
    WidgetTester tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(800, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      GorabraApp(
        positionFetcher: () async =>
            const UserPosition(lat: 57.7089, lng: 11.9746),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('© 2026 Hittpå'), findsOneWidget);
    expect(find.textContaining('v1.5.0'), findsOneWidget);
  });
}
