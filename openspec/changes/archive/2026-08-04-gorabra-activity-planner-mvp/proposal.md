## Why

Parents of young kids repeatedly face the same daily decision-paralysis problem
("what do we do today with 2 young kids in Gothenburg?") and end up scrolling
generic search results that ignore weather, age-appropriateness, budget, or
whether they have a car. Görabra solves this with a curated, evidence-grounded
activity catalog that filters by real constraints (age, weather, cost,
transport) and randomly picks 1-3 suggestions from the matching pool — a
"spin" mechanic that removes the decision entirely instead of adding another
search UI.

## What Changes

- New Flutter/Dart mobile app ("Görabra"), Gothenburg-only for v1.
- A hand-curated JSON activity catalog (~20-30 entries) with a fixed schema
  covering age range, indoor/outdoor, kid interests, parent interests,
  social/meetup suitability, evidence-based developmental benefits, opening
  hours, distance from city center, transport modes, and cost tier.
- A recommendation engine that hard-filters activities by kid age, weather
  (via Open-Meteo, no API key), cost vs. user budget, and transport
  reachability vs. whether the user has a car — with progressive filter
  relaxation (interests → weather → age, cost/transport handled as
  described in design.md) so the app never returns zero results.
- Soft scoring (not filtering) that boosts an activity's odds in the random
  pick based on parent interests, social/meetup suitability, and
  evidence-based physical-activity benefit tags (to counter sedentary time).
- A "spin" UI: user fills in kid age(s) + interests once, then taps a spin
  button to get 1-3 random suggestions from the current filtered pool, with
  a re-spin option.
- Android home-screen widget (1-3 activity suggestions) is explicitly **out
  of scope for this change** — deferred to a future change once the core
  app is validated.

## Capabilities

### New Capabilities
- `activity-catalog`: the curated activity data schema and Gothenburg dataset.
- `weather-lookup`: fetching today's Gothenburg weather from Open-Meteo and
  classifying it as indoor/outdoor-appropriate.
- `activity-recommender`: hard-filtering, progressive relaxation, and soft
  scoring/weighting logic that produces the candidate pool for a spin.
- `planner-ui`: the input form (kid age/interests/budget/car) and spin/result
  screen.

### Modified Capabilities
- None (greenfield project, no existing specs).

## Impact

- New standalone Flutter project at `~/Görabra` (this repo).
- New dependency: Open-Meteo HTTP client (no API key required).
- No backend/server component; all data ships in the app bundle.
- No impact on other projects/repos.
