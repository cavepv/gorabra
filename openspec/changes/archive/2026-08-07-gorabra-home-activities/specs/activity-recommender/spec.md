## MODIFIED Requirements

### Requirement: Hard filter by kid age, weather, cost, and transport
The system SHALL filter the activity catalog down to a candidate pool using
these hard filters: every kid's age (from the user's list of one to four
kid ages) within the activity's `[minAge, maxAge]` range; `indoor` matching
today's weather classification (when known); `cost` within the user's
stated `budget`; at least one of the activity's `transportModes` being
reachable given the user's `hasCar` input (if `hasCar` is false, activities
whose only `transportModes` entry is `car` are excluded); and the
activity's `homeOnly` flag matching the user's `stayHome` input (when
`stayHome` is true, only `homeOnly: true` activities pass; when `stayHome`
is false, only `homeOnly: false` activities pass).

#### Scenario: All hard filters applied for a single kid
- **WHEN** the user requests suggestions with one kid age, a budget, and a
  `hasCar` value, and today's weather is known
- **THEN** the candidate pool contains only activities matching that kid's
  age range, weather-appropriate indoor/outdoor status, cost within
  budget, a reachable transport mode, and the requested home/away mode

#### Scenario: stayHome excludes away activities
- **WHEN** the user sets `stayHome: true`
- **THEN** the candidate pool contains only activities with
  `homeOnly: true`, regardless of weather, interests, or age relaxation

#### Scenario: default mode excludes home-only activities
- **WHEN** the user sets `stayHome: false` (the default)
- **THEN** the candidate pool never includes activities with
  `homeOnly: true`

### Requirement: Progressive relaxation on empty pool
The system SHALL relax hard filters in this order if the candidate pool is
empty: first drop the kid-interests filter, then drop the weather filter,
then drop the age filter (i.e. the multi-kid age-intersection check from
the age hard filter) — in that order, stopping as soon as the pool is
non-empty. The `cost`/`budget`, `transportModes`/`hasCar`, and
`homeOnly`/`stayHome` filters SHALL NOT be relaxed under any circumstance.

#### Scenario: stayHome never relaxed
- **WHEN** the `stayHome`-filtered pool would be empty even after
  relaxing interests, weather, and age
- **THEN** the system shows the best available `homeOnly`-matching
  activities from the cost/transport-filtered set only, rather than
  falling back to activities that don't match `stayHome`
