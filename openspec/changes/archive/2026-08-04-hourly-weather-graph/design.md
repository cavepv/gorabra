## Context

The prior weather feature (`todays-tomorrow-weather-display`) fetches a
single midday (12:00) `WeatherResult` per day and shows a one-line summary.
This change replaces the summary with an hourly graph (icons + temp,
scrollable, full 24h) while keeping the recommender's existing contract
(one indoor/outdoor signal per day) intact.

## Goals / Non-Goals

**Goals:**
- Show a full 24-hour, scrollable, icon-based hourly forecast strip for
  whichever day (Today/Tomorrow) is selected.
- Use Open-Meteo's `weather_code` (WMO codes) for accurate condition icons
  instead of inferring condition from temperature/precipitation alone.
- Keep the recommender's weather filter tier working exactly as before —
  it still receives one `WeatherResult`-shaped midday signal per day.
- No new dependencies: `Icons.*` for icons, a plain scrollable `Row`/
  `ListView` for the "graph" (no chart package).

**Non-Goals:**
- No line/bar chart library (fl_chart, etc.) — a scrollable icon+temp strip
  is the "graph," per the ladder (native widgets over a new dependency).
- No hour-range restriction — full 24h per user decision, scrollable.
- No timezone picker or per-hour activity filtering — the recommender
  still filters on the single midday entry, not per-hour.

## Decisions

**Single Open-Meteo request grows one param: add `weather_code` to the
existing `hourly=temperature_2m,apparent_temperature,precipitation` list.**
Still `forecast_days=2&timezone=Europe%2FStockholm`. No new request, no new
provider.

**New `HourlyPoint` model holds one hour's data:** `time` (parsed
`DateTime`, local), `temperatureC`, `apparentTemperatureC`,
`precipitationMm`, `weatherCode` (int). `WeatherForecast.today` /
`.tomorrow` become `List<HourlyPoint>` (24 entries each, empty list if
that day's data is entirely missing — same per-day fallback posture as
before, just list-shaped instead of nullable-single-value).

**Recommender-facing `WeatherResult` is now derived, not fetched.** Add a
`WeatherResult? middayResult(List<HourlyPoint> hourly)` helper (or a
`WeatherForecast.todayMidday`/`.tomorrowMidday` getter) that finds the
`12:00` entry in the hourly list and reuses the existing `_classify()`
logic (apparent-temperature + precipitation → `IndoorReason`). This keeps
`ActivityRecommender` and `test/recommender_test.dart`'s `WeatherResult`
fixtures unchanged in shape — only where the value comes from changes.

**Weather-code → icon mapping is a pure lookup table, not a dependency.**
WMO weather codes group cleanly: 0 (clear) → `Icons.wb_sunny`, 1-3
(cloudy variants) → `Icons.cloud`/`Icons.wb_cloudy`, 45/48 (fog) →
`Icons.foggy` (or `Icons.blur_on` fallback if unavailable), 51-67/80-82
(rain/drizzle) → `Icons.umbrella`, 71-77/85-86 (snow) → `Icons.ac_unit`,
95-99 (thunderstorm) → `Icons.thunderstorm`. Codes outside known ranges
fall back to `Icons.help_outline` (defensive default, should never trigger
against Open-Meteo's documented code set).

**UI: horizontally scrollable `SingleChildScrollView` + `Row` of 24
columns**, each column: hour label ("14"), icon, temperature. Plain
`Row`/`Column`, not `ListView.builder` — 24 fixed items is cheap enough
that lazy building adds no value and would need `SizedBox`-constrained
width like the ListView pitfall (see cv_app's `pumpTall` lesson) — a
bounded `SingleChildScrollView` avoids test-viewport surprises since it
doesn't clip children based on viewport the same way `ListView.builder`
does (all 24 columns exist as real widgets regardless of scroll offset).

## Risks / Trade-offs

- **[Risk]** 24-wide horizontal strip may be visually cramped on narrow
  phones → **Mitigation**: fixed per-hour column width (e.g. 56px) inside
  the scroll view; acceptable for v1, revisit with a design pass if user
  feedback says otherwise.
- **[Risk]** Some Open-Meteo weather codes may not have a good Material
  icon equivalent → **Mitigation**: the fallback-bucket mapping above
  covers the full documented WMO code range Open-Meteo uses; the
  `help_outline` default is a safety net, not expected to fire in practice.
- **[Risk]** Widget test needs a tall+wide enough surface to find hourly
  strip content (same class of issue fixed previously with `setSurfaceSize`)
  → **Mitigation**: keep the existing enlarged test surface; add a targeted
  assertion (e.g. find at least one hour label) rather than asserting on
  all 24 to keep the test resilient to a hidden overflow edge case.

## Migration Plan

No persisted data. Single-commit rollout replacing the summary widget and
`WeatherLookup`'s return shape. Rollback = revert the commit.

## Open Questions

None — full-24h scope was confirmed by the user before starting.
