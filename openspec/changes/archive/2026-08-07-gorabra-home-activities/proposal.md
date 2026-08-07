## Why

Some days a family just doesn't want to leave the house — rain, a sick kid,
low energy — and the app currently has no way to say "I don't want to go
anywhere" other than picking `budget: free` and hoping an indoor activity
comes up. There's no way to get suggestions scoped to things you do at home.

## What Changes

- New `Activity.homeOnly` field (bool, default `false`) marking an activity
  as a stay-at-home suggestion (no location/transport/opening hours apply).
- 9 new curated home activities added to `activities.json` (pillow fort,
  kitchen disco, indoor scavenger hunt, baking, board game night, home
  cinema + craft break, kitchen science, upcycled craft workshop, living
  room obstacle course), reusing the existing schema with placeholder
  `distanceKm: 0`, `transportModes: []`, `openingHours: "Alltid"`,
  `location: "Hemma"`, and real `cost`/`interests` tags.
- New `UserPreferences.stayHome` bool (default `false`). When `true`, the
  recommender hard-filters to `homeOnly` activities only; when `false`,
  `homeOnly` activities are excluded from normal results. This filter is
  never relaxed (same tier as cost/transport).
- New "Stanna hemma" `SwitchListTile` toggle in the planner form,
  independent of the Idag/Imorgon day selector. Weather is still fetched
  when the toggle is on (unused for filtering in that case).

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `activity-catalog`: schema gains an optional `homeOnly` field.
- `activity-recommender`: adds a `stayHome` hard filter tier (never
  relaxed), applied alongside cost/transport in the base pool.
- `planner-ui`: form gains a "Stanna hemma" toggle.

## Impact

- `lib/models/activity.dart`: new `homeOnly` field, `fromJson` default.
- `assets/data/activities.json`: 9 new entries.
- `lib/services/recommender.dart`: `UserPreferences.stayHome`, base-pool
  filter.
- `lib/screens/planner_screen.dart`: `_stayHome` state, toggle widget,
  `_spin()` wiring.
- `test/recommender_test.dart`, `test/widget_test.dart`: new coverage.
- No new dependencies; no changes to `weather_lookup.dart`.
