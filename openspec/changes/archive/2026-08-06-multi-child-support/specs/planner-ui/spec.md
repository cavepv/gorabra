## MODIFIED Requirements

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
