## ADDED Requirements

### Requirement: Input form for kid age, interests, budget, and car
The system SHALL provide a form where the user enters one or more kid ages
(one to four kids, defaulting to a single kid aged 4), always visible
outside any collapsible section since it's required before spinning. The
remaining inputs — kid interest tags, a maximum budget in SEK via a slider
(0-10000 kr, default 10000 kr/unlimited so a fresh spin isn't hard-filtered
to free-only activities, step 50 kr) with an accompanying optional
textfield for entering an exact amount directly (both controls stay in
sync and clamp to the 0-10000 kr range), whether they have a car
(`hasCar`, default on), whether to stay home (`stayHome`, default off),
whether to show only indoor activities (`indoorOnly`, default off,
disabled and moot while `stayHome` is active since every `homeOnly`
activity is already indoor), and an optional distance filter based on
their current position and a
radius slider — SHALL be grouped together under a single collapsible
"Filter" section that is collapsed by default on every fresh
session, so the form shows only the kid age input and the collapsed
section header until the user chooses to expand it. The "Filter" section
header SHALL show a reset button once any filter differs from its
default, which restores every filter to its default value in one tap;
the button is hidden while every filter is already at its default.
#### Scenario: Completing the input form with one kid
- **WHEN** the user opens the app for a new session
- **THEN** a single kid-age row (age slider defaulting to 4) is shown
  always visible, the "Filter" section is collapsed, and the user
  can spin immediately without touching it

#### Scenario: Expanding "Filter"
- **WHEN** the user taps the collapsed "Filter" section
- **THEN** it expands in place to reveal Intressen, Budget, Tillgång till
  bil, Stanna hemma, Inomhusaktiviteter, and Avstånd, in that order,
  without navigating away from the planner screen

#### Scenario: Resetting all filters
- **WHEN** the user has changed at least one filter from its default and
  taps the reset button in the "Filter" section header
- **THEN** every filter (interests, budget, car, stay-home, indoor-only,
  distance/position) returns to its default value and the reset button
  disappears again

#### Scenario: Setting budget via the textfield
- **WHEN** the user types a number directly into the budget textfield
- **THEN** the slider moves to reflect that value, and any amount typed
  outside the 0-10000 kr range is clamped and the textfield updated to show
  the clamped value

#### Scenario: Budget at the free minimum
- **WHEN** the budget is set to 0 kr (via the slider or the textfield)
  and the textfield is not focused
- **THEN** the textfield displays "Gratis" instead of "0 kr", and typing a
  digit into the field replaces it with that digit

#### Scenario: Adding a kid
- **WHEN** the user taps "+ Lägg till barn" with fewer than four kid rows
  present
- **THEN** a new kid-age row is added (age slider defaulting to 4), up to a
  maximum of four rows total

#### Scenario: Adding a kid at the cap
- **WHEN** the user has four kid-age rows present
- **THEN** the "+ Lägg till barn" control is disabled, preventing a fifth
  row

#### Scenario: Removing a kid
- **WHEN** the user taps the remove control on a kid-age row while more
  than one row is present
- **THEN** that row is removed and the remaining rows' ages are unchanged

#### Scenario: Removing the last kid is prevented
- **WHEN** only one kid-age row remains
- **THEN** its remove control is hidden or disabled, so the form always has
  at least one kid age

#### Scenario: Toggling "Stanna hemma"
- **WHEN** the user enables the "Stanna hemma" switch
- **THEN** subsequent spins only suggest `homeOnly` activities,
  independent of the Idag/Imorgon day selection, and any existing result
  is cleared until the user spins again

#### Scenario: Toggling "Inomhusaktiviteter"
- **WHEN** the user enables the "Inomhusaktiviteter" switch
- **THEN** subsequent spins only suggest `indoor: true` activities, and
  any existing result is cleared until the user spins again

#### Scenario: "Inomhusaktiviteter" disabled while staying home
- **WHEN** "Stanna hemma" is active
- **THEN** the "Inomhusaktiviteter" switch is disabled, since every
  `homeOnly` activity is already indoor and the toggle would have no
  effect

#### Scenario: Expanding the distance section
- **WHEN** the user expands the "Avstånd" section and enables "Använd min
  position"
- **THEN** the app fetches the user's current position once, caches it
  for the rest of the session (not re-fetched on every spin), and enables
  a 1-50km radius slider (default 5km, step 1km) once the position is
  available

#### Scenario: Distance section disabled while staying home
- **WHEN** "Stanna hemma" is active
- **THEN** the "Avstånd" section's position switch is disabled, since
  distance filtering is moot when suggestions are home-only

#### Scenario: Position fetch failure falls back gracefully
- **WHEN** the position fetch fails (permission denied, location services
  off, or a timeout)
- **THEN** the app shows an inline error message, leaves the slider
  disabled, and does not apply any distance filter to the spin (falls
  back to unfiltered results rather than blocking the user)

### Requirement: Spin and result display
The system SHALL show a "spin" control that, once the input form is filled,
triggers the recommender and displays the resulting 1-3 activities as
cards showing at minimum the activity name, description, and
`benefitNote`.

