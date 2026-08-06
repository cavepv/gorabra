## 1. Recommender: age intersection

- [x] 1.1 In `lib/services/recommender.dart`, change `UserPreferences.kidAge:
  int` to `kidAges: List<int>` (required, assert non-empty in the
  constructor).
- [x] 1.2 Update `matchesAge` to
  `prefs.kidAges.every((age) => age >= a.minAge && age <= a.maxAge)`.
- [x] 1.3 Update the doc comment on `ActivityRecommender` if it references
  the old single-age wording.

## 2. Planner screen: state and spin wiring

- [x] 2.1 In `lib/screens/planner_screen.dart`, replace `int _kidAge = 4;`
  with `final List<int> _kidAges = [4];`.
- [x] 2.2 Update `_spin()` to pass `kidAges: _kidAges` instead of
  `kidAge: _kidAge` when constructing `UserPreferences`.
- [x] 2.3 Add `_addKid()` (appends age 4, no-op if already at 4 entries) and
  `_removeKid(int index)` (no-op if only 1 entry remains) helper methods,
  each calling `setState` and clearing `_result` (consistent with other
  input-changing handlers already clearing stale results).

## 3. Planner screen: form UI

- [x] 3.1 Replace the single kid-age `Slider` section with a loop over
  `_kidAges` rendering one row per kid: existing slider widget/style bound
  to that index's age, plus a remove `IconButton` (icon e.g.
  `Icons.close`) that calls `_removeKid(index)`, hidden or disabled when
  `_kidAges.length == 1`.
- [x] 3.2 Add an "+ Lägg till barn" `TextButton`/`OutlinedButton` below the
  kid rows that calls `_addKid()`, disabled when `_kidAges.length == 4`.
- [x] 3.3 Adjust any surrounding label text (e.g. "Barnets ålder") to
  reflect one label per row instead of a single shared label, if needed for
  clarity with multiple rows.

## 4. Tests

- [x] 4.1 In `test/recommender_test.dart`, add a case with `kidAges: [5,
  7]` against a catalog containing an activity whose range covers both
  (e.g. 5-10) and one that only covers one (e.g. 3-6), asserting only the
  covering activity is selectable.
- [x] 4.2 Add a case with non-overlapping `kidAges` (e.g. `[3, 12]`) against
  a catalog with no activity spanning both, asserting the existing
  age-relaxation fallback still returns a non-empty, `isClosestMatch: true`
  result.
- [x] 4.3 In `test/widget_test.dart`, add coverage for tapping "+ Lägg till
  barn" to add a row, tapping remove on a row to remove it, and confirming
  the remove control is absent/disabled at exactly one row.

## 5. Verification

- [x] 5.1 Run `flutter analyze` — no new issues.
- [x] 5.2 Run `flutter test` — all tests pass, including the new cases from
  section 4.
- [x] 5.3 Manually smoke-test in a running instance: add up to 4 kids,
  remove down to 1, confirm spin results respect all ages and the "+"
  button disables at the cap.
