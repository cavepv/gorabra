## Context

`WeatherLookup.fetchToday()` currently calls Open-Meteo's `current` block
for temperature + precipitation, classifies indoor/outdoor via a simple
threshold heuristic, and returns a single `WeatherResult`. The recommender
consumes this to filter/relax around indoor/outdoor. This is invisible to
the user today. The grill-me session locked: show weather as reasoning next
to results (not decorative), tied to a Today/Tomorrow toggle that actually
drives which day's weather feeds the recommender, using a fixed midday
(12:00) hour for both days (no time-picker), and classify using Open-Meteo's
built-in `apparent_temperature` (wind chill + humidity) instead of raw temp.

## Goals / Non-Goals

**Goals:**
- Fetch and expose weather for both today and tomorrow at a fixed midday
  hour, from the same Open-Meteo API already in use.
- Classify indoor/outdoor using `apparent_temperature` instead of raw temp.
- Let the user toggle which day's weather drives the current spin.
- Display a small weather summary next to results as the "why" behind
  indoor/outdoor picks.

**Non-Goals:**
- No time-of-day picker (fixed midday hour for both days).
- No multi-day (3+ day) forecast.
- No new weather provider (SMHI/yr.no) — Open-Meteo's `apparent_temperature`
  already covers wind chill without a new dependency.
- No change to the recommender's relaxation/filter logic itself — it still
  takes one `WeatherResult` per call.

## Decisions

**Switch `current` → `hourly` Open-Meteo params, fixed midday index.**
Request `hourly=temperature_2m,apparent_temperature,precipitation` plus
`forecast_days=2`, then pick the hourly entry closest to 12:00 local time
for today and for tomorrow (index by matching the `hourly.time` timestamp
string, not by naive fixed array offset, since the array is UTC-hour-aligned
and Gothenburg's UTC offset shifts with DST). Alternative considered: two
separate `current`/`daily` calls — rejected, since `daily` only gives
min/max (loses the "midday" precision decision from grilling) and a second
`current` call can't target "tomorrow" at all.

**Classify on `apparent_temperature`, not raw `temperature_2m`.**
`_classify()` keeps its existing precipitation and extreme-temperature
thresholds, just reading from `apparent_temperature` instead of
`temperature_2m`. No NWS wind-chill formula needed — Open-Meteo already
computes a feels-like value combining wind + humidity + solar radiation, so
there's no valid-range edge case to guard (unlike a hand-rolled formula).

**`WeatherResult` gains a `day` label; `WeatherLookup` returns both days in
one call.** Add `WeatherLookup.fetchForecast()` returning
`(WeatherResult? today, WeatherResult? tomorrow)` (or a small named record)
in a single HTTP request, rather than two separate calls — cheaper and
keeps today/tomorrow atomically consistent (same fetch, same failure mode).
`fetchToday()` is removed/renamed since v1's only caller becomes obsolete.

**UI: toggle is a `SegmentedButton<Day>` beside the weather summary.**
Selecting "Tomorrow" re-runs `_spin()` semantics? No — the toggle only
changes which `WeatherResult` backs the *next* spin; it does not
auto-re-spin. Existing "stale result clears on input change" behavior
(from the prior review-fix round) already covers this: toggling the day
clears `_result` like any other filter input change, consistent with the
rest of the form.

## Risks / Trade-offs

- **[Risk]** Open-Meteo's hourly array for "tomorrow midday" may be
  momentarily unavailable near the UTC day boundary → **Mitigation**: reuse
  the existing `null`-on-failure fallback (per-day: if tomorrow's midday
  entry isn't found in the response, that day's `WeatherResult` is `null`
  and the UI shows "weather unavailable" for that day only, today is
  unaffected).
- **[Risk]** DST transition days shift Gothenburg's UTC offset mid-forecast
  → **Mitigation**: match by parsing/comparing `hourly.time` ISO strings
  converted to local Europe/Stockholm time, not by a fixed array index.
- **[Risk]** `apparent_temperature` may be `null` for some model/location
  edge cases → **Mitigation**: if `apparent_temperature` is null in the
  response, fall back to `temperature_2m` for that entry (same fallback
  posture as the rest of the feature).

## Migration Plan

No data migration (stateless fetch, no persistence). Rollout is a single
app update: ship `WeatherLookup.fetchForecast()` alongside the UI toggle in
one release. Rollback = revert the commit; no server-side state to unwind.

## Open Questions

None — grilling session resolved scope (midday-fixed, apparent_temperature,
toggle drives recommender not auto-respin).
