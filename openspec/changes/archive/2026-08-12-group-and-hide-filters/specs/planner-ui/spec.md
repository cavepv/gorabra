## MODIFIED Requirements

### Requirement: Input form for kid age, interests, budget, and car
The system SHALL provide a form where the user enters one or more kid ages
(one to four kids, defaulting to a single kid aged 4), always visible
outside any collapsible section since it's required before spinning. The
remaining inputs — kid interest tags, a maximum budget in SEK via a slider
(0-3000 kr, default 0 kr/Gratis, step 50 kr) with an accompanying optional
textfield for entering an exact amount directly (both controls stay in
sync and clamp to the 0-3000 kr range), whether they have a car
(`hasCar`, default on), whether to stay home (`stayHome`, default off),
and an optional distance filter based on their current position and a
radius slider — SHALL be grouped together under a single collapsible
"Fler filter" section that is collapsed by default on every fresh
session, so the form shows only the kid age input and the collapsed
section header until the user chooses to expand it.

#### Scenario: Completing the input form with one kid
- **WHEN** the user opens the app for a new session
- **THEN** a single kid-age row (age slider defaulting to 4) is shown
  always visible, the "Fler filter" section is collapsed, and the user
  can spin immediately without touching it

#### Scenario: Expanding "Fler filter"
- **WHEN** the user taps the collapsed "Fler filter" section
- **THEN** it expands in place to reveal Intressen, Budget, Tillgång till
  bil, Stanna hemma, and Avstånd, in that order, without navigating away
  from the planner screen

#### Scenario: Setting budget via the textfield
- **WHEN** the user types a number directly into the budget textfield
- **THEN** the slider moves to reflect that value, and any amount typed
  outside the 0-3000 kr range is clamped and the textfield updated to show
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
