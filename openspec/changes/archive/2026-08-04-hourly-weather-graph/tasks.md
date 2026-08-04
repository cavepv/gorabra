## 1. Weather service rework

- [x] 1.1 Add `HourlyPoint` model (`time`, `temperatureC`,
      `apparentTemperatureC`, `precipitationMm`, `weatherCode`).
- [x] 1.2 Add `weather_code` to the Open-Meteo `hourly` request params.
- [x] 1.3 Parse the full hourly response into `List<HourlyPoint>` per day
      (today / tomorrow), splitting by date label (reuse the existing
      response-derived date-label logic, not device clock).
- [x] 1.4 `WeatherForecast.today` / `.tomorrow` become
      `List<HourlyPoint>` (empty list if that day's data is unavailable).
- [x] 1.5 Add a helper (e.g. `WeatherForecast.middayResult(day)` or a free
      function) that finds the 12:00 `HourlyPoint` in a day's list and
      returns the existing `WeatherResult` shape (temp, apparent temp,
      `IndoorReason`) for the recommender — reusing `_classify()` unchanged.
- [x] 1.6 Add a `weatherCodeToIcon(int code)` mapping function (WMO code →
      `IconData` + short condition label), with a defensive fallback for
      unrecognized codes.
- [x] 1.7 Update `test/recommender_test.dart` fixtures for whatever
      `WeatherResult`-equivalent shape the recommender still consumes.

## 2. Planner UI

- [x] 2.1 Replace `_buildWeatherSummary()` with an hourly graph widget:
      horizontally scrollable `Row` of 24 columns (hour label, icon,
      temperature) for `_selectedDay`'s hourly list.
- [x] 2.2 Show "weather unavailable" when the selected day's hourly list
      is empty.
- [x] 2.3 Wire the recommender's `weather:` param to the midday-derived
      `WeatherResult` (via the new helper) for `_selectedDay`, unchanged
      call site otherwise.
- [x] 2.4 Confirm day-toggle-clears-`_result` and delayed-weather-clears-
      `_result` behavior still holds with the new data shape.

## 3. Verification

- [x] 3.1 Run `flutter analyze` — must be clean.
- [x] 3.2 Run `flutter test` — update/extend `widget_test.dart` if needed
      to assert on the hourly graph instead of the old summary line.
- [x] 3.3 Manual spot-check against the live Open-Meteo API: confirm 24
      real hourly entries per day, sensible weather-code → icon mapping,
      and the recommender's midday-derived signal still matches the old
      single-value behavior.
- [x] 3.4 Mark all tasks complete in this file.
