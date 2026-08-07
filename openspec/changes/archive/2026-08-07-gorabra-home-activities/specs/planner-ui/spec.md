## MODIFIED Requirements

### Requirement: Input form for kid age, interests, budget, and car
The system SHALL provide a form where the user enters one or more kid ages
(one to four kids, defaulting to a single kid aged 4), selects kid interest
tags, states a budget (`free`/`low`/`medium`/`high`), indicates whether
they have a car (`hasCar`), and toggles whether to stay home (`stayHome`,
default off), before requesting suggestions.

#### Scenario: Toggling "Stanna hemma"
- **WHEN** the user enables the "Stanna hemma" switch
- **THEN** subsequent spins only suggest `homeOnly` activities,
  independent of the Idag/Imorgon day selection, and any existing result
  is cleared until the user spins again
