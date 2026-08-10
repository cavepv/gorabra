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
  int costSek = 0,
  List<TransportMode> transportModes = const [TransportMode.walk],
  bool homeOnly = false,
  double? lat,
  double? lng,
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
    costSek: costSek,
    homeOnly: homeOnly,
    lat: lat,
    lng: lng,
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
        kidAges: [5],
        kidInterests: ['animals'],
        maxBudgetSek: 100,
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
        kidAges: [5],
        kidInterests: ['animals'], // no activity matches this interest
        maxBudgetSek: 100,
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
          costSek: 100,
        ),
      ];
      final prefs = UserPreferences(
        kidAges: [2], // outside age range even after other relaxations
        kidInterests: ['animals'],
        maxBudgetSek: 100,
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
        _activity(id: 'expensive', costSek: 800),
        _activity(id: 'carOnly', transportModes: [TransportMode.car]),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 0,
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

    test('multi-kid age: only an activity covering every kid\'s age matches', () {
      final catalog = [
        _activity(id: 'coversBoth', minAge: 5, maxAge: 10),
        _activity(id: 'coversOne', minAge: 3, maxAge: 6),
      ];
      final prefs = UserPreferences(
        kidAges: [5, 7],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.isClosestMatch, isFalse);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'coversBoth');
    });

    test('multi-kid age with no overlap falls back to age-relaxed pool', () {
      final catalog = [_activity(id: 'a', minAge: 4, maxAge: 6)];
      final prefs = UserPreferences(
        kidAges: [3, 12], // no activity range spans both
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.isClosestMatch, isTrue);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'a');
    });

    test('stayHome false: homeOnly activities are excluded from the pool', () {
      final catalog = [
        _activity(id: 'outing', homeOnly: false),
        _activity(id: 'homeActivity', homeOnly: true),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
        stayHome: false,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'outing');
    });

    test('stayHome true: hard-filters to homeOnly pool, never relaxed', () {
      final catalog = [
        _activity(id: 'outing', homeOnly: false),
        _activity(id: 'homeActivity', homeOnly: true, interests: ['lek']),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: ['unmatched-interest'], // should relax, but stay home-only
        maxBudgetSek: 100,
        hasCar: true,
        stayHome: true,
      );
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'homeActivity');
    });

    test('stayHome true: hasCar has no effect on home activity results', () {
      final catalog = [
        _activity(
          id: 'homeActivity',
          homeOnly: true,
          transportModes: [TransportMode.car], // shouldn't matter when home
        ),
      ];
      final prefsNoCar = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: false,
        stayHome: true,
      );
      final prefsWithCar = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
        stayHome: true,
      );

      final resultNoCar = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefsNoCar,
        weather: null,
      );
      final resultWithCar = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefsWithCar,
        weather: null,
      );

      expect(resultNoCar.activities, hasLength(1));
      expect(resultWithCar.activities, hasLength(1));
      expect(resultNoCar.activities.first.id, 'homeActivity');
      expect(resultWithCar.activities.first.id, 'homeActivity');
    });

    test('distance filter: excludes activities outside the radius', () {
      final catalog = [
        _activity(id: 'near', lat: 57.71, lng: 11.98), // ~0.3km from user
        _activity(id: 'far', lat: 58.41, lng: 15.62), // ~230km from user (Linköping)
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
        maxDistanceKm: 10,
        userLat: 57.7089,
        userLng: 11.9746,
      );

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'near');
    });

    test('distance filter: never relaxed even if it empties the pool', () {
      final catalog = [
        _activity(id: 'far', interests: ['animals'], lat: 58.41, lng: 15.62),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: ['animals'],
        maxBudgetSek: 100,
        hasCar: true,
        maxDistanceKm: 10,
        userLat: 57.7089,
        userLng: 11.9746,
      );

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, isEmpty);
    });

    test('distance filter: homeOnly activities are exempt regardless of distance', () {
      final catalog = [
        _activity(id: 'home', homeOnly: true, lat: null, lng: null),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
        stayHome: true,
        maxDistanceKm: 5,
        userLat: 57.7089,
        userLng: 11.9746,
      );

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'home');
    });

    test('distance filter off when maxDistanceKm is null', () {
      final catalog = [
        _activity(id: 'far', lat: 58.41, lng: 15.62),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'far');
    });

    test('excludeIds: previous spin\'s activities are avoided when alternatives exist', () {
      final catalog = [
        _activity(id: 'a'),
        _activity(id: 'b'),
        _activity(id: 'c'),
        _activity(id: 'd'),
        _activity(id: 'e'),
      ];
      final prefs = UserPreferences(kidAges: [5], kidInterests: [], maxBudgetSek: 100, hasCar: true);

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
        excludeIds: {'a', 'b'},
      );

      // 3 non-excluded alternatives exist (c, d, e) so all 3 slots can be
      // filled without any repeat — a real repeat should never appear here.
      expect(result.activities, hasLength(3));
      expect(result.activities.map((a) => a.id), containsAll(['c', 'd', 'e']));
    });

    test('excludeIds: tops up with a repeat rather than shrinking the result count', () {
      final catalog = [_activity(id: 'only-one')];
      final prefs = UserPreferences(kidAges: [5], kidInterests: [], maxBudgetSek: 100, hasCar: true);

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
        excludeIds: {'only-one'},
      );

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'only-one');
    });

    test('excludeIds: default (empty) behaves exactly like no exclusion', () {
      final catalog = [_activity(id: 'a'), _activity(id: 'b')];
      final prefs = UserPreferences(kidAges: [5], kidInterests: [], maxBudgetSek: 100, hasCar: true);

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
      );

      expect(result.activities, hasLength(2));
      expect(result.activities.map((a) => a.id), containsAll(['a', 'b']));
    });

    test('excludeIds: never changes which relaxation tier is selected', () {
      // Only one activity matches the full (unrelaxed) filter set — even
      // though excludeIds covers it, tier 0 still "has a match" (the tier
      // check ignores exclusion), so isClosestMatch must stay false and the
      // excluded activity is topped back up rather than falling through to
      // a more-relaxed tier.
      final catalog = [_activity(id: 'match', interests: ['vatten'])];
      final prefs = UserPreferences(kidAges: [5], kidInterests: ['vatten'], maxBudgetSek: 100, hasCar: true);

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
        excludeIds: {'match'},
      );

      expect(result.isClosestMatch, isFalse);
      expect(result.activities.map((a) => a.id), contains('match'));
    });
  });
}
