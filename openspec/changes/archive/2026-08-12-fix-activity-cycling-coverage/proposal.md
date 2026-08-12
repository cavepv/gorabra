## Why

Manual testing showed the same 6-7 activities kept reappearing on repeated
spins. Root cause: `excludeIds` only ever contained the *immediately
previous* spin's 1-3 picks (`planner_screen.dart`'s `_spin()`), not
everything already shown this session. Combined with `_weightedPick`'s
sampling bias (social + physicalActivity activities get 2-3x the sampling
weight) and a default-filtered pool of just 12 activities (Gratis/0kr
budget, a never-relaxed hard filter, excludes most of the 48-entry
catalog), the same handful of high-weight activities dominated almost
every spin while low-weight ones were rarely sampled.

## What Changes

- `RecommendationResult` gains `eligiblePoolSize`: the size of the
  eligible pool the pick was drawn from (whichever relaxation tier
  matched). This lets a caller know exactly when every eligible activity
  has been shown at least once.
- `planner_screen.dart` tracks a session-wide `_shownIds` set (not just
  the last spin) and passes it as `excludeIds`. Once `_shownIds` reaches
  `eligiblePoolSize`, it resets, starting a fresh cycle. `_shownIds` is
  cleared alongside `_clearResult()` whenever a filter changes (the
  eligible pool itself changes then).
- No change to the weighting mechanism itself (`_weightedPick`'s
  social/physicalActivity boost) — the fix is purely in how much history
  is excluded, not in the sampling weights.
- Add recommender tests proving every eligible activity is shown within
  one cycle (`ceil(poolSize / 3)` spins) and that the cycle repeats
  correctly on subsequent laps.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `activity-recommender`: the exclude/no-repeat behavior changes from
  "avoid only the previous spin's picks" to "avoid every activity shown
  since the last full cycle or filter change, resetting once the whole
  eligible pool has been shown once."

## Impact

- `lib/services/recommender.dart`: `RecommendationResult` gains
  `eligiblePoolSize` (all three construction sites updated).
- `lib/screens/planner_screen.dart`: new `_shownIds` field, `_spin()` and
  `_clearResult()` updated.
- `test/recommender_test.dart`: new tests for `eligiblePoolSize` and
  eventual full-pool coverage across cycles.
