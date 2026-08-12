## Context

`planner_screen.dart` currently renders Intressen, Budget, Tillgång till
bil, Stanna hemma, and Avstånd as always-visible sections alongside kid
age. All of these already default to a permissive "show all" state in
`recommender.dart` except budget, which is kept at Gratis (0kr) by
deliberate choice. This is a UI-only reorganization — no filter semantics
change.

## Goals / Non-Goals

**Goals:**
- Collapse Intressen, Budget, Tillgång till bil, Stanna hemma, and
  Avstånd into a single "Fler filter" section, collapsed by default.
- Keep kid age always visible outside the collapsed section.
- Zero behavior change to `UserPreferences`/`ActivityRecommender`.

**Non-Goals:**
- Changing any filter default value (budget stays 0kr/Gratis).
- New navigation, dialogs, or bottom sheets.
- New dependencies.

## Decisions

- Use Flutter's built-in `ExpansionTile` for the collapsible group —
  stdlib widget, no new dependency, matches Material design conventions
  already used elsewhere in the app.
- Collapsed by default: `initiallyExpanded: false` (the widget's own
  default), so no extra state variable is needed to track open/closed —
  `ExpansionTile` manages its own expansion state internally.
- Order inside the tile: Intressen → Budget → Tillgång till bil → Stanna
  hemma → Avstånd, matching the existing visual order in the current
  build methods.

## Risks / Trade-offs

- [Existing widget tests locate grouped controls (budget slider/field,
  interest chips, car switch, stayHome switch, distance slider) directly
  by `Key`/finder without expanding the tile first] → tests must call
  `tester.tap(find.text('Fler filter'))` (or equivalent) and pump before
  interacting with those widgets.
- [`ExpansionTile` adds a leading/trailing chevron and default padding
  that slightly changes visual layout] → acceptable, matches Material
  conventions already used in the app; no pixel-perfect requirement
  exists.
