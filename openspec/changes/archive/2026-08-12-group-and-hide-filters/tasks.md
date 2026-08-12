## 1. UI grouping

- [x] 1.1 Wrap Intressen, Budget, Tillgång till bil, Stanna hemma, and
      Avstånd sections in `planner_screen.dart` in a single
      `ExpansionTile` titled "Fler filter", collapsed by default, in that
      order. Keep kid age rows outside/above the tile.

## 2. Test updates

- [x] 2.1 Update `budget_field_test.dart`, `widget_test.dart`, and
      `kid_rows_test.dart` to expand "Fler filter" before interacting
      with grouped controls, if those controls are now inside the tile.

## 3. Verification

- [x] 3.1 Run `flutter analyze` and `flutter test` (full suite); fix any
      failures.
- [x] 3.2 Manually confirm: fresh app load shows only kid age + collapsed
      "Fler filter" header, and expanding reveals all five controls in
      order, and a spin works without ever expanding it.