#### Scenario: Viewing spin results
- **WHEN** the user taps "spin" after completing the input form
- **THEN** the app displays 1-3 activity cards, each showing the name,
  description, and the evidence-based benefit note

### Requirement: Re-spin control
The system SHALL provide a way for the user to re-spin (request a new
random pick from the same candidate pool) without re-entering the input
form. The system SHALL track every activity shown since the last filter
change (not merely the immediately previous spin) and pass it as the
recommender's exclude set, resetting that tracked set once every eligible
activity has been shown at least once, so repeated re-spins eventually
surface the whole eligible pool rather than a small high-scoring subset.

#### Scenario: Re-spinning for new suggestions
- **WHEN** the user taps "re-spin" after viewing results
- **THEN** the app shows a new set of 1-3 activities drawn from the same
  filtered candidate pool, without requiring the input form to be
  re-filled

#### Scenario: Repeated re-spins eventually cover the whole pool
- **WHEN** the user re-spins repeatedly without changing any filter
- **THEN** within `ceil(eligiblePoolSize / 3)` spins every activity in the
  eligible pool has been shown at least once, after which the tracked
  shown-set resets and a new cycle begins

#### Scenario: Changing a filter resets the shown-activities tracking
- **WHEN** the user changes any filter input (kid ages, interests,
  budget, car, stay-home, distance, position, or the Idag/Imorgon day)
- **THEN** the tracked set of previously shown activity ids is cleared
  along with the spin history, since the eligible pool itself has changed

#### Scenario: A filter change during an in-flight spin discards it
- **WHEN** the user changes a filter while a re-spin request is still
  pending (e.g. during its loading state)
- **THEN** the pending spin's result is discarded rather than committed —
  it isn't shown, added to spin history, or merged into the tracked
  shown-activities set — and the loading indicator clears immediately
  rather than waiting for the discarded spin to finish

### Requirement: Spin history navigation
The system SHALL keep an in-memory, browser-tab-style history of past spin
results and provide back/forward icon buttons flanking the spin button so
the user can revisit a previous suggestion set without re-spinning, or
step forward again. Any change to a filter input (kid ages, interests,
budget, car, stay-home, distance, position, or the Idag/Imorgon day)
SHALL clear this history along with the current result.

#### Scenario: No history yet
- **WHEN** the user has not spun yet, or has just changed a filter input
- **THEN** both the back and forward buttons are disabled

#### Scenario: Stepping back after multiple spins
- **WHEN** the user has spun more than once and taps the back button
- **THEN** the previously shown result set is displayed again, the back
  button disables once the oldest entry is reached, and the forward
  button becomes enabled

#### Scenario: Stepping forward
- **WHEN** the user has stepped back and taps the forward button
- **THEN** the next-newer result set in history is displayed, and the
  forward button disables once the newest entry is reached again

#### Scenario: Spinning again after stepping back
- **WHEN** the user has stepped back to an older result and taps
  "Nya förslag"
- **THEN** any newer history entries beyond that point are discarded, and
  the freshly computed result becomes the newest history entry

### Requirement: Closest-matches results (unlabeled)
The system SHALL show results even when the recommender had to fall back
to a relaxed or cost/transport-only filtered pool (per the
activity-recommender capability), without a visible "closest matches"
label — the relaxation is internal to the recommender and not surfaced in
the UI.

#### Scenario: Displaying relaxed results
- **WHEN** the recommender returns results only after relaxing one or more
  filters
- **THEN** the UI shows those results the same way as a full match, with
  no "closest matches" label

### Requirement: Today/Tomorrow weather day toggle
The system SHALL provide a Today/Tomorrow toggle that selects which day's
weather forecast drives the weather scoring boost for the next spin, and
SHALL display a scrollable hourly weather graph (24 hours, each showing an
hour label, a condition icon, the temperature, and the wind speed) for the
currently selected day next to the spin results, so the user can see how
weather changes across the day and the reasoning behind indoor/outdoor
suggestions.

#### Scenario: Viewing today's hourly graph by default
- **WHEN** the user opens the planner and the input form loads
- **THEN** the "Today" option is selected by default and its 24-hour
  hourly graph (icon, temperature, wind speed, hour label per hour) is
  shown, horizontally scrollable

#### Scenario: Switching to tomorrow
- **WHEN** the user selects "Tomorrow" on the day toggle
- **THEN** the hourly graph updates to show tomorrow's 24-hour forecast,
  and the next spin uses tomorrow's midday-derived weather signal to drive
  the indoor/outdoor scoring boost instead of today's

#### Scenario: Toggling the day clears stale results
- **WHEN** the user changes the day toggle after already viewing spin
  results
- **THEN** the previously shown results are cleared, consistent with
  changing any other filter input

#### Scenario: Selected day's weather is unavailable
- **WHEN** the weather fetch failed or returned no hourly data for the
  currently selected day
- **THEN** the UI shows a "weather unavailable" message in place of the
  hourly graph for that day, and the next spin proceeds without the
  weather scoring boost
