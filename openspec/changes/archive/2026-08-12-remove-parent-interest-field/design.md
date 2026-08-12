## Context

`parentInterest` is a list-of-tags field on each catalog entry, parsed into
`Activity.parentInterest`, but no code reads it — not `recommender.dart`
scoring/filtering, not the UI. It's dead weight left over from an earlier
design iteration.

## Goals / Non-Goals

**Goals:**
- Remove `parentInterest` from the JSON data, the `Activity` model, and
  the test helper that seeds it.

**Non-Goals:**
- Changing any other field or scoring behavior.
- Introducing a migration/versioning mechanism for the JSON schema — it's
  a bundled asset rebuilt with the app, not an external data feed.

## Decisions

- Remove the field outright rather than deprecate-and-ignore, since
  nothing reads it and this is app-bundled data with no external
  consumers.
- Use a small script (not manual edits) to strip `parentInterest` from all
  ~48 JSON entries consistently and re-validate the JSON parses.

## Risks / Trade-offs

- [Removing a required constructor param breaks any code still passing
  it] → grep confirms only `activity.dart` and the `recommender_test.dart`
  test helper reference it; both are updated in this change.
