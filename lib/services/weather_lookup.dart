import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

/// Gothenburg's coordinates — hardcoded since v1 is Gothenburg-only.
const double _gothenburgLat = 57.7089;
const double _gothenburgLon = 11.9746;

/// Why a day (or hour) was classified as indoor-favoring (or none, if
/// outdoor-favoring).
enum IndoorReason { none, rain, cold, heat }

/// Broad weather condition category, derived from Open-Meteo's WMO
/// `weather_code`, used to pick a display icon.
enum WeatherCondition { clear, cloudy, fog, rain, snow, thunderstorm, unknown }

/// One hour of forecast data.
class HourlyPoint {
  final DateTime time;
  final double temperatureC;
  final double apparentTemperatureC;
  final double precipitationMm;
  final int weatherCode;

  const HourlyPoint({
    required this.time,
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.precipitationMm,
    required this.weatherCode,
  });

  WeatherCondition get condition => conditionForWeatherCode(weatherCode);
}

/// Maps Open-Meteo's WMO `weather_code` to a broad condition category.
/// Falls back to [WeatherCondition.unknown] for any code outside the
/// documented ranges, so an unexpected code never throws.
WeatherCondition conditionForWeatherCode(int code) {
  if (code == 0) return WeatherCondition.clear;
  if (code >= 1 && code <= 3) return WeatherCondition.cloudy;
  if (code == 45 || code == 48) return WeatherCondition.fog;
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) {
    return WeatherCondition.rain;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return WeatherCondition.snow;
  }
  if (code >= 95 && code <= 99) return WeatherCondition.thunderstorm;
  return WeatherCondition.unknown;
}

/// Icon representing a broad weather condition, for hourly graph display.
IconData iconForCondition(WeatherCondition condition) {
  switch (condition) {
    case WeatherCondition.clear:
      return Icons.wb_sunny;
    case WeatherCondition.cloudy:
      return Icons.wb_cloudy;
    case WeatherCondition.fog:
      return Icons.blur_on;
    case WeatherCondition.rain:
      return Icons.umbrella;
    case WeatherCondition.snow:
      return Icons.ac_unit;
    case WeatherCondition.thunderstorm:
      return Icons.thunderstorm;
    case WeatherCondition.unknown:
      return Icons.help_outline;
  }
}

/// Icon color for a broad weather condition, matching yr.no's palette
/// (yellow sun, grey cloud/fog, blue rain/snow, dark thunderstorm) so
/// icons read at a glance instead of all sharing one theme color.
Color colorForCondition(WeatherCondition condition) {
  switch (condition) {
    case WeatherCondition.clear:
      return const Color(0xFFFFC107);
    case WeatherCondition.cloudy:
    case WeatherCondition.fog:
      return const Color(0xFF9E9E9E);
    case WeatherCondition.rain:
    case WeatherCondition.snow:
      return const Color(0xFF4FC3F7);
    case WeatherCondition.thunderstorm:
      return const Color(0xFF5C6BC0);
    case WeatherCondition.unknown:
      return const Color(0xFF9E9E9E);
  }
}

/// Result of a single hourly entry's indoor/outdoor classification — used
/// by the recommender, derived from a day's midday (12:00) [HourlyPoint].
class WeatherResult {
  final double temperatureC;
  final double apparentTemperatureC;
  final IndoorReason indoorReason;

  bool get isIndoorFavoring => indoorReason != IndoorReason.none;

  const WeatherResult({
    required this.temperatureC,
    required this.apparentTemperatureC,
    required this.indoorReason,
  });
}

/// Today's and tomorrow's full hourly forecast (24 entries each), each
/// independently possibly empty if that day's forecast couldn't be
/// fetched or found in the response (see weather-lookup spec: fallback
/// treats weather as unknown and skips the weather filter tier entirely).
class WeatherForecast {
  final List<HourlyPoint> today;
  final List<HourlyPoint> tomorrow;

  const WeatherForecast({this.today = const [], this.tomorrow = const []});

  /// The recommender-facing indoor/outdoor signal for [day], derived from
  /// that day's midday (12:00) hourly entry. Null if that day's hourly
  /// list has no midday entry (empty fetch, or a gap in the series).
  WeatherResult? middayResult(List<HourlyPoint> day) {
    for (final point in day) {
      if (point.time.hour == 12) {
        return WeatherResult(
          temperatureC: point.temperatureC,
          apparentTemperatureC: point.apparentTemperatureC,
          indoorReason: WeatherLookup._classify(point.apparentTemperatureC, point.precipitationMm),
        );
      }
    }
    return null;
  }
}

