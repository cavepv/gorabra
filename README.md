# Görabra

A family activity planner for Gothenburg — enter your kid's age, interests,
budget, and whether you have a car, and Görabra spins up 1-3 weather-aware
activity suggestions from a curated local catalog.

Built to solve a real vacation problem: "what do we do today in Gothenburg
with young kids?" — without scrolling generic search results that ignore
weather, age-appropriateness, budget, or transport.

## How it works

1. Fill in kid age, interest tags, budget level, and whether you have a car.
2. Toggle between "Idag" (today) and "Imorgon" (tomorrow) — Görabra fetches
   Gothenburg's full 24-hour forecast for both days in one call (via
   [Open-Meteo](https://open-meteo.com/), free, no API key), and shows the
   selected day as a scrollable hourly graph: an icon, temperature, and
   hour label for every hour, so you can see how the day's weather changes
   at a glance.
3. The recommender hard-filters a curated ~21-activity Gothenburg catalog by
   age, weather (indoor/outdoor, derived from the selected day's midday
   forecast), cost vs. budget, and transport reachability — relaxing
   filters progressively (interests → weather → age) if the pool is empty,
   so you never see zero results. Cost and transport are never relaxed.
4. Activities that match your own interests, are good for meeting other
   families, or are tagged as good physical activity get better odds — but
   never override the hard filters.
5. Tap "Spinna" for 1-3 random suggestions from the matching pool; "Spinna
   igen" re-rolls without re-entering your inputs.

## Project structure

- `lib/models/activity.dart` — the activity data model (`Cost`,
  `TransportMode` enums, `Activity` class).
- `lib/models/activity_catalog.dart` — loads the bundled JSON catalog (no
  network call).
- `assets/data/activities.json` — the curated Gothenburg activity dataset,
  hand-maintained (no live places/maps API).
- `lib/services/weather_lookup.dart` — Open-Meteo client fetching a full
  24-hour forecast (temperature, feels-like/apparent temperature — wind
  matters for Gothenburg's perceived temperature — precipitation, and
  weather condition code) for today and tomorrow, mapped to display icons,
  with a midday-derived indoor/outdoor signal for the recommender and a
  null-safe per-day/per-hour fallback if a fetch or entry is unavailable.
- `lib/services/recommender.dart` — the filter/relaxation/scoring logic;
  the one piece of real branching logic in the app, covered by
  `test/recommender_test.dart`.
- `lib/screens/planner_screen.dart` — the single-screen form + spin +
  results UI.

## Getting started

```bash
flutter pub get
flutter analyze
flutter test
flutter run -d chrome        # or an emulator/device
```

## Scope (v1)

Phone app only, Gothenburg-only, no backend, no accounts. An Android
home-screen widget (1-3 quick suggestions) is a planned v2 — see
[`openspec/changes/gorabra-activity-planner-mvp/`](openspec/changes/gorabra-activity-planner-mvp/)
for the full proposal, design rationale, specs, and task history behind
this MVP.
