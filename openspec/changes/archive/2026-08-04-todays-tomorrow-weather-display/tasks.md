## 1. Weather service

- [x] 1.1 Update `WeatherResult` to include `apparentTemperatureC` (or
      similar) alongside `temperatureC` and `isIndoorFavoring`.
- [x] 1.2 Replace `WeatherLookup.fetchToday()` with
      `WeatherLookup.fetchForecast()` requesting
      `hourly=temperature_2m,apparent_temperature,precipitation` and
      `forecast_days=2` from Open-Meteo.
- [x] 1.3 Implement midday-entry selection: parse `hourly.time` timestamps,
      convert to Europe/Stockholm local time, and pick the entry closest to
      12:00 for today and for tomorrow (not a fixed array index, to survive
      DST).
- [x] 1.4 Return a small named record/class with `today` and `tomorrow`
      fields, each `WeatherResult?` (null if that day's entry is missing).
- [x] 1.5 Update `_classify()` to use `apparent_temperature`, falling back
      to raw `temperature_2m` when apparent temperature is null in the
      response.
- [x] 1.6 Update `test/recommender_test.dart` fixtures if `WeatherResult`'s
      constructor shape changed.

## 2. Planner UI

- [x] 2.1 Add a `Day` enum (`today`, `tomorrow`) and `_selectedDay` state
      in `planner_screen.dart`.
- [x] 2.2 Replace `_loadWeather()`'s single fetch with a call to
      `WeatherLookup.fetchForecast()`, storing both days' results.
- [x] 2.3 Add a `SegmentedButton<Day>` toggle (Today/Tomorrow) in the form,
      defaulting to Today.
- [x] 2.4 Add a weather summary widget near the results area showing
      temperature, feels-like temperature, and a rain indicator for
      `_selectedDay`; show a "weather unavailable" message when that day's
      `WeatherResult` is null.
- [x] 2.5 Wire `_selectedDay`'s `WeatherResult` into the `weather:` param
      passed to `ActivityRecommender().recommend()` in `_spin()`.
- [x] 2.6 Clear `_result` on day-toggle change, matching the existing
      stale-result-clearing behavior on other form inputs.

## 3. Verification

- [x] 3.1 Run `flutter analyze` — must be clean.
- [x] 3.2 Run `flutter test` — all existing tests plus any updated
      fixtures must pass.
- [x] 3.3 Manual spot-check: toggle Today/Tomorrow and confirm the weather
      summary and spin results change accordingly; verify behavior when
      simulating a weather-fetch failure (both days null).
- [x] 3.4 Mark all tasks complete in this file.
