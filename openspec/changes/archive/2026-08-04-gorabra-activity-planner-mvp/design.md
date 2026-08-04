## Context

Görabra is a greenfield Flutter/Dart mobile app. No backend, no existing
codebase, no prior specs. All decisions below were settled in a grill-me
session with the user before this proposal (see conversation history);
this document records the resulting technical shape and rationale.

## Goals / Non-Goals

**Goals:**
- Ship a phone-only MVP: curated Gothenburg activity catalog + weather- and
  constraint-aware random suggestion ("spin") mechanic.
- Keep the data pipeline free of paid/keyed external APIs — only Open-Meteo
  (free, no key) for weather.
- Ground suggestions in real developmental value, nudging toward physical
  activity given the "kids not moving enough" problem.
- Make the recommendation logic simple enough to unit-test as pure functions.

**Non-Goals:**
- Android/iOS home-screen widget — deferred to a future change.
- Multi-city support — Gothenburg is hardcoded for v1.
- Live opening-hours or places data (e.g. Google Places API) — hours are
  hand-curated and static.
- A general scoring/ranking engine — scoring is a simple weighted-duplication
  trick (see Decisions), not a real algorithm.
- User accounts, persistence/sync, or any backend service.

## Decisions

### Activity data: hand-curated static JSON, not a live places API
Alternatives considered: Google Places API, TripAdvisor, scraping. Rejected —
adds API keys, billing, quota management, and doesn't provide developmental
context (age-appropriateness, benefit tags) that only manual curation can
supply. A local JSON asset (~20-30 entries) is the entire "content" layer of
v1 and is cheap to maintain by hand.

### Weather: Open-Meteo, no API key
Alternatives considered: OpenWeatherMap (needs key/has quota). Open-Meteo is
free, keyless, and sufficient — v1 only needs today's condition classified as
indoor-appropriate or outdoor-appropriate (plus temperature for judgment
calls), not a full forecast UI.

### Recommendation approach: hard filter, then weighted random pick
Alternatives considered: (a) pure random pick with no filtering — rejected,
risks proposing clearly inappropriate activities (e.g. sandcastle-building on
a rainy day) which breaks user trust immediately; (b) a scored/ranked
recommendation engine — rejected as over-engineering for a ~20-30-item
dataset; a simple filter + weighted-duplicate-then-`random.choice` approach
gets the same practical effect with far less code and no tuning surface.

Filter tier order (hard filters, applied in this order, relaxed from the top
if the pool empties):
1. `interests` (kid) — relaxed first if pool is empty.
2. `cost` vs. user `budget` — hard filter, not relaxed.
3. `transportModes` vs. user `hasCar` — hard filter, not relaxed.
4. Weather (indoor/outdoor) — relaxed second-to-last.
5. `minAge`/`maxAge` — relaxed last (least negotiable: an activity genuinely
   unsafe/wrong for a toddler should stay excluded as long as possible).

Scoring/weighting (never excludes, only affects the random pick's odds):
- `parentInterest` match → boost.
- `social: true` → boost.
- `benefits` containing `physicalActivity` → boost (this is the one
  concrete, deliberate lever addressing the "kids not moving enough"
  motivation from the proposal).
- Implementation: duplicate a matching entry N times in the candidate list
  before calling `random.choice`/`Random.nextInt`, rather than building a
  weighted-random-sampling utility. Simplest possible mechanism for a
  dataset this small.

If the hard-filtered pool is empty even after full relaxation (interests →
weather → age; cost/transport are never relaxed), show the closest available
matches from the cost+transport-filtered set with an explicit "closest
matches" label rather than an empty screen.

### Data schema (locked)
```
{
  id, name, description,
  minAge, maxAge,
  indoor: bool,
  interests: [tags],         // kid interests — hard filter, relaxed first
  parentInterest: [tags],    // scoring boost only
  social: bool,              // scoring boost only
  benefits: [tags],          // physicalActivity boosts scoring; others informational
  benefitNote: string,       // short evidence-based "why this is good" blurb
  openingHours: string,      // manual, static
  location: string,          // free text, Gothenburg hardcoded as city
  distanceKm: number,        // manual, from Gothenburg city center
  transportModes: [tags],    // walk | bike | publicTransit | car — hard filter
  cost: enum                 // free | low | medium | high — hard filter
}
```
User inputs (not persisted, entered per session): kid age(s), kid interests,
`hasCar: bool`, `budget: enum` (same scale as `cost`).

### Distance: manual `distanceKm`, no geocoding/GPS
Alternatives considered: real lat/lng + live GPS distance. Rejected for v1 —
adds location-permission handling and geocoding for a dataset small enough
that a hand-entered km-from-city-center figure is sufficient and trivially
maintained alongside every other manually-curated field.

### Testing approach: manual spot-check + one unit test on filter logic
This is a content-curation app, not a service with SLAs — the dominant risk
is bad data/bad matches, not code defects. Validation is a manual pass across
a handful of real weather days and age/interest/budget combos, plus a single
`flutter test` covering the filter + relaxation function (the only real
branching logic in the app).

## Risks / Trade-offs

- **Small dataset (~20-30 items) → filtered pool frequently empty or tiny** →
  Mitigated by the progressive relaxation + "closest matches" fallback; never
  show a hard zero-results screen.
- **Hand-maintained opening hours/cost go stale** → Acceptable trade-off for
  v1; re-editing JSON is cheap. Revisit with live data only if this becomes a
  real pain point.
- **Weighted-duplicate scoring trick doesn't scale past a small dataset** →
  Fine at 20-30 items; flagged as the ceiling to watch if the catalog grows
  significantly (upgrade path: real weighted-random sampling).
- **No widget in v1** → Reduces "zero-effort surfacing" value proposition
  until v2; accepted trade-off to validate the core recommendation loop
  first before taking on native Android widget complexity.

## Migration Plan

N/A — greenfield project, no existing system to migrate from or roll back to.

## Open Questions

- None blocking v1 implementation. Widget architecture (native
  `AppWidgetProvider` + `home_widget` plugin) is deferred and will be
  designed in a future change once the core app ships.
