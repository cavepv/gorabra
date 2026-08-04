import 'package:flutter_test/flutter_test.dart';
import 'package:gorabra/models/activity.dart';
import 'package:gorabra/services/recommender.dart';
import 'package:gorabra/services/weather_lookup.dart';

Activity _activity({
  required String id,
  int minAge = 1,
  int maxAge = 12,
  bool indoor = false,
  List<String> interests = const [],
  List<String> parentInterest = const [],
  bool social = false,
  List<String> benefits = const [],
  Cost cost = Cost.free,
  List<TransportMode> transportModes = const [TransportMode.walk],
}) {
  return Activity(
    id: id,
    name: id,
    description: 'desc',
    minAge: minAge,
    maxAge: maxAge,
    indoor: indoor,
    interests: interests,
    parentInterest: parentInterest,
    social: social,
    benefits: benefits,
    benefitNote: 'note',
    openingHours: '09:00-17:00',
    location: 'Gothenburg',
    distanceKm: 1.0,
    transportModes: transportModes,
    cost: cost,
  );
}

void main() {
  group('ActivityRecommender', () {
    test('normal case: full filters match, no relaxation needed', () {
      final catalog = [
        _activity(id: 'a', interests: ['animals'], indoor: false),
        _activity(id: 'b', interests: ['art'], indoor: true),
      ];
      final prefs = UserPreferences(
        kidAge: 5,
        kidInterests: ['animals'],
        budget: Cost.low,
        hasCar: true,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: const WeatherResult(temperatureC: 20, apparentTemperatureC: 20, indoorReason: IndoorReason.none),
      );

      expect(result.isClosestMatch, isFalse);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'a');
    });

    test('empty after hard filters: relaxes interests then finds a match', () {
      final catalog = [
        _activity(id: 'a', interests: ['music'], indoor: false, minAge: 1, maxAge: 12),
      ];
      final prefs = UserPreferences(
        kidAge: 5,
        kidInterests: ['animals'], // no activity matches this interest
        budget: Cost.low,
        hasCar: true,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: const WeatherResult(temperatureC: 20, apparentTemperatureC: 20, indoorReason: IndoorReason.none),
      );

      expect(result.isClosestMatch, isTrue);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'a');
    });

    test('full relaxation still empty: falls back to cost/transport-only pool', () {
      final catalog = [
        _activity(
          id: 'a',
          interests: ['music'],
          indoor: true, // mismatched weather
          minAge: 8, // mismatched age
          maxAge: 12,
          cost: Cost.low,
        ),
      ];
      final prefs = UserPreferences(
        kidAge: 2, // outside age range even after other relaxations
        kidInterests: ['animals'],
        budget: Cost.low,
        hasCar: true,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: const WeatherResult(temperatureC: 20, apparentTemperatureC: 20, indoorReason: IndoorReason.none),
      );

      expect(result.isClosestMatch, isTrue);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'a');
    });

    test('cost/transport hard filters are never relaxed', () {
      final catalog = [
        _activity(id: 'expensive', cost: Cost.high),
        _activity(id: 'carOnly', transportModes: [TransportMode.car]),
      ];
      final prefs = UserPreferences(
        kidAge: 5,
        kidInterests: [],
        budget: Cost.free,
        hasCar: false,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, isEmpty);
      expect(result.isClosestMatch, isTrue);
    });
  });
}
