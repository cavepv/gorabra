## MODIFIED Requirements

### Requirement: Fetch today's Gothenburg weather
The system SHALL fetch hourly forecast weather for Gothenburg from the
Open-Meteo API (no API key required) covering both today and tomorrow, and
SHALL select the forecast entry closest to 12:00 local time (Europe/
Stockholm) for each day when the user requests activity suggestions or
views the weather summary.

#### Scenario: Successful weather fetch for both days
- **WHEN** the user opens the planner and network access is available
- **THEN** the system retrieves midday temperature, apparent temperature,
  and precipitation data for Gothenburg for both today and tomorrow from
  Open-Meteo, in a single request

#### Scenario: One day succeeds, the other is unavailable
- **WHEN** the Open-Meteo response is missing the hourly entry for one of
  the two days (e.g. near a UTC day boundary)
- **THEN** the system returns a `WeatherResult` for the day that is
  available and `null` for the other day, without failing the whole fetch

### Requirement: Classify weather as indoor- or outdoor-appropriate
The system SHALL classify each day's fetched weather as favoring indoor or
outdoor activities using apparent temperature (feels-like, combining wind
chill and humidity) rather than raw air temperature — e.g. rain or extreme
apparent temperature favors indoor; clear/mild apparent temperature favors
outdoor — producing a single boolean or equivalent signal consumable by the
recommender for whichever day is selected.

#### Scenario: Rainy day classification
- **WHEN** Open-Meteo reports active precipitation for the selected day
- **THEN** the system classifies that day as indoor-favoring

#### Scenario: Clear mild day classification
- **WHEN** Open-Meteo reports no precipitation and a comfortable apparent
  temperature for the selected day
- **THEN** the system classifies that day as outdoor-favoring

#### Scenario: Windy but mild classification uses feels-like temperature
- **WHEN** Open-Meteo reports a raw air temperature within the comfortable
  range but a lower apparent temperature due to wind, such that apparent
  temperature crosses the indoor-favoring threshold
- **THEN** the system classifies that day as indoor-favoring, based on
  apparent temperature rather than raw air temperature

#### Scenario: Apparent temperature missing from response
- **WHEN** Open-Meteo's response omits `apparent_temperature` for an
  otherwise valid forecast entry
- **THEN** the system falls back to classifying using raw air temperature
  for that entry

### Requirement: Weather fetch failure fallback
The system SHALL NOT crash or block suggestions if the weather fetch fails
(e.g. no network) for one or both days; it SHALL fall back to treating the
affected day(s) as unknown weather and skip the weather filter tier
entirely for any request using that day's forecast.

#### Scenario: Weather API unreachable
- **WHEN** the Open-Meteo request fails or times out
- **THEN** the system proceeds to generate suggestions without applying the
  indoor/outdoor weather filter, rather than showing an error that blocks
  suggestions, for whichever day(s) could not be fetched
