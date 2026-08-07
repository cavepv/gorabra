## Why

Families often spin the app while already out and about (at a park, in
town) rather than always from home, and want suggestions genuinely nearby
— not just filtered by the manual `distanceKm` estimate from city center.
There's currently no way to filter by real closeness to the user's actual
position.

## What Changes

- New optional `Activity.lat`/`Activity.lng` fields (nullable doubles).
  Added real coordinates to the 21 non-home activities; the 9 `homeOnly`
  activities intentionally have none (distance doesn't apply to them).
- New `lib/services/distance.dart` with a hand-rolled haversine distance
  function (no new dependency needed for ~10 lines of math).
- New `geolocator` dependency + `lib/services/location_lookup.dart`
  wrapping it behind an injectable `UserPosition? Function()` seam
  (mirrors the existing `Random? random` pattern on `ActivityRecommender`).
  All failure modes (permission denied, service off, timeout) collapse to
  `null` — the wrapper never throws.
- New `UserPreferences.maxDistanceKm`/`userLat`/`userLng` (all nullable,
  default `null` = filter off). Recommender adds a `_matchesDistance` hard
  filter (never relaxed), exempting `homeOnly` activities the same way the
  `hasCar` check is exempted.
- New "Avstånd" `ExpansionTile` in the planner form: a "Använd min
  position" switch (fetches position once per toggle-on, cached for the
  session) and a 1–50km slider (default 5km, step 1km). Disabled while
  "Stanna hemma" is active. On fetch failure, shows an inline error and
  leaves the filter off rather than blocking the spin.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `activity-catalog`: schema gains optional `lat`/`lng` fields.
- `activity-recommender`: adds a distance-radius hard filter tier (never
  relaxed), exempting `homeOnly` activities.
- `planner-ui`: form gains an "Avstånd" section (position switch + slider).

## Impact

- `lib/models/activity.dart`: new `lat`/`lng` fields, `fromJson` parsing.
- `assets/data/activities.json`: `lat`/`lng` added to 21 non-home entries.
- `lib/services/distance.dart`: new haversine helper.
- `lib/services/location_lookup.dart`: new GPS wrapper (`UserPosition`,
  `LocationLookup.getCurrentPosition()`).
- `lib/services/recommender.dart`: `UserPreferences.maxDistanceKm`/
  `userLat`/`userLng`, `_matchesDistance` base-pool filter.
- `lib/screens/planner_screen.dart`: injectable `positionFetcher`
  constructor param, distance-section state, `ExpansionTile` UI,
  `_spin()` wiring.
- `lib/main.dart`: `GorabraApp` gains an optional `positionFetcher`
  pass-through (for testability without real GPS in widget tests).
- `pubspec.yaml`: new `geolocator` dependency.
- `test/recommender_test.dart`, `test/widget_test.dart`: new coverage.
