## ADDED Requirements

### Requirement: Hard filter by kid age, weather, cost, and transport
The system SHALL filter the activity catalog down to a candidate pool using
these hard filters: kid age within `[minAge, maxAge]`; `indoor` matching
today's weather classification (when known); `cost` within the user's
stated `budget`; and at least one of the activity's `transportModes` being
reachable given the user's `hasCar` input (if `hasCar` is false, activities
whose only `transportModes` entry is `car` are excluded).

#### Scenario: All hard filters applied
- **WHEN** the user requests suggestions with a stated kid age, budget, and
  `hasCar` value, and today's weather is known
- **THEN** the candidate pool contains only activities matching age range,
  weather-appropriate indoor/outdoor status, cost within budget, and a
  reachable transport mode

### Requirement: Progressive relaxation on empty pool
The system SHALL relax hard filters in this order if the candidate pool is
empty: first drop the kid-interests filter, then drop the weather filter,
then drop the age filter — in that order, stopping as soon as the pool is
non-empty. The `cost`/`budget` and `transportModes`/`hasCar` filters SHALL
NOT be relaxed under any circumstance.

#### Scenario: Empty pool after full hard filtering
- **WHEN** the fully hard-filtered pool (age, weather, cost, transport) is
  empty
- **THEN** the system relaxes interests first, then weather, then age (each
  time re-checking whether the pool is non-empty), while keeping cost and
  transport filters intact

#### Scenario: Still empty after full relaxation
- **WHEN** the pool remains empty even after relaxing interests, weather,
  and age
- **THEN** the system shows the best available activities from the
  cost/transport-filtered set only, labeled as "closest matches", rather
  than showing zero results

### Requirement: Soft scoring boosts, never exclusion
The system SHALL boost (not filter) an activity's likelihood of being
picked when it matches the user's `parentInterest` tags, when `social` is
true, or when its `benefits` include `physicalActivity`. These signals
SHALL NOT remove any activity from the candidate pool.

#### Scenario: Physical activity nudge
- **WHEN** the candidate pool contains activities tagged with
  `physicalActivity` in `benefits`
- **THEN** those activities have a higher probability of being selected in
  the random pick than equally-filtered activities without that tag,
  without excluding any non-tagged activity

### Requirement: Random pick of 1-3 suggestions
The system SHALL randomly select 1-3 activities from the current candidate
pool (after hard filtering/relaxation and soft-score weighting) each time
the user triggers a "spin", and SHALL be able to produce a different result
on a re-spin without changing the user's stated inputs.

#### Scenario: Spin produces suggestions
- **WHEN** the user taps "spin" with a non-empty candidate pool
- **THEN** the system displays 1-3 randomly selected activities from that
  pool

#### Scenario: Re-spin without changing inputs
- **WHEN** the user taps "spin" again without changing any input
- **THEN** the system performs a new random selection from the same
  candidate pool, which may differ from the previous result
