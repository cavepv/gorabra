## 1. Data cleanup

- [x] 1.1 Strip the `parentInterest` key from every entry in
      `assets/data/activities.json` (script, not manual edits).

## 2. Model and test cleanup

- [x] 2.1 Remove `parentInterest` field, constructor param, and JSON
      parsing from `lib/models/activity.dart`.
- [x] 2.2 Remove the unused `parentInterest` parameter from the
      `_activity` test helper in `test/recommender_test.dart`.

## 3. Verification

- [x] 3.1 Run `flutter analyze` and `flutter test` (full suite); fix any
      failures.
