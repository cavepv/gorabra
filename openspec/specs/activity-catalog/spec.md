## ADDED Requirements

### Requirement: Activity data schema
The system SHALL define each activity entry with the following fields: `id`,
`name`, `description`, `minAge`, `maxAge`, `indoor` (bool), `interests`
(list of tags), `parentInterest` (list of tags), `social` (bool), `benefits`
(list of tags), `benefitNote` (string), `openingHours` (string), `location`
(string), `distanceKm` (number), `transportModes` (list of tags: `walk`,
`bike`, `publicTransit`, `car`), `cost` (enum: `free`, `low`, `medium`,
`high`), and `homeOnly` (bool, optional, defaults to `false` when absent).

#### Scenario: Loading the catalog
- **WHEN** the app starts
- **THEN** it loads a bundled JSON asset of Gothenburg activities matching
  this schema, with no network request required to display the catalog

#### Scenario: Home activity entries
- **WHEN** an activity entry has `homeOnly: true`
- **THEN** its `location`, `distanceKm`, `transportModes`, and
  `openingHours` fields are placeholder values (`"Hemma"`, `0`, `[]`,
  `"Alltid"`) since none of those apply to a stay-at-home activity

### Requirement: Curated Gothenburg dataset
The system SHALL ship with a hand-curated set of at least 20 Gothenburg
activities covering a range of ages, indoor/outdoor types, cost tiers, and
transport modes, each with a non-empty `benefitNote` grounding the
suggestion in a real developmental or physical-activity benefit.
#### Scenario: Dataset breadth
- **WHEN** the catalog is loaded
- **THEN** it contains at least 20 entries, at least some tagged `indoor:
  true` and some `indoor: false`, at least some `cost: free`, and at least
  one entry per `transportModes` value

### Requirement: Static, hand-maintained hours and distance
The system SHALL treat `openingHours` and `distanceKm` as static data
maintained manually in the JSON catalog; the system SHALL NOT call any
external places/maps API to fetch or validate this data.

#### Scenario: No live places API call
- **WHEN** the app displays an activity's opening hours or distance
- **THEN** the values come only from the bundled JSON, with no network
  request to a places/maps service