/// Fetches a full 24-hour forecast (temperature, apparent temperature,
/// precipitation, weather condition code) for Gothenburg today and
/// tomorrow from Open-Meteo (free, no API key required), in one request.
class WeatherLookup {
  static Future<WeatherForecast> fetchForecast() async {
    // `timezone=Europe/Stockholm` makes Open-Meteo return `hourly.time`
    // strings already in local time, so picking "today/tomorrow" is a
    // string-prefix match — no manual DST/UTC-offset math needed.
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$_gothenburgLat&longitude=$_gothenburgLon'
      '&hourly=temperature_2m,apparent_temperature,precipitation,weather_code'
      '&forecast_days=2&timezone=Europe%2FStockholm',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return const WeatherForecast();
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final hourly = json['hourly'] as Map<String, dynamic>;
      final times = (hourly['time'] as List).cast<String>();
      final temps = hourly['temperature_2m'] as List;
      final apparentTemps = hourly['apparent_temperature'] as List;
      final precipitations = hourly['precipitation'] as List;
      final weatherCodes = hourly['weather_code'] as List;

      // Derive both date labels from the response itself (Stockholm-local,
      // since `timezone=Europe/Stockholm` was requested) rather than the
      // device clock — a device set to a different timezone would
      // otherwise mislabel or miss both "today" and "tomorrow".
      final firstDate = DateTime.parse(times.first.substring(0, 10));
      // Calendar-day arithmetic via the DateTime constructor (which
      // normalizes month/year rollover), not `add(Duration(days: 1))` —
      // a elapsed-24h duration lands on the SAME calendar date on a
      // device-timezone DST fall-back day (25-hour day), which would
      // silently alias tomorrowLabel to todayLabel and replace tomorrow's
      // forecast with today's.
      final todayLabel = _dateLabel(firstDate);
      final tomorrowLabel = _dateLabel(
        DateTime(firstDate.year, firstDate.month, firstDate.day + 1),
      );

      final points = <String, List<HourlyPoint>>{todayLabel: [], tomorrowLabel: []};
      assert(todayLabel != tomorrowLabel, 'today/tomorrow date labels must never collide');
      for (var i = 0; i < times.length; i++) {
        final dateLabel = times[i].substring(0, 10);
        final bucket = points[dateLabel];
        if (bucket == null) continue; // outside today/tomorrow, ignore
        final point = _hourlyPoint(times[i], temps[i], apparentTemps[i], precipitations[i], weatherCodes[i]);
        if (point != null) bucket.add(point);
      }

      return WeatherForecast(
        today: points[todayLabel] ?? const [],
        tomorrow: points[tomorrowLabel] ?? const [],
      );
    } catch (_) {
      // Network failure, timeout, or malformed response: caller falls back
      // to skipping the weather filter tier entirely for both days.
      return const WeatherForecast();
    }
  }

  static String _dateLabel(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static HourlyPoint? _hourlyPoint(
    String time,
    dynamic rawTemp,
    dynamic rawApparent,
    dynamic rawPrecipitation,
    dynamic rawWeatherCode,
  ) {
    // A gap in Open-Meteo's hourly series (null value) for this specific
    // entry only drops this one hour — it must not throw and take down
    // the rest of the day's otherwise-good entries via the outer catch.
    if (rawTemp == null || rawPrecipitation == null || rawWeatherCode == null) return null;
    final temp = (rawTemp as num).toDouble();
    // Fall back to raw temperature if Open-Meteo omits apparent_temperature
    // for this entry.
    final apparentTemp = rawApparent == null ? temp : (rawApparent as num).toDouble();
    return HourlyPoint(
      time: DateTime.parse(time),
      temperatureC: temp,
      apparentTemperatureC: apparentTemp,
      precipitationMm: (rawPrecipitation as num).toDouble(),
      weatherCode: (rawWeatherCode as num).toInt(),
    );
  }

  /// Rain or extreme apparent (feels-like) temperature favors indoor;
  /// clear/mild apparent temperature favors outdoor. Using apparent
  /// temperature (Open-Meteo's built-in wind chill + humidity blend)
  /// instead of raw air temperature matters in Gothenburg, where wind is a
  /// significant factor. Thresholds are a simple, defensible heuristic —
  /// not a full meteorological model.
  static IndoorReason _classify(double apparentTemperatureC, double precipitationMm) {
    if (precipitationMm > 0.2) return IndoorReason.rain;
    if (apparentTemperatureC < 2) return IndoorReason.cold;
    if (apparentTemperatureC > 28) return IndoorReason.heat;
    return IndoorReason.none;
  }
}
