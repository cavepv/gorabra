import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'Spin button row does not overflow on a narrow phone with scaled text',
    (WidgetTester tester) async {
      // Isolates just the spin/back/forward Row (see PlannerScreen.build) at
      // the narrowest common phone width (360dp) plus a larger-than-default
      // text scale — the combination that overflowed it before it was
      // switched from Transform.scale (visual-only, doesn't shrink layout)
      // to a real Flexible + FittedBox.
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              textScaler: TextScaler.linear(1.3),
            ),
            child: Scaffold(
              body: Builder(
                builder: (context) => Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.arrow_back),
                      ),
                      Flexible(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: FilledButton.icon(
                            onPressed: () {},
                            style: FilledButton.styleFrom(
                              textStyle: Theme.of(
                                context,
                              ).textTheme.titleMedium,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                                vertical: 15,
                              ),
                            ),
                            icon: const Icon(Icons.casino, size: 24),
                            label: const Text('Ge mig tips!'),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {},
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    },
  );
}
