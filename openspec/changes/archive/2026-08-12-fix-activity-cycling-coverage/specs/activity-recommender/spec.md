## MODIFIED Requirements

### Requirement: Avoid repeating the previous spin's activities
The system SHALL accept an `excludeIds` set representing every activity
shown since the last full cycle or filter change (not merely the
immediately previous spin), and SHALL prefer activities not in that set
when selecting the next spin's suggestions, without changing which
relaxation tier is used and without reducing the number of suggestions
shown (1-3) below what the tier's candidate pool can provide. If the
candidate pool (after exclusion) can't fill all suggestion slots, the
system SHALL top up with previously shown activities rather than showing
fewer suggestions or an empty result. The system SHALL report the size of
the eligible pool the pick was drawn from (`eligiblePoolSize`) so a caller
can detect when every eligible activity has been shown at least once and
reset its exclude set to start a new cycle.

#### Scenario: Enough alternatives exist
- **WHEN** the candidate pool has enough non-excluded activities to fill
  all suggestion slots
- **THEN** none of the excluded activities appear in the new result

#### Scenario: Not enough alternatives exist
- **WHEN** the candidate pool (after exclusion) has fewer activities than
  needed to fill all suggestion slots
- **THEN** the system tops up the result with previously shown activities
  rather than showing fewer than the pool would otherwise allow

#### Scenario: Exclusion never changes the relaxation tier
- **WHEN** a relaxation tier's candidate pool is non-empty but every
  activity in it is excluded
- **THEN** the system still uses that tier's pool (repeating an activity if
  necessary) rather than falling through to a more-relaxed tier

#### Scenario: Reporting the eligible pool size
- **WHEN** a spin's result is drawn from a candidate pool of a given size
  (whichever relaxation tier matched)
- **THEN** the result reports that size as `eligiblePoolSize`, so a caller
  tracking cumulative exclusions can detect full-pool coverage and reset

#### Scenario: Full pool coverage within one cycle
- **WHEN** a caller accumulates every shown activity's id into its
  exclude set across successive spins (instead of resetting it after each
  spin) and resets the set once it reaches `eligiblePoolSize`
- **THEN** every activity in the eligible pool is shown at least once
  within `ceil(eligiblePoolSize / 3)` spins, regardless of scoring-boost
  weighting

#### Scenario: No immediate repeat across a cycle-boundary reset
- **WHEN** a caller's exclude set reaches `eligiblePoolSize` and it resets
  the set by seeding it with the ids just shown (rather than clearing it
  to empty)
- **THEN** the activities shown in that spin do not reappear in the very
  next spin, as long as the eligible pool size is evenly divisible by the
  number of suggestions shown per spin
