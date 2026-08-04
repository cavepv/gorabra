## ADDED Requirements

### Requirement: Fetch today's Gothenburg weather
The system SHALL fetch today's current weather for Gothenburg from the
Open-Meteo API (no API key required) when the user requests activity
suggestions.

#### Scenario: Successful weather fetch
- **WHEN** the user requests suggestions and network access is available
- **THEN** the system retrieves today's temperature and precipitation/
  condition data for Gothenburg from Open-Meteo

### Requirement: Classify weather as indoor- or outdoor-appropriate
The system SHALL classify the fetched weather as favoring indoor or outdoor
activities (e.g. rain or extreme temperature favors indoor; clear/mild
weather favors outdoor), producing a single boolean or equivalent signal
consumable by the recommender.

#### Scenario: Rainy day classification
- **WHEN** Open-Meteo reports active precipitation
- **THEN** the system classifies today as indoor-favoring

#### Scenario: Clear mild day classification
- **WHEN** Open-Meteo reports no precipitation and a comfortable temperature
- **THEN** the system classifies today as outdoor-favoring

### Requirement: Weather fetch failure fallback
The system SHALL NOT crash or block suggestions if the weather fetch fails
(e.g. no network); it SHALL fall back to treating weather as unknown and
skip the weather filter tier entirely for that request.

#### Scenario: Weather API unreachable
- **WHEN** the Open-Meteo request fails or times out
- **THEN** the system proceeds to generate suggestions without applying the
  indoor/outdoor weather filter, rather than showing an error that blocks
  suggestions
