## 1. Project setup

- [x] 1.1 Create Flutter project (`flutter create .` in `~/Görabra`) with app name "Görabra"
- [x] 1.2 Add `http` package dependency for Open-Meteo calls
- [x] 1.3 Set up `flutter analyze` / `flutter test` baseline (no custom lint config beyond Flutter defaults)

## 2. Activity catalog data

- [x] 2.1 Define the activity data model (Dart class) matching the locked schema: `id`, `name`, `description`, `minAge`, `maxAge`, `indoor`, `interests`, `parentInterest`, `social`, `benefits`, `benefitNote`, `openingHours`, `location`, `distanceKm`, `transportModes`, `cost`
- [x] 2.2 Add a bundled JSON asset with at least 20 hand-curated Gothenburg activities covering a range of ages, indoor/outdoor, cost tiers, and transport modes, each with a real `benefitNote`
- [x] 2.3 Implement catalog loading from the bundled JSON asset (no network call)

## 3. Weather lookup

- [x] 3.1 Implement an Open-Meteo client call for Gothenburg's current weather (no API key)
- [x] 3.2 Implement classification of fetched weather into indoor-favoring vs. outdoor-favoring
- [x] 3.3 Implement fallback behavior when the weather fetch fails: treat weather as unknown, skip the weather filter tier

## 4. Recommendation engine

- [x] 4.1 Implement hard filters: kid age range, weather (indoor/outdoor), cost vs. budget, transport modes vs. hasCar
- [x] 4.2 Implement progressive relaxation order (interests → weather → age) that stops as soon as the pool is non-empty, never relaxing cost or transport
- [x] 4.3 Implement "closest matches" fallback pool (cost/transport-filtered only) for when full relaxation still yields zero results
- [x] 4.4 Implement soft-score weighting via candidate duplication for `parentInterest` match, `social: true`, and `benefits` containing `physicalActivity`
- [x] 4.5 Implement random pick of 1-3 activities from the final weighted candidate pool
- [x] 4.6 Write one `flutter test` covering the filter + relaxation function across: normal case, empty-after-hard-filter case, and full-relaxation-still-empty case

## 5. Planner UI

- [x] 5.1 Build the input form screen: kid age, interest tags, budget, hasCar toggle
- [x] 5.2 Build the spin/result screen: display 1-3 activity cards (name, description, benefitNote)
- [x] 5.3 Add a re-spin control that re-runs the random pick against the same candidate pool without re-collecting inputs
- [x] 5.4 Add a "closest matches" label shown when the recommender had to relax filters or fall back

## 6. Verification

- [x] 6.1 Run `flutter analyze` and `flutter test`, confirm clean
- [x] 6.2 Manually spot-check suggestions across a few real Gothenburg weather days and different age/interest/budget/hasCar combinations, confirming results are sensible
- [x] 6.3 Confirm the empty-pool and closest-matches fallback path is reachable and displays correctly with a deliberately narrow test input (e.g. very high budget-restrictive + no car)
