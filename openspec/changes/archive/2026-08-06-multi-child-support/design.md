## Context

`UserPreferences.kidAge` is a single `int`, matched against an activity's
`[minAge, maxAge]` range via `matchesAge`. The planner form has one
age slider bound to `_kidAge`. Families with more than one kid have no way
to express that — they'd need to run separate spins per kid and reconcile
results by hand.

## Goals / Non-Goals

**Goals:**
- Let the user enter an age per kid (1-4 kids) and get one recommendation
  that's valid for all of them.
- Reuse the existing single-age slider widget per kid rather than building
  a new age-input control.
- Keep the existing relaxation order (interests → weather → age) and
  "cost/transport never relaxed" rule completely unchanged.

**Non-Goals:**
- No per-kid interest tags, per-kid weighting, or "closest match for most
  kids" partial-fit logic — out of scope for this change (see grilled
  decision: empty intersection just falls through the existing relax
  fallback, same as single-kid today).
- No persistence of kid ages across app sessions — matches current
  in-memory-only behavior for all planner inputs.
- No upper bound beyond 4 kids driven by data; 4 is a UI layout choice, not
  a domain constraint.

## Decisions

**`kidAge: int` → `kidAges: List<int>`, non-empty, 1-4 entries.**
Simplest shape that lets the recommender reuse its existing per-activity
predicate style. Alternative considered: a `{minAge, maxAge}` range
struct — rejected because it silently accepts gaps (e.g. entering 3 and 9
would imply a valid 3-9-year-old exists) and loses the ability to show
each kid's own slider back in the UI.

**Age match becomes an intersection, computed inline in `matchesAge`.**
`matchesAge(a) => prefs.kidAges.every((age) => age >= a.minAge && age <=
a.maxAge)`. No new data structure needed — `every()` over a list of at most
4 elements is O(4) per activity, negligible for this catalog's ~21
activities. Alternative considered: precomputing `groupMinAge`/`groupMaxAge`
once and comparing against that — rejected because it's an approximation
(passes for gapped ranges, e.g. group min=3/max=9 would wrongly accept an
activity whose range is exactly 3-9 even if no single kid is aged
4-8) that trades correctness for a micro-optimization the catalog size
doesn't need.

**UI: repeatable row widget, capped list, no separate "kids count" input.**
Each row is the existing age `Slider` plus a remove (X) `IconButton`
(hidden/disabled when `kidAges.length == 1`). An "+ Lägg till barn" button
below the rows appends a new default-age-4 entry, disabled at 4 kids. This
matches the locked plan from grilling: cap at 4, always ≥1, default age 4
per new kid.

**Progressive relaxation untouched.**
`attempts` list in `ActivityRecommender.recommend` stays structurally
identical; only the inline `matchesAge` predicate's body changes from a
single comparison to `.every(...)`. No new relax tier is introduced for
"partial fit across some kids" — confirmed out of scope during grilling.

## Risks / Trade-offs

- **Wide age gaps can empty the pool entirely** (e.g. a 3-year-old and a
  12-year-old with no activity spanning both) → Mitigation: falls through
  to the existing age-relaxed / cost-transport-only fallback, same as
  today; no new UI messaging needed since `isClosestMatch` already
  communicates "not a perfect match".
- **Breaking API change** to `UserPreferences` → Mitigation: this is an
  internal, non-persisted, single-screen app with no external consumers of
  `UserPreferences`; the only call site is `planner_screen.dart`, updated
  in the same change.
- **Test coverage gap if only intersection is tested at the boundary** →
  Mitigation: tasks.md includes an explicit multi-age intersection test
  case (e.g. ages `[3, 9]` against an activity range that covers both vs.
  one that only covers one).

## Migration Plan

Single-PR change, no phased rollout (in-memory-only state, no persisted
data to migrate):
1. Update `RecommenderPrefs`/`UserPreferences` shape and `matchesAge` in
   `recommender.dart`.
2. Update `planner_screen.dart` state (`_kidAge` → `_kidAges`) and form UI.
3. Extend `recommender_test.dart` and `widget_test.dart`.
4. Run `flutter analyze` + `flutter test` before merge (existing project
   convention — no new tooling).

No rollback mechanism needed beyond reverting the commit; there's no
persisted data format to reverse-migrate.

## Open Questions

None outstanding — resolved during a grilling session prior to this
proposal (see decisions above for the rationale on each locked choice).
