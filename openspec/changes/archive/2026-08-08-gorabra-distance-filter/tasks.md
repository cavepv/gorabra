## 1. Data model and catalog

- [x] 1.1 In `lib/models/activity.dart`, add nullable `final double? lat`
  and `final double? lng` fields, constructor params (default `null`), and
  `fromJson` parsing via `(json['lat'] as num?)?.toDouble()`.
- [x] 1.2 Add real approximate Gothenburg coordinates to the 21 non-`homeOnly`
  entries in `assets/data/activities.json`. The 9 `homeOnly` entries are
  left without `lat`/`lng` (distance filtering doesn't apply to them).

## 2. Distance math and location service

- [x] 2.1 Create `lib/services/distance.dart` with a `haversineKm(lat1,
  lng1, lat2, lng2)` function using `dart:math` (Earth radius 6371km, no
  external package).
- [x] 2.2 Run `flutter pub add geolocator` for real GPS access (no stdlib
  equivalent exists).
- [x] 2.3 Create `lib/services/location_lookup.dart`: `UserPosition`
  (lat/lng) and `LocationLookup.getCurrentPosition()` — checks location
  service enabled, requests permission if needed, fetches position with
  medium accuracy and a 10s timeout, and collapses every failure mode
  (service off, permission denied, timeout, plugin error) to `null` so it
  never throws.

## 3. Recommender: distance hard filter

- [x] 3.1 In `lib/services/recommender.dart`, add nullable
  `maxDistanceKm`/`userLat`/`userLng` to `UserPreferences` (all default
  `null` = filter off).
- [x] 3.2 Add a private `_matchesDistance(Activity, UserPreferences)`
  method: passes if the filter is off (any of the three params null), if
  the activity is `homeOnly` (exempt, same pattern as the `hasCar`
  exemption), or if the activity has no `lat`/`lng`; otherwise computes
  `haversineKm` and compares to `maxDistanceKm`.
- [x] 3.3 Wire `_matchesDistance` into the base-pool filter alongside
  `withinBudget`/`reachable`/`homeMatch` — never relaxed.
- [x] 3.4 Update the `ActivityRecommender` doc comment to mention the
  distance-radius tier.

## 4. Planner screen: position switch, slider, wiring

- [x] 4.1 Change `PlannerScreen`'s constructor to accept an injectable
  `Future<UserPosition?> Function()? positionFetcher`, defaulting to
  `LocationLookup.getCurrentPosition` (mirrors the `Random? random` seam
  on `ActivityRecommender`). Keep it `const`-constructible.
- [x] 4.2 Thread the same optional `positionFetcher` through
  `lib/main.dart`'s `GorabraApp` so tests can inject a fake without
  touching real GPS.
- [x] 4.3 Add state: `_useMyPosition`, `_maxDistanceKm` (default 5),
  `_userPosition`, `_locatingPosition`, `_locationError`.
- [x] 4.4 Add an `ExpansionTile` "Avstånd" section in `_buildForm()`
  containing a "Använd min position" `SwitchListTile` (fetches position
  once on toggle-on, caches for the session, shows inline error on
  failure) and a `Slider` (1–50km, step 1km, default 5km) enabled only
  once a position is available.
- [x] 4.5 Disable the whole section's position switch while `_stayHome` is
  true (distance filtering is moot in that mode).
- [x] 4.6 Wire `maxDistanceKm`/`userLat`/`userLng` into `_spin()`'s
  `UserPreferences`, only when a position is actually available and
  `_stayHome` is false.

## 5. Tests

- [x] 5.1 In `test/recommender_test.dart`, add `lat`/`lng` params to the
  `_activity()` test helper.
- [x] 5.2 Add cases: activities within radius pass, outside radius are
  excluded, the filter is never relaxed (even for matching interests),
  `homeOnly` activities are exempt regardless of distance, and the filter
  is off entirely when `maxDistanceKm` is null.
- [x] 5.3 In `test/widget_test.dart`, inject a fake `positionFetcher` via
  `GorabraApp`, expand the "Avstånd" section, toggle "Använd min
  position", and assert the slider becomes enabled with no error shown
  (kept in the existing single `testWidgets` block per the documented
  double-pump flakiness).

## 6. Verification

- [x] 6.1 Run `flutter analyze` — no new issues.
- [x] 6.2 Run `flutter test` — all tests pass, including new distance
  cases.
- [x] 6.3 Update `openspec/specs/activity-catalog`, `activity-recommender`,
  and `planner-ui` specs with the `lat`/`lng`/distance-filter deltas.
