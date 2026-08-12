## MODIFIED Requirements

### Requirement: Activity data schema
The system SHALL define each activity entry with the following fields: `id`,
`name`, `description`, `minAge`, `maxAge`, `indoor` (bool), `interests`
(list of tags), `social` (bool), `benefits`
(list of tags), `benefitNote` (string), `openingHours` (string), `location`
(string), `distanceKm` (number), `transportModes` (list of tags: `walk`,
`bike`, `publicTransit`, `car`), `costSek` (integer, flat SEK cost for the
whole outing, `0` for free), `homeOnly` (bool, optional, defaults to
`false` when absent), and `lat`/`lng` (numbers, optional, absent/null for
`homeOnly` activities).

#### Scenario: Loading the catalog
- **WHEN** the app starts
- **THEN** it loads a bundled JSON asset of Gothenburg activities matching
  this schema, with no network request required to display the catalog

#### Scenario: Home activity entries
- **WHEN** an activity entry has `homeOnly: true`
- **THEN** its `location`, `distanceKm`, `transportModes`, and
  `openingHours` fields are placeholder values (`"Hemma"`, `0`, `[]`,
  `"Alltid"`) since none of those apply to a stay-at-home activity, and it
  has no `lat`/`lng` coordinates

#### Scenario: Away activity entries have coordinates
- **WHEN** an activity entry has `homeOnly: false` (or absent, defaulting
  to `false`)
- **THEN** it has real approximate `lat`/`lng` coordinates so it can be
  compared against the user's position for the distance filter
