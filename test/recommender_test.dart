import 'dart:math';

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
        weather: const WeatherResult(
          temperatureC: 20,
          apparentTemperatureC: 20,
          indoorReason: IndoorReason.none,
        ),
      );

      expect(result.isClosestMatch, isFalse);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'a');
    });

    test('empty after hard filters: relaxes interests then finds a match', () {
      final catalog = [
        _activity(
          id: 'a',
          interests: ['music'],
          indoor: false,
          minAge: 1,
          maxAge: 12,
        ),
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
        weather: const WeatherResult(
          temperatureC: 20,
          apparentTemperatureC: 20,
          indoorReason: IndoorReason.none,
        ),
      );

      expect(result.isClosestMatch, isTrue);
      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'a');
    });

    test(
      'full relaxation still empty: falls back to cost/transport-only pool',
      () {
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
          weather: const WeatherResult(
            temperatureC: 20,
            apparentTemperatureC: 20,
            indoorReason: IndoorReason.none,
          ),
        );

        expect(result.isClosestMatch, isTrue);
        expect(result.activities, hasLength(1));
        expect(result.activities.first.id, 'a');
      },
    );

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
      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

      expect(result.activities, isEmpty);
      expect(result.isClosestMatch, isTrue);
    });

    test('weather is advisory, not a hard filter: a weather-mismatched '
        'activity is still eligible (no relaxation needed)', () {
      final catalog = [_activity(id: 'indoorOnlyGood', indoor: true)];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      // Weather favors outdoor — this activity is indoor, a full mismatch.
      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: const WeatherResult(
          temperatureC: 20,
          apparentTemperatureC: 20,
          indoorReason: IndoorReason.none,
        ),
      );

      // Would have been excluded/relaxed under the old hard-filter design.
      expect(result.isClosestMatch, isFalse);
      expect(result.activities, hasLength(1));
      expect(result.eligiblePoolSize, 1);
    });

    test('weather is advisory: matching activities are picked more often '
        'than mismatched ones over many spins', () {
      final catalog = [
        _activity(id: 'matches', indoor: true),
        _activity(id: 'mismatches', indoor: false),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      const weather = WeatherResult(
        temperatureC: 5,
        apparentTemperatureC: 3,
        indoorReason: IndoorReason.cold, // indoor-favoring
      );
      final random = Random(42);
      var matchesFirst = 0;
      const spins = 500;
      for (var i = 0; i < spins; i++) {
        final result = ActivityRecommender(
          random: random,
        ).recommend(catalog: catalog, prefs: prefs, weather: weather);
        if (result.activities.first.id == 'matches') matchesFirst++;
      }

      // Both are always in the pool (advisory, never excluded) — but the
      // matching one should come up front more often thanks to its extra
      // weight, expected ~2/3 of the time (weight 2 vs weight 1). A
      // threshold barely above 50% wouldn't distinguish a real 2:1 boost
      // from an accidentally-removed one (both would clear >50%), so this
      // checks a range close to the true expected ratio instead.
      expect(matchesFirst, inInclusiveRange(spins * 0.55, spins * 0.78));
    });

    test(
      'multi-kid age: only an activity covering every kid\'s age matches',
      () {
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
        final result = ActivityRecommender(
          random: null,
        ).recommend(catalog: catalog, prefs: prefs, weather: null);

        expect(result.isClosestMatch, isFalse);
        expect(result.activities, hasLength(1));
        expect(result.activities.first.id, 'coversBoth');
      },
    );

    test('multi-kid age with no overlap falls back to age-relaxed pool', () {
      final catalog = [_activity(id: 'a', minAge: 4, maxAge: 6)];
      final prefs = UserPreferences(
        kidAges: [3, 12], // no activity range spans both
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

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
      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

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
        kidInterests: [
          'unmatched-interest',
        ], // should relax, but stay home-only
        maxBudgetSek: 100,
        hasCar: true,
        stayHome: true,
      );
      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

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

      final resultNoCar = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefsNoCar, weather: null);
      final resultWithCar = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefsWithCar, weather: null);

      expect(resultNoCar.activities, hasLength(1));
      expect(resultWithCar.activities, hasLength(1));
      expect(resultNoCar.activities.first.id, 'homeActivity');
      expect(resultWithCar.activities.first.id, 'homeActivity');
    });

    test('indoorOnly true: hard-filters to indoor pool, never relaxed', () {
      final catalog = [
        _activity(id: 'outdoorActivity', indoor: false, interests: ['lek']),
        _activity(id: 'indoorActivity', indoor: true),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        // Matches the outdoor activity's interest — without the indoorOnly
        // hard filter, 'outdoorActivity' would win on interest match alone.
        kidInterests: ['lek'],
        maxBudgetSek: 100,
        hasCar: true,
        indoorOnly: true,
      );
      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'indoorActivity');
    });

    test(
      'indoorOnly true + stayHome true: homeOnly (always indoor) activities still match',
      () {
        final catalog = [
          _activity(id: 'homeActivity', homeOnly: true, indoor: true),
        ];
        final prefs = UserPreferences(
          kidAges: [5],
          kidInterests: [],
          maxBudgetSek: 100,
          hasCar: true,
          stayHome: true,
          indoorOnly: true,
        );
        final result = ActivityRecommender(
          random: null,
        ).recommend(catalog: catalog, prefs: prefs, weather: null);

        expect(result.activities, hasLength(1));
        expect(result.activities.first.id, 'homeActivity');
      },
    );

    test('distance filter: excludes activities outside the radius', () {
      final catalog = [
        _activity(id: 'near', lat: 57.71, lng: 11.98), // ~0.3km from user
        _activity(
          id: 'far',
          lat: 58.41,
          lng: 15.62,
        ), // ~230km from user (Linköping)
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

      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

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

      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

      expect(result.activities, isEmpty);
    });

    test(
      'distance filter: homeOnly activities are exempt regardless of distance',
      () {
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

        final result = ActivityRecommender(
          random: null,
        ).recommend(catalog: catalog, prefs: prefs, weather: null);

        expect(result.activities, hasLength(1));
        expect(result.activities.first.id, 'home');
      },
    );

    test('distance filter off when maxDistanceKm is null', () {
      final catalog = [_activity(id: 'far', lat: 58.41, lng: 15.62)];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );

      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

      expect(result.activities, hasLength(1));
      expect(result.activities.first.id, 'far');
    });

    test(
      'excludeIds: previous spin\'s activities are avoided when alternatives exist',
      () {
        final catalog = [
          _activity(id: 'a'),
          _activity(id: 'b'),
          _activity(id: 'c'),
          _activity(id: 'd'),
          _activity(id: 'e'),
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
          excludeIds: {'a', 'b'},
        );

        // 3 non-excluded alternatives exist (c, d, e) so all 3 slots can be
        // filled without any repeat — a real repeat should never appear here.
        expect(result.activities, hasLength(3));
        expect(
          result.activities.map((a) => a.id),
          containsAll(['c', 'd', 'e']),
        );
      },
    );

    test(
      'excludeIds: tops up with a repeat rather than shrinking the result count',
      () {
        final catalog = [_activity(id: 'only-one')];
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
          excludeIds: {'only-one'},
        );

        expect(result.activities, hasLength(1));
        expect(result.activities.first.id, 'only-one');
      },
    );

    test('excludeIds: default (empty) behaves exactly like no exclusion', () {
      final catalog = [_activity(id: 'a'), _activity(id: 'b')];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );

      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

      expect(result.activities, hasLength(2));
      expect(result.activities.map((a) => a.id), containsAll(['a', 'b']));
    });

    test('excludeIds: never changes which relaxation tier is selected', () {
      // Only one activity matches the full (unrelaxed) filter set — even
      // though excludeIds covers it, tier 0 still "has a match" (the tier
      // check ignores exclusion), so isClosestMatch must stay false and the
      // excluded activity is topped back up rather than falling through to
      // a more-relaxed tier.
      final catalog = [
        _activity(id: 'match', interests: ['vatten']),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: ['vatten'],
        maxBudgetSek: 100,
        hasCar: true,
      );

      final result = ActivityRecommender(random: null).recommend(
        catalog: catalog,
        prefs: prefs,
        weather: null,
        excludeIds: {'match'},
      );

      expect(result.isClosestMatch, isFalse);
      expect(result.activities.map((a) => a.id), contains('match'));
    });

    test('eligiblePoolSize reports the size of the tier that matched', () {
      // 3 activities match the full filter set, 2 more only match once age
      // is relaxed — eligiblePoolSize should reflect whichever tier fired.
      final catalog = [
        _activity(id: 'a', interests: ['vatten']),
        _activity(id: 'b', interests: ['vatten']),
        _activity(id: 'c', interests: ['vatten']),
        _activity(id: 'd', interests: ['annat'], minAge: 20, maxAge: 30),
        _activity(id: 'e', interests: ['annat'], minAge: 20, maxAge: 30),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: ['vatten'],
        maxBudgetSek: 100,
        hasCar: true,
      );

      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

      expect(result.isClosestMatch, isFalse);
      expect(result.eligiblePoolSize, 3);
    });

    test('eligiblePoolSize counts unique ids, not raw entries — a duplicate '
        'id in the matched tier must not double-count', () {
      // Regression test for the pool.length vs. unique-id-count bug: a
      // catalog with a duplicate id would let this test pass even with
      // the old `pool.length` implementation, so it deliberately
      // constructs a tier where entry count and unique-id count differ.
      final catalog = [
        _activity(id: 'a'),
        _activity(id: 'a'), // duplicate id, distinct entry
        _activity(id: 'b'),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );

      final result = ActivityRecommender(
        random: null,
      ).recommend(catalog: catalog, prefs: prefs, weather: null);

      expect(
        result.eligiblePoolSize,
        2,
        reason: '3 entries but only 2 unique ids',
      );
    });

    test('eventual coverage: repeated spins present every eligible activity, '
        'not just a high-weight subset', () {
      // 12 activities, mirroring the real catalog's shape: a handful get
      // extra sampling weight (social + physicalActivity), most don't.
      // A naive "only exclude the last spin" approach lets the high-weight
      // ones dominate indefinitely (the bug being fixed here) — this test
      // simulates the same cumulative-exclude-with-reset loop planner_screen
      // uses and asserts the full pool surfaces within one cycle.
      final catalog = [
        for (var i = 0; i < 3; i++)
          _activity(
            id: 'high$i',
            social: true,
            benefits: const ['physicalActivity'],
          ),
        for (var i = 0; i < 9; i++) _activity(id: 'low$i'),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final recommender = ActivityRecommender(random: Random(42));

      final shownIds = <String>{};
      final seenAcrossCycle = <String>{};
      // ceil(12 / 3) = 4 spins should be enough to cover all 12 ids once,
      // mirroring planner_screen's _spin()/_shownIds bookkeeping exactly.
      for (var spin = 0; spin < 4; spin++) {
        final result = recommender.recommend(
          catalog: catalog,
          prefs: prefs,
          weather: null,
          excludeIds: Set<String>.from(shownIds),
        );
        seenAcrossCycle.addAll(result.activities.map((a) => a.id));
        final newIds = result.activities.map((a) => a.id);
        shownIds.addAll(newIds);
        // Mirrors planner_screen's reset: seed the fresh cycle with this
        // spin's ids (not an empty set) so the cycle boundary can't
        // immediately repeat what was just shown.
        if (shownIds.length >= result.eligiblePoolSize) {
          shownIds
            ..clear()
            ..addAll(newIds);
        }
      }

      expect(seenAcrossCycle, catalog.map((a) => a.id).toSet());
    });

    test('eventual coverage: repeats over many laps — every sliding window '
        'still covers the whole pool', () {
      // Seeding the reset with the just-shown ids (rather than clearing to
      // empty) means each lap after the first "borrows" one spin's worth
      // of slack from the previous lap — a fixed-width, non-overlapping
      // window no longer lines up with lap boundaries. The real guarantee
      // is weaker but still solid: every *sliding* window of
      // ceil(poolSize / pickSize) + 1 spins covers the full pool at least
      // once. This asserts that over a long run.
      final catalog = [
        for (var i = 0; i < 3; i++)
          _activity(
            id: 'high$i',
            social: true,
            benefits: const ['physicalActivity'],
          ),
        for (var i = 0; i < 9; i++) _activity(id: 'low$i'),
      ];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final recommender = ActivityRecommender(random: Random(7));
      // Empirically, once the seeded-reset carryover reaches steady state
      // every id resurfaces within 2 sub-cycles; 8 gives comfortable
      // margin without over-claiming a tight bound.
      const windowSize = 8;

      final shownIds = <String>{};
      final perSpinIds = <Set<String>>[];
      for (var spin = 0; spin < 20; spin++) {
        final result = recommender.recommend(
          catalog: catalog,
          prefs: prefs,
          weather: null,
          excludeIds: Set<String>.from(shownIds),
        );
        final newIds = result.activities.map((a) => a.id).toSet();
        perSpinIds.add(newIds);
        shownIds.addAll(newIds);
        if (shownIds.length >= result.eligiblePoolSize) {
          shownIds
            ..clear()
            ..addAll(newIds);
        }
      }

      final allIds = catalog.map((a) => a.id).toSet();
      for (var start = 0; start + windowSize <= perSpinIds.length; start++) {
        final window = perSpinIds
            .sublist(start, start + windowSize)
            .expand((s) => s)
            .toSet();
        expect(
          window,
          allIds,
          reason:
              'spins $start..${start + windowSize - 1} did not cover every activity',
        );
      }
    });

    test('eventual coverage: cycle boundary never immediately repeats the '
        'just-shown activities', () {
      // Regression test: an earlier version of the reset simply cleared
      // `shownIds` to empty at cycle end, which let the exact trio just
      // shown reappear on the very next spin. The fix seeds the new
      // cycle with those ids instead.
      //
      // Scope: this guarantee holds when the pool size is evenly
      // divisible by the pick size (3 here), since `_shownIds` then
      // never has fewer than 3 unseen candidates left before a reset —
      // `_weightedPick` always has enough unseen ids to fill a spin
      // without falling back to its top-up-with-repeats path. When the
      // pool isn't evenly divisible (see the "not evenly divisible"
      // test below), the last spin of a lap may have fewer than 3
      // unseen candidates and legitimately top up with a repeat —
      // that's an accepted trade-off, not a regression.
      final catalog = [for (var i = 0; i < 12; i++) _activity(id: 'a$i')];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final recommender = ActivityRecommender(random: Random(3));

      final shownIds = <String>{};
      Set<String>? previousSpinIds;
      for (var spin = 0; spin < 20; spin++) {
        final result = recommender.recommend(
          catalog: catalog,
          prefs: prefs,
          weather: null,
          excludeIds: Set<String>.from(shownIds),
        );
        final newIds = result.activities.map((a) => a.id).toSet();
        if (previousSpinIds != null) {
          expect(
            newIds.intersection(previousSpinIds),
            isEmpty,
            reason:
                'spin $spin repeated an activity from the immediately previous spin',
          );
        }
        previousSpinIds = newIds;
        shownIds.addAll(newIds);
        if (shownIds.length >= result.eligiblePoolSize) {
          shownIds
            ..clear()
            ..addAll(newIds);
        }
      }
    });

    test('eventual coverage: pool size not evenly divisible by pick size still '
        'covers every activity', () {
      // 10 activities, 3 per spin — the final spin of a cycle only has 1
      // unseen candidate left and must top up with 2 repeats rather than
      // stalling or skipping coverage.
      final catalog = [for (var i = 0; i < 10; i++) _activity(id: 'a$i')];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final recommender = ActivityRecommender(random: Random(11));

      final shownIds = <String>{};
      final seen = <String>{};
      for (var spin = 0; spin < 4; spin++) {
        final result = recommender.recommend(
          catalog: catalog,
          prefs: prefs,
          weather: null,
          excludeIds: Set<String>.from(shownIds),
        );
        seen.addAll(result.activities.map((a) => a.id));
        final newIds = result.activities.map((a) => a.id);
        shownIds.addAll(newIds);
        if (shownIds.length >= result.eligiblePoolSize) {
          shownIds
            ..clear()
            ..addAll(newIds);
        }
      }

      expect(seen, catalog.map((a) => a.id).toSet());
    });

    test('eventual coverage: pool smaller than the pick size (single activity) '
        'never stalls', () {
      final catalog = [_activity(id: 'only')];
      final prefs = UserPreferences(
        kidAges: [5],
        kidInterests: [],
        maxBudgetSek: 100,
        hasCar: true,
      );
      final recommender = ActivityRecommender(random: Random(1));

      final shownIds = <String>{};
      for (var spin = 0; spin < 5; spin++) {
        final result = recommender.recommend(
          catalog: catalog,
          prefs: prefs,
          weather: null,
          excludeIds: Set<String>.from(shownIds),
        );
        expect(result.activities.map((a) => a.id), contains('only'));
        final newIds = result.activities.map((a) => a.id);
        shownIds.addAll(newIds);
        if (shownIds.length >= result.eligiblePoolSize) {
          shownIds
            ..clear()
            ..addAll(newIds);
        }
      }
    });
  });
}
