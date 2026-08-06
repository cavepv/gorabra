## MODIFIED Requirements

### Requirement: Hard filter by kid age, weather, cost, and transport
The system SHALL filter the activity catalog down to a candidate pool using
these hard filters: every kid's age (from the user's list of one to four
kid ages) within the activity's `[minAge, maxAge]` range; `indoor` matching
today's weather classification (when known); `cost` within the user's
stated `budget`; and at least one of the activity's `transportModes` being
reachable given the user's `hasCar` input (if `hasCar` is false, activities
whose only `transportModes` entry is `car` are excluded).

#### Scenario: All hard filters applied for a single kid
- **WHEN** the user requests suggestions with one kid age, a budget, and a
  `hasCar` value, and today's weather is known
- **THEN** the candidate pool contains only activities matching that kid's
  age range, weather-appropriate indoor/outdoor status, cost within
  budget, and a reachable transport mode

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

#### Scenario: Age relaxation applies uniformly regardless of kid count
- **WHEN** the age hard filter (single age or multi-kid intersection) is
  the filter being relaxed
- **THEN** the system drops the age check entirely for that relaxation
  step, regardless of whether one or multiple kid ages were supplied
