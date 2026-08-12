## MODIFIED Requirements

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
