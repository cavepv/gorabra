## 1. Data model and catalog

- [x] 1.1 In `lib/models/activity.dart`, add `final bool homeOnly` field,
  default `false` in the constructor, and read it in `fromJson` as
  `json['homeOnly'] as bool? ?? false` (existing 21 entries need no JSON
  change).
- [x] 1.2 Add 9 new entries to `assets/data/activities.json`, each with
  `homeOnly: true`, `indoor: true`, `distanceKm: 0`, `transportModes: []`,
  `openingHours: "Alltid"`, `location: "Hemma"`, and real `cost`/
  `interests`/`benefits` tags spanning free→low cost.

## 2. Recommender: stayHome hard filter

- [x] 2.1 In `lib/services/recommender.dart`, add `final bool stayHome`
  (default `false`) to `UserPreferences`.
- [x] 2.2 In `recommend()`'s base-pool filter, add a `homeMatch` check:
  `prefs.stayHome ? a.homeOnly : !a.homeOnly`, alongside the existing
  never-relaxed `withinBudget`/`reachable` checks.
- [x] 2.3 Update the `ActivityRecommender` doc comment to mention the
  stayHome/homeOnly tier.

## 3. Planner screen: toggle and wiring

- [x] 3.1 Add `bool _stayHome = false;` state.
- [x] 3.2 Add a `SwitchListTile` "Stanna hemma" toggle in `_buildForm()`
  near the budget/car controls, clearing `_result` on change (consistent
  with other input handlers).
- [x] 3.3 Pass `stayHome: _stayHome` when constructing `UserPreferences` in
  `_spin()`.

## 4. Tests

- [x] 4.1 In `test/recommender_test.dart`, add `homeOnly` param to the
  `_activity()` test helper.
- [x] 4.2 Add a case: `stayHome: false` excludes `homeOnly: true`
  activities from the pool.
- [x] 4.3 Add a case: `stayHome: true` hard-filters to the `homeOnly` pool
  and is never relaxed (even when interests don't match).
- [x] 4.4 In `test/widget_test.dart`, extend the existing test to toggle
  "Stanna hemma" and re-spin, asserting a result or "no matches" message
  still renders (kept in the same `testWidgets` block — pumping a second
  full `GorabraApp` in the same test file hangs on its second
  `pumpAndSettle`, a pre-existing issue unrelated to this change).

## 5. Verification

- [x] 5.1 Run `flutter analyze` — no new issues.
- [x] 5.2 Run `flutter test` — all tests pass, including new stayHome
  cases.
- [x] 5.3 Update `openspec/specs/activity-catalog`, `activity-recommender`,
  and `planner-ui` specs with the `homeOnly`/`stayHome` deltas.
