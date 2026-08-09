## ADDED Requirements

### Requirement: Hard filter by kid age, weather, cost, and transport
The system SHALL filter the activity catalog down to a candidate pool using
these hard filters: every kid's age (from the user's list of one to four
kid ages) within the activity's `[minAge, maxAge]` range; `indoor` matching
today's weather classification (when known); `costSek` at or below the
user's stated `maxBudgetSek` (0-3000 kr); at least one of the activity's `transportModes` being
reachable given the user's `hasCar` input (if `hasCar` is false, activities
whose only `transportModes` entry is `car` are excluded — this check does
not apply to `homeOnly` activities, which are always reachable regardless
of `hasCar`); and the
activity's `homeOnly` flag matching the user's `stayHome` input (when
`stayHome` is true, only `homeOnly: true` activities pass; when `stayHome`
is false, only `homeOnly: false` activities pass); and, when the user has
supplied a position and a `maxDistanceKm` radius, the activity's distance
from that position (computed via the haversine formula against its
`lat`/`lng`) being within `maxDistanceKm` — this check does not apply to
`homeOnly` activities, or to activities lacking `lat`/`lng`, and is
skipped entirely (always passes) when the user hasn't supplied a position
or radius.

#### Scenario: All hard filters applied for a single kid
- **WHEN** the user requests suggestions with one kid age, a budget, and a
  `hasCar` value, and today's weather is known
- **THEN** the candidate pool contains only activities matching that kid's
  age range, weather-appropriate indoor/outdoor status, cost at or below
  budget, a reachable transport mode, and the requested home/away mode

#### Scenario: stayHome excludes away activities
- **WHEN** the user sets `stayHome: true`
- **THEN** the candidate pool contains only activities with
  `homeOnly: true`, regardless of weather, interests, or age relaxation

#### Scenario: hasCar has no effect on home activities
- **WHEN** the user sets `stayHome: true`
- **THEN** the `hasCar` input does not exclude any `homeOnly` activity,
  since there is nowhere to drive to when staying home

#### Scenario: default mode excludes home-only activities
- **WHEN** the user sets `stayHome: false` (the default)
- **THEN** the candidate pool never includes activities with
  `homeOnly: true`

#### Scenario: Distance filter excludes far-away activities
- **WHEN** the user has supplied a position and a `maxDistanceKm` radius
- **THEN** the candidate pool contains only activities whose haversine
  distance from that position is within the radius

#### Scenario: Distance filter has no effect on home activities
- **WHEN** the user has supplied a position and a `maxDistanceKm` radius
  and `stayHome` is true
- **THEN** the distance filter does not exclude any `homeOnly` activity,
  since staying home has no meaningful "distance from here"

#### Scenario: Distance filter off by default
- **WHEN** the user has not supplied a position and radius (the default)
- **THEN** the distance filter has no effect and every activity passes it
  regardless of its `lat`/`lng`

#### Scenario: Age filter requires every kid's age to fit
- **WHEN** the user requests suggestions with more than one kid age (e.g.
  ages 5 and 7)
- **THEN** the candidate pool only includes activities whose
  `[minAge, maxAge]` range covers every one of the stated kid ages, not
  just one of them

#### Scenario: Non-overlapping kid ages produce no age-filtered match
- **WHEN** the user's kid ages span a range no single activity covers (e.g.
  ages 3 and 12)
- **THEN** no activity satisfies the age hard filter, and the system falls
  through to the progressive relaxation behavior (age is relaxed last,
  unchanged from the single-kid case)

### Requirement: Progressive relaxation on empty pool
The system SHALL relax hard filters in this order if the candidate pool is
empty: first drop the kid-interests filter, then drop the weather filter,
then drop the age filter (i.e. the multi-kid age-intersection check from
the age hard filter) — in that order, stopping as soon as the pool is
non-empty. The `costSek`/`maxBudgetSek`, `transportModes`/`hasCar`,
`homeOnly`/`stayHome`, and distance-radius filters SHALL NOT be relaxed
under any circumstance.

#### Scenario: stayHome never relaxed
- **WHEN** the `stayHome`-filtered pool would be empty even after
  relaxing interests, weather, and age
- **THEN** the system shows the best available `homeOnly`-matching
  activities from the cost/transport-filtered set only, rather than
  falling back to activities that don't match `stayHome`

#### Scenario: Distance radius never relaxed
- **WHEN** the distance-filtered pool would be empty even after relaxing
  interests, weather, and age
- **THEN** the system shows zero results (or the best available
  within-radius activities) rather than falling back to activities
  outside the user's chosen radius

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

#### Scenario: Age relaxation applies uniformly regardless of kid count
- **WHEN** the age hard filter (single age or multi-kid intersection) is
  the filter being relaxed
- **THEN** the system drops the age check entirely for that relaxation
  step, regardless of whether one or multiple kid ages were supplied

### Requirement: Soft scoring boosts, never exclusion
The system SHALL boost (not filter) an activity's likelihood of being
picked when `social` is true, or when its `benefits` include
`physicalActivity`. These signals SHALL NOT remove any activity from the
candidate pool.

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
