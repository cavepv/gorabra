import 'dart:convert';

import 'package:http/http.dart' as http;

/// Gothenburg's coordinates — hardcoded since v1 is Gothenburg-only.
const double _gothenburgLat = 57.7089;
const double _gothenburgLon = 11.9746;

/// Result of today's weather lookup, or null if the lookup failed (see
/// weather-lookup spec: fallback treats weather as unknown and skips the
/// weather filter tier entirely).
class WeatherResult {
  final double temperatureC;
  final bool isIndoorFavoring;

  const WeatherResult({
    required this.temperatureC,
    required this.isIndoorFavoring,
  });
}

/// Fetches today's current weather for Gothenburg from Open-Meteo (free,
/// no API key required) and classifies it as indoor- or outdoor-favoring.
class WeatherLookup {
  static Future<WeatherResult?> fetchToday() async {
    final uri = Uri.parse(
      'https://api.open-meteo.com/v1/forecast'
      '?latitude=$_gothenburgLat&longitude=$_gothenburgLon'
      '&current=temperature_2m,precipitation',
    );
    try {
      final response = await http.get(uri).timeout(const Duration(seconds: 8));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final current = json['current'] as Map<String, dynamic>;
      final temp = (current['temperature_2m'] as num).toDouble();
      final precipitation = (current['precipitation'] as num).toDouble();
      return WeatherResult(
        temperatureC: temp,
        isIndoorFavoring: _classify(temp, precipitation),
      );
    } catch (_) {
      // Network failure, timeout, or malformed response: caller falls back
      // to skipping the weather filter tier entirely.
      return null;
    }
  }

  /// Rain or extreme temperature favors indoor; clear/mild weather favors
  /// outdoor. Thresholds are a simple, defensible heuristic — not a
  /// meteorological model.
  static bool _classify(double temperatureC, double precipitationMm) {
    if (precipitationMm > 0.2) return true;
    if (temperatureC < 2 || temperatureC > 28) return true;
    return false;
  }
}
