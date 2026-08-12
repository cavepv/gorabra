## Why

The planner form shows Intressen, Budget, Tillgång till bil, Stanna hemma,
and Avstånd all at once alongside kid age. For the app's goal — easy,
quick tips for families with kids — most spins don't need any of these
touched: every filter already defaults to a permissive "show all" state
except kid age (required) and budget (kept at Gratis/0kr as a deliberate
exception). Showing five extra controls before the first spin adds visual
weight without adding value for the common case.

## What Changes

- Group Intressen, Budget, Tillgång till bil, Stanna hemma, and Avstånd
  into a single collapsible section labeled "Fler filter", collapsed by
  default on every fresh session.
- Kid age stays outside the collapsed section, always visible, since it's
  required before spinning.
- No change to filter *behavior* or hard-filter semantics in
  `recommender.dart` — interests (empty), hasCar (true), stayHome (false),
  and distance (off) already produce "show all" results today. Budget's
  default was separately changed to 0kr/Gratis in a prior, unrelated
  request this session (accepted as a deliberate exception to "show
  all"); this change does not alter it further, only documents it.
- Update the `planner-ui` spec to reflect the current budget default
  (0kr/Gratis) alongside the new collapsed-by-default grouping.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `planner-ui`: input form requirement changes to (a) document budget's
  actual default (0kr/Gratis, not 300kr) and (b) group Intressen, Budget,
  Tillgång till bil, Stanna hemma, and Avstånd under a single
  collapsed-by-default "Fler filter" section, with kid age remaining
  always visible.

## Impact

- `lib/screens/planner_screen.dart`: wrap the five grouped controls in an
  `ExpansionTile` (or equivalent collapsible widget), collapsed by
  default; kid age rows stay outside it.
- `openspec/specs/planner-ui/spec.md`: delta for the corrected budget
  default and the new grouping/collapse behavior.
- Existing widget tests (`budget_field_test.dart`, `widget_test.dart`,
  `kid_rows_test.dart`) that interact with grouped controls directly may
  need to expand "Fler filter" first before finding those widgets.
