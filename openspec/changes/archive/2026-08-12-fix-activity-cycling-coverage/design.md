## Context

Manual testing surfaced that the same 6-7 activities kept reappearing on
repeated spins. Investigation (see proposal.md) traced this to
`excludeIds` only ever containing the immediately previous spin's picks,
combined with `_weightedPick`'s scoring bias and a default-filtered pool
shrunk to ~12 activities by the Gratis (0kr) budget default.

## Goals / Non-Goals

**Goals:**
- Guarantee every eligible activity is shown at least once within a
  bounded number of spins (`ceil(eligiblePoolSize / 3)`), verified by a
  test using a fixed random seed.
- Keep the fix minimal — no change to the weighting/scoring mechanism
  itself, no new dependencies, no persistent storage.

**Non-Goals:**
- Changing the budget default or scoring weights (out of scope; the pool
  size and weighting bias are contributing factors but not what's being
  fixed here — the caller no longer under-tracks history regardless of
  pool size or weight distribution).
- Cross-session persistence of "shown" ids (resets on app restart, same
  as today's `_history`).

## Decisions

- Expose `eligiblePoolSize` on `RecommendationResult` rather than having
  the caller guess or recompute pool size — the recommender already knows
  which relaxation tier matched and how big that tier's pool is.
- Reset condition is `_shownIds.length >= eligiblePoolSize` (checked
  after adding the latest spin's ids), not a heuristic like "all of this
  spin's picks were already shown" — the latter would discard tracking
  for pool members not in the current pick, breaking the coverage
  guarantee.
- Reset `_shownIds` alongside `_clearResult()` — same trigger, since a
  filter change changes the eligible pool itself.

## Risks / Trade-offs

- [If the eligible pool's relaxation tier changes between spins (e.g. an
  interest match becomes available), `eligiblePoolSize` changes too,
  which could reset the cycle earlier/later than expected] → acceptable;
  the pool composition itself changed, so restarting the coverage cycle
  against the new pool is the correct behavior, not a bug.
- [`_shownIds` grows within a single filter session but is bounded by
  `eligiblePoolSize`, so no unbounded memory growth] → verified by the
  reset-at-full-coverage logic.

## Round-2 fixes (post-review)

A first review round (Opus 5 + GPT-5.6 Sol, run in parallel) independently
converged on the same 3 issues, addressed here:

- **Cycle-boundary immediate repeat**: the initial reset cleared
  `_shownIds` to `{}` once it covered the full pool, which let the
  activities just shown reappear on the very next spin — a regression
  vs. the pre-fix behavior (which always excluded at least the last
  spin). Fixed by seeding the reset with the just-shown ids
  (`_shownIds..clear()..addAll(newIds)`) instead of clearing to empty.
  Trade-off: each lap after the first now needs one extra spin's worth
  of "slack" before the carried-over ids can reappear (verified by a
  sliding-window test rather than a fixed-width one — see tests).
- **Entry-count vs. unique-id mismatch**: `eligiblePoolSize` was
  `pool.length` (raw entries), but `_shownIds` is a `Set<String>` of
  unique ids. If the catalog ever had duplicate ids the reset condition
  could never fire. Defensive fix: `eligiblePoolSize` now uses
  `pool.map((a) => a.id).toSet().length`. Not currently reachable (all 48
  catalog ids are unique) but cheap to make correct regardless.
- **Async race with filter changes**: `_spin()`'s 300ms artificial delay
  (for the loading spinner) had no guard against a filter change
  occurring mid-flight — filter controls stay interactive while
  `_loading` is true. A stale spin's completion would silently commit a
  result/history entry and corrupt `_shownIds` bookkeeping for the wrong
  (new) filter pool. Fixed with a `_spinGeneration` counter bumped in
  `_clearResult()`; `_spin()` snapshots it before the delay and discards
  the result if `!mounted || generation != _spinGeneration`.
- **Follow-up bug caught by review of the above fix**: the discard path
  returned early without resetting `_loading`, so a filter change during
  the 300ms window left the spinner stuck forever and the spin button
  permanently disabled (both Opus 5 and GPT-5.6 Sol independently caught
  this — confirmed reachable via `_loadWeather()`'s `_clearResult()` call
  when a forecast lands mid-spin). Fixed by resetting `_loading = false`
  directly in `_clearResult()`, so it's cleared the instant the
  generation moves on rather than waiting for the stale spin to resolve
  and hit the discard branch.

## Known related issue (not fixed here, out of scope)

GPT-5.6 Sol also flagged that `_toggleUseMyPosition` resolves the device
position asynchronously and updates `_userPosition` without bumping
`_spinGeneration` a second time — an in-flight spin's `prefs` snapshot
(taken synchronously before the position resolves) can commit using a
stale/missing position rather than the newly-resolved one. This doesn't
corrupt `_shownIds`/pool-size bookkeeping (the committed result stays
internally consistent with whatever prefs were used), so it's a
different, narrower race than the one this change targets, and fixing it
would mean rearchitecting `_toggleUseMyPosition`'s own async flow —
tracked as a follow-up rather than folded into this change, per the
"keep the fix minimal" goal above.
