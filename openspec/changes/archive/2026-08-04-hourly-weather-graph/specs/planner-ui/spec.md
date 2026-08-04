## MODIFIED Requirements

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
