## ADDED Requirements

### Requirement: Input form for kid age, interests, budget, and car
The system SHALL provide a form where the user enters one or more kid ages
(one to four kids, defaulting to a single kid aged 4), selects kid interest
tags, states a budget (`free`/`low`/`medium`/`high`), and indicates whether
they have a car (`hasCar`), before requesting suggestions.

#### Scenario: Completing the input form with one kid
- **WHEN** the user opens the app for a new session
- **THEN** a single kid-age row (age slider defaulting to 4) is shown, and
  they can select one or more interests, choose a budget level, and toggle
  whether they have a car, before spinning

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
form.

#### Scenario: Re-spinning for new suggestions
- **WHEN** the user taps "re-spin" after viewing results
- **THEN** the app shows a new set of 1-3 activities drawn from the same
  filtered candidate pool, without requiring the input form to be
  re-filled

### Requirement: Closest-matches labeling
The system SHALL visibly label results as "closest matches" when the
recommender had to fall back to a relaxed or cost/transport-only filtered
pool (per the activity-recommender capability), so the user understands
the results are not a perfect match.

#### Scenario: Displaying relaxed results
- **WHEN** the recommender returns results only after relaxing one or more
  filters
- **THEN** the UI shows a "closest matches" label alongside the results

### Requirement: Today/Tomorrow weather day toggle
The system SHALL provide a Today/Tomorrow toggle that selects which day's
weather forecast drives the weather filter tier for the next spin, and
SHALL display a scrollable hourly weather graph (24 hours, each showing an
hour label, a condition icon, and the temperature) for the currently
selected day next to the spin results, so the user can see how weather
changes across the day and the reasoning behind indoor/outdoor
suggestions.

#### Scenario: Viewing today's hourly graph by default
- **WHEN** the user opens the planner and the input form loads
- **THEN** the "Today" option is selected by default and its 24-hour
  hourly graph (icon, temperature, hour label per hour) is shown,
  horizontally scrollable

#### Scenario: Switching to tomorrow
- **WHEN** the user selects "Tomorrow" on the day toggle
- **THEN** the hourly graph updates to show tomorrow's 24-hour forecast,
  and the next spin uses tomorrow's midday-derived weather signal to drive
  the indoor/outdoor filter tier instead of today's

#### Scenario: Toggling the day clears stale results
- **WHEN** the user changes the day toggle after already viewing spin
  results
- **THEN** the previously shown results (including any "closest matches"
  label) are cleared, consistent with changing any other filter input

#### Scenario: Selected day's weather is unavailable
- **WHEN** the weather fetch failed or returned no hourly data for the
  currently selected day
- **THEN** the UI shows a "weather unavailable" message in place of the
  hourly graph for that day, and the next spin proceeds without the
  weather filter tier
