# Görabra

A family activity planner for Gothenburg — enter your kids' ages (1-4 kids),
interests, budget, and whether you have a car, and Görabra spins up 1-3
weather-aware activity suggestions from a curated local catalog.

Built to solve a real vacation problem: "what do we do today in Gothenburg
with young kids?" — without scrolling generic search results that ignore
weather, age-appropriateness, budget, or transport.

## How it works

1. Fill in one or more kids' ages (add up to 4 via "+ Lägg till barn"),
   interest tags (yours and the kids', each collapsible/expandable), budget
   level, whether you have a car, whether you want to stay home today
   ("Stanna hemma"), and optionally an "Avstånd" (distance) filter based
   on your current position and a 1-50km radius slider.
2. Toggle between "Idag" (today) and "Imorgon" (tomorrow) — Görabra fetches
   Gothenburg's full 24-hour forecast for both days in one call (via
   [Open-Meteo](https://open-meteo.com/), free, no API key), and shows the
   selected day as a scrollable hourly graph: a color-coded icon, bold
   temperature, and muted hour label for every hour, with the current hour
   highlighted and auto-scrolled into view, so you can see how the day's
   weather changes at a glance.
3. The recommender hard-filters a curated ~50-activity Gothenburg catalog by
   age (must suit every kid in the group), weather (indoor/outdoor, derived
   from the selected day's midday forecast), cost vs. budget, transport
   reachability, home/away mode ("Stanna hemma" limits results to
   stay-at-home activities), and — if enabled — a real-GPS distance radius
   (via [geolocator](https://pub.dev/packages/geolocator), haversine
   distance against each activity's coordinates) — relaxing filters
   progressively (interests → weather → age) if the pool is empty, so you
   never see zero results. Cost, transport, home/away mode, and the
   distance radius are never relaxed. The distance filter (and "har ni
   bil") have no effect while "Stanna hemma" is active.
4. Activities that match your own interests, are good for meeting other
   families, or are tagged as good physical activity get better odds — but
   never override the hard filters.
5. Tap "Ge mig tips!" for 1-3 random suggestions from the matching pool;
   "Nya förslag" re-rolls without re-entering your inputs.

## Project structure

- `lib/models/activity.dart` — the activity data model (`TransportMode`
  enum, `Activity` class with `costSek`).
- `lib/models/activity_catalog.dart` — loads the bundled JSON catalog (no
  network call).
- `assets/data/activities.json` — the curated Gothenburg activity dataset,
  hand-maintained (no live places/maps API).
- `lib/services/weather_lookup.dart` — Open-Meteo client fetching a full
  24-hour forecast (temperature, feels-like/apparent temperature — wind
  matters for Gothenburg's perceived temperature — precipitation, wind
  speed, and weather condition code) for today and tomorrow, mapped to
  display icons, with a midday-derived indoor/outdoor signal for the
  recommender and a null-safe per-day/per-hour fallback if a fetch or
  entry is unavailable.
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

## Deployment (web)

The web build is deployed to GitHub Pages: **https://cavepv.github.io/gorabra/**

```bash
flutter build web --release --base-href /gorabra/
```

The `build/web` output is then pushed to the `gh-pages` branch (served from
its root), which triggers GitHub's Pages build/deploy workflow automatically.
`--base-href /gorabra/` is required since the site is served from a
project-repo subpath rather than a domain root.

## Scope (v1)

Phone app only, Gothenburg-only, no backend, no accounts. An Android
home-screen widget (1-3 quick suggestions) is a planned v2 — see
[`openspec/changes/archive/2026-08-04-gorabra-activity-planner-mvp/`](openspec/changes/archive/2026-08-04-gorabra-activity-planner-mvp/)
for the full proposal, design rationale, specs, and task history behind
this MVP, and
[`openspec/changes/archive/2026-08-06-multi-child-support/`](openspec/changes/archive/2026-08-06-multi-child-support/)
for the multi-kid support add-on. Current source-of-truth specs live under
[`openspec/specs/`](openspec/specs/).
