## Why

`parentInterest` is a leftover field on every activity entry that is parsed
into `Activity.parentInterest` but never read anywhere else — not in
scoring, not in filtering, not in the UI. It's dead data that adds noise to
every hand-maintained JSON entry and to the model.

## What Changes

- Remove the `parentInterest` field from every entry in
  `assets/data/activities.json`.
- Remove the corresponding `parentInterest` property, constructor
  parameter, and JSON parsing from `lib/models/activity.dart`.
- Remove the unused `parentInterest` test helper parameter from
  `test/recommender_test.dart`.
- **BREAKING**: activity JSON entries with a `parentInterest` field will no
  longer be parsed for that field — any external tooling relying on it
  would need updating (none exists in this repo).

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `activity-catalog`: activity data schema requirement drops
  `parentInterest` from the documented field list.

## Impact

- `assets/data/activities.json`: ~48 entries, drop `parentInterest` key
  from each.
- `lib/models/activity.dart`: drop field/constructor param/JSON parse.
- `test/recommender_test.dart`: drop unused test-helper parameter.
- `openspec/specs/activity-catalog/spec.md`: delta removing the field from
  the schema requirement.
