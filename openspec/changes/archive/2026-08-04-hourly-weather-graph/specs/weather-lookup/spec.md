## MODIFIED Requirements

### Requirement: Fetch today's Gothenburg weather
The system SHALL fetch a full 24-hour forecast series for Gothenburg from
the Open-Meteo API (no API key required) covering both today and tomorrow,
including temperature, apparent temperature, precipitation, and weather
condition code (`weather_code`) for each hour, in a single request.

#### Scenario: Successful hourly fetch for both days
- **WHEN** the user opens the planner and network access is available
- **THEN** the system retrieves 24 hourly entries (temperature, apparent
  temperature, precipitation, weather code) for Gothenburg for both today
  and tomorrow from Open-Meteo, in a single request

#### Scenario: One day succeeds, the other is unavailable
- **WHEN** the Open-Meteo response is missing hourly entries for one of
  the two days (e.g. near a UTC day boundary)
- **THEN** the system returns the hourly series for the day that is
  available and an empty series for the other day, without failing the
  whole fetch

### Requirement: Classify weather as indoor- or outdoor-appropriate
The system SHALL classify each day as favoring indoor or outdoor
activities using the apparent temperature (feels-like, combining wind
chill and humidity) and precipitation of that day's midday (12:00 local)
hourly entry — e.g. rain or extreme apparent temperature favors indoor;
clear/mild apparent temperature favors outdoor — producing a single
indoor/outdoor signal consumable by the recommender for whichever day is
selected, derived from the hourly series rather than a separately fetched
value.

#### Scenario: Rainy day classification
- **WHEN** Open-Meteo reports active precipitation at the selected day's
  midday hourly entry
- **THEN** the system classifies that day as indoor-favoring

#### Scenario: Clear mild day classification
- **WHEN** Open-Meteo reports no precipitation and a comfortable apparent
  temperature at the selected day's midday hourly entry
- **THEN** the system classifies that day as outdoor-favoring

#### Scenario: Windy but mild classification uses feels-like temperature
- **WHEN** Open-Meteo reports a raw air temperature within the comfortable
  range but a lower apparent temperature due to wind at the midday hourly
  entry, such that apparent temperature crosses the indoor-favoring
  threshold
- **THEN** the system classifies that day as indoor-favoring, based on
  apparent temperature rather than raw air temperature

#### Scenario: Apparent temperature missing from response
- **WHEN** Open-Meteo's response omits `apparent_temperature` for the
  midday hourly entry
- **THEN** the system falls back to classifying using raw air temperature
  for that entry

### Requirement: Weather fetch failure fallback
The system SHALL NOT crash or block suggestions if the weather fetch fails
(e.g. no network) for one or both days; it SHALL fall back to treating the
affected day(s) as unknown weather (empty hourly series, no midday signal)
and skip the weather filter tier entirely for any request using that day's
forecast.

#### Scenario: Weather API unreachable
- **WHEN** the Open-Meteo request fails or times out
- **THEN** the system proceeds to generate suggestions without applying the
  indoor/outdoor weather filter, rather than showing an error that blocks
  suggestions, for whichever day(s) could not be fetched

## ADDED Requirements

### Requirement: Weather condition icon mapping
The system SHALL map each hourly entry's Open-Meteo `weather_code` (WMO
code) to a condition category (clear, cloudy, fog, rain, snow,
thunderstorm) with a corresponding icon, so hourly forecast data can be
displayed visually rather than as a bare number.

#### Scenario: Known weather code maps to an icon
- **WHEN** an hourly entry has a `weather_code` within Open-Meteo's
  documented WMO range (e.g. 0 for clear sky, 61 for rain)
- **THEN** the system resolves it to the corresponding condition category
  and icon

#### Scenario: Unrecognized weather code falls back safely
- **WHEN** an hourly entry has a `weather_code` outside the known mapped
  ranges
- **THEN** the system resolves it to a defensive default icon rather than
  throwing or crashing
