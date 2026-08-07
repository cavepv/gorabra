## MODIFIED Requirements

### Requirement: Input form for kid age, interests, budget, and car
The system SHALL provide a form where the user enters one or more kid ages
(one to four kids, defaulting to a single kid aged 4), selects kid interest
tags, states a budget (`free`/`low`/`medium`/`high`), indicates whether
they have a car (`hasCar`), toggles whether to stay home (`stayHome`,
default off), and optionally enables a distance filter based on their
current position and a radius slider, before requesting suggestions.

#### Scenario: Toggling "Stanna hemma"
- **WHEN** the user enables the "Stanna hemma" switch
- **THEN** subsequent spins only suggest `homeOnly` activities,
  independent of the Idag/Imorgon day selection, and any existing result
  is cleared until the user spins again

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
