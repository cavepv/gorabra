## ADDED Requirements

### Requirement: Input form for kid age, interests, budget, and car
The system SHALL provide a form where the user enters kid age(s), selects
kid interest tags, states a budget (`free`/`low`/`medium`/`high`), and
indicates whether they have a car (`hasCar`), before requesting suggestions.

#### Scenario: Completing the input form
- **WHEN** the user opens the app for a new session
- **THEN** they can enter a kid age, select one or more interests, choose a
  budget level, and toggle whether they have a car, before spinning

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
