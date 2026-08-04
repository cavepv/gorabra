## Why

The Today/Tomorrow weather feature currently shows a single midday
snapshot (one temperature, one feels-like value). That hides how weather
actually changes across the day — a family planning a Gothenburg outing
benefits far more from seeing "clear until 15:00, rain after" than one
number. An hourly graph with weather icons makes the reasoning behind
indoor/outdoor suggestions visible and lets users pick a better time
window themselves.

## What Changes

- **BREAKING** (internal only, no persisted data): `WeatherLookup` and
  `WeatherResult`/`WeatherForecast` are reworked to carry a full 24-hour
  series per day (temperature, apparent temperature, precipitation, and
  Open-Meteo's `weather_code`) instead of a single midday value.
- The recommender's weather filter tier still needs one indoor/outdoor
  signal per day — derived from the same midday (12:00) entry as before,
  now extracted from the hourly series rather than fetched separately.
- Add a `weather_code` → Material icon + short condition label mapping
  (sunny/cloudy/rain/snow/thunderstorm/fog) using Open-Meteo's WMO codes —
  no new icon asset or dependency, `Icons.*` covers it.
- Planner UI replaces the single-line weather summary with a horizontally
  scrollable hourly strip (icon, temperature, hour label) for the selected
  day (Today/Tomorrow toggle unchanged), full 24 hours, scrollable.

## Capabilities

### New Capabilities
(none)

### Modified Capabilities
- `weather-lookup`: fetch and expose a full hourly series (not just
  midday) for today and tomorrow, including `weather_code`; the
  indoor/outdoor classification requirement is updated to note it's
  derived from the midday entry of the hourly series.
- `planner-ui`: the weather display requirement changes from a single-line
  summary to a scrollable hourly graph with icons.

## Impact

- `lib/services/weather_lookup.dart`: request shape adds `weather_code`;
  `WeatherResult` (midday, used by the recommender) stays but is now
  derived from a new `HourlyPoint` list; `WeatherForecast.today` /
  `.tomorrow` become `List<HourlyPoint>`.
- `lib/screens/planner_screen.dart`: new hourly strip widget, icon mapping
  helper, `_selectedWeather` (for the recommender) now derived from the
  midday `HourlyPoint` in the selected day's list.
- `test/recommender_test.dart`: fixtures need updating for whatever
  `WeatherResult`-equivalent shape the recommender still consumes.
- No new dependencies (Material `Icons`, no chart package).
