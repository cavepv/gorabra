## 1. Recommender changes

- [x] 1.1 Add `eligiblePoolSize` to `RecommendationResult`, populated from
      whichever relaxation tier's pool matched (all 3 construction sites
      in `recommender.dart`).
- [x] 1.2 Count `eligiblePoolSize` as **unique activity ids**
      (`pool.map((a) => a.id).toSet().length`), not raw entry count — a
      duplicate-id catalog entry must not make the planner's reset
      condition unreachable. (Round-2 review fix.)

## 2. Planner screen changes

- [x] 2.1 Add `_shownIds` set to `PlannerScreenState`, cleared alongside
      `_clearResult()`.
- [x] 2.2 Update `_spin()` to pass `_shownIds` as `excludeIds` (instead of
      only the last result's ids), and after each spin add the new
      result's ids, resetting `_shownIds` once it reaches
      `eligiblePoolSize`.
- [x] 2.3 Seed the cycle reset with the just-shown ids instead of clearing
      to empty, so the activities just shown can't immediately repeat on
      the very next spin across a cycle boundary. (Round-2 review fix.)
- [x] 2.4 Add a `_spinGeneration` counter, bumped in `_clearResult()`;
      `_spin()` snapshots it before its artificial delay and discards a
      stale result (`!mounted || generation != _spinGeneration`) so a
      filter change mid-spin can't corrupt `_shownIds`/`_result`/`_history`
      for the wrong pool. (Round-2 review fix.)
- [x] 2.5 Reset `_loading = false` inside `_clearResult()` so a discarded
      in-flight spin doesn't leave the spinner stuck and the spin button
      permanently disabled. (Round-3 review fix — caught by both
      reviewers on the round-2 diff.)

## 3. Tests

- [x] 3.1 Add a recommender test asserting `eligiblePoolSize` reports the
      matched tier's pool size.
- [x] 3.2 Add a recommender test simulating the planner's cumulative
      exclude/reset loop with a seeded `Random`, asserting every activity
      in a weighted, unevenly-scored pool is shown within one cycle.
- [x] 3.3 Add a recommender test asserting coverage holds over many laps
      using a sliding window (updated in round 2 to match the
      seed-on-reset fix, which shifts lap boundaries — a fixed
      non-overlapping window no longer aligns with laps).
- [x] 3.4 Add a regression test asserting no activity from the immediately
      previous spin ever reappears, even across a cycle boundary.
- [x] 3.5 Add coverage tests for pool sizes not evenly divisible by the
      pick size, and for pools smaller than the pick size (single
      activity).
- [x] 3.6 Add a duplicate-id test for `eligiblePoolSize` so the unique-id
      count fix is actually exercised (the original test passed under
      both the old and new implementations). (Round-3 review fix.)

## 5. Verification

- [x] 5.1 Run `flutter analyze` and `flutter test` (full suite); fix any
      failures.
- [x] 5.2 Second review round (Opus 5 + GPT-5.6 Sol) on the round-2 diff;
      third round after applying round-2 review fixes, confirming the
      `_loading` regression and test gaps are resolved.
