## Why

Today's weather already drives the recommender's indoor/outdoor filter, but
it's invisible to the user — they can't see *why* the app suggested indoor
activities, and they can't plan for tomorrow. Showing today's and tomorrow's
weather, tied to an actionable "plan for" toggle, makes the recommendation
reasoning transparent and lets users plan a day ahead.

## What Changes

- `WeatherLookup` fetches hourly forecast data (not just current conditions)
  for both today and tomorrow at a fixed midday (12:00) hour, using
  Open-Meteo's `hourly` parameters — no new API provider.
- Classification switches from raw `temperature_2m` to Open-Meteo's
  `apparent_temperature` (feels-like, combining wind chill + humidity),
  which is a wind-chill-aware temperature Gothenburg's climate needs, without
  hand-rolling a wind-chill formula.
- The planner UI gains a "Today" / "Tomorrow" toggle. Whichever day is
  selected drives both the displayed weather summary and the recommender's
  weather filter tier for that spin.
- A small weather summary (temperature, feels-like, rain indicator) is shown
  next to the spin results as the reasoning behind indoor/outdoor picks.

## Capabilities

### New Capabilities
(none — this modifies existing capabilities only)

### Modified Capabilities
- `weather-lookup`: fetch hourly forecast for today AND tomorrow (fixed
  midday hour) instead of only today's current conditions; classify using
  `apparent_temperature` instead of raw temperature.
- `planner-ui`: add a Today/Tomorrow toggle that selects which day's
  weather feeds the recommender, and display a weather summary near results.

## Impact

- `lib/services/weather_lookup.dart`: request shape changes from `current`
  to `hourly`; new `WeatherResult` fields (`apparentTemperatureC` or
  similar) and a way to fetch/return both days.
- `lib/screens/planner_screen.dart`: new toggle control, new weather summary
  widget, `_loadWeather()` updated to fetch both days.
- `test/recommender_test.dart` unaffected (recommender still takes a single
  `WeatherResult`, just sourced from whichever day is selected).
- No new dependencies.
