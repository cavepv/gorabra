## Why

The planner currently accepts one kid age via a single slider. Families with
more than one kid can't get a recommendation that actually works for all
their kids at once — they have to guess an age or run the spin multiple
times and reconcile results manually.

## What Changes

- **BREAKING**: `RecommenderPrefs.kidAge: int` becomes `kidAges: List<int>`
  (1-4 entries, defaulting to `[4]`).
- Age hard-filter now requires an activity's `[minAge, maxAge]` range to
  cover *every* kid's age (intersection), not just one age.
- Planner form gains a repeatable "kid" row: each kid has its own age slider
  (reusing the existing slider widget), a "+ Lägg till barn" control to add
  a kid (capped at 4), and a remove (X) control per row, hidden when only
  one kid remains.
- Progressive relaxation fallback (interests → weather → age) is unchanged:
  if the multi-kid age intersection empties the pool, age is still the last
  filter relaxed, same as today's single-kid behavior.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `activity-recommender`: age hard filter changes from a single `kidAge`
  match to an intersection match across a list of kid ages; relaxation
  order and all other filter/scoring behavior unchanged.
- `planner-ui`: input form changes from a single kid-age slider to a
  repeatable, cappped (max 4, min 1) list of kid-age rows.

## Impact

- `lib/services/recommender.dart`: `RecommenderPrefs` shape and age-match
  predicate.
- `lib/screens/planner_screen.dart`: state (`_kidAge` → `_kidAges`), form
  UI (add/remove kid rows).
- `test/recommender_test.dart`: extend with a multi-age intersection case.
- `test/widget_test.dart`: extend with add/remove kid row coverage.
- No new dependencies; no changes to `weather_lookup.dart` or
  `activity_catalog.dart`.
