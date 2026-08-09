import 'dart:math';

import '../models/activity.dart';
import 'distance.dart';
import 'weather_lookup.dart';

/// User inputs collected once per session (see planner-ui spec).
class UserPreferences {
  final List<int> kidAges;
  final List<String> kidInterests;

  /// Max SEK the user wants to spend on the whole outing (flat, not
  /// scaled by party size) — hard filter, never relaxed. 0 means
  /// free-only.
  final int maxBudgetSek;
  final bool hasCar;

  /// When true, hard-filters to `homeOnly` activities only (never
  /// relaxed, same tier as cost/transport). When false, excludes
  /// `homeOnly` activities from normal "go somewhere" suggestions.
  final bool stayHome;

  /// Optional distance-radius filter: when non-null, hard-filters (never
  /// relaxed) to activities within `maxDistanceKm` of `userLat`/`userLng`.
  /// `homeOnly` activities are always exempt, same as the `hasCar` filter.
  final double? maxDistanceKm;
  final double? userLat;
  final double? userLng;

  UserPreferences({
    required this.kidAges,
    required this.kidInterests,
    required this.maxBudgetSek,
    required this.hasCar,
    this.stayHome = false,
    this.maxDistanceKm,
    this.userLat,
    this.userLng,
  }) : assert(kidAges.isNotEmpty, 'kidAges must have at least one entry');
}

/// Result of a recommendation request: 1-3 activities plus whether filters
/// had to be relaxed to produce them (planner-ui shows a "closest matches"
/// label in that case).
class RecommendationResult {
  final List<Activity> activities;
  final bool isClosestMatch;

  const RecommendationResult({
    required this.activities,
    required this.isClosestMatch,
  });
}

/// Filters the activity catalog and randomly picks 1-3 suggestions.
///
/// Filter tiers (see design.md): interests → cost/budget → transport/car →
/// stayHome/homeOnly → distance radius → weather → age. Cost, transport,
/// stayHome, and distance radius are hard filters that are never relaxed;
/// interests, weather, and age are relaxed in that order if the pool is
/// empty. social/physicalActivity only affect the odds of
/// being picked, never exclude an activity. transport/hasCar and the
/// distance radius never exclude a `homeOnly` activity — there's nowhere
/// to drive to (or measure distance to) when staying home.
class ActivityRecommender {
  final Random _random;

  ActivityRecommender({Random? random}) : _random = random ?? Random();

  RecommendationResult recommend({
    required List<Activity> catalog,
    required UserPreferences prefs,
    required WeatherResult? weather,
  }) {
    // Cost, transport, stayHome, and distance radius are never relaxed —
    // this is the floor every candidate pool must satisfy.
    final base = catalog.where((a) {
      final withinBudget = a.costSek <= prefs.maxBudgetSek;
      // hasCar never affects home activities — there's nowhere to drive to.
      final reachable =
          a.homeOnly || prefs.hasCar || a.transportModes.any((m) => m != TransportMode.car);
      final homeMatch = prefs.stayHome ? a.homeOnly : !a.homeOnly;
      final withinDistance = _matchesDistance(a, prefs);
      return withinBudget && reachable && homeMatch && withinDistance;
    }).toList();

    bool matchesInterests(Activity a) =>
        prefs.kidInterests.isEmpty ||
        a.interests.any(prefs.kidInterests.contains);

    bool matchesWeather(Activity a) =>
        weather == null || a.indoor == weather.isIndoorFavoring;

    bool matchesAge(Activity a) =>
        prefs.kidAges.every((age) => age >= a.minAge && age <= a.maxAge);

    // Try progressively relaxed filter combinations, in the locked order:
    // full filters -> drop interests -> drop weather -> drop age -> base only.
    final attempts = <bool Function(Activity)>[
      (a) => matchesInterests(a) && matchesWeather(a) && matchesAge(a),
      (a) => matchesWeather(a) && matchesAge(a),
      (a) => matchesAge(a),
      (a) => true,
    ];

    for (var i = 0; i < attempts.length; i++) {
      final pool = base.where(attempts[i]).toList();
      if (pool.isNotEmpty) {
        return RecommendationResult(
          activities: _weightedPick(pool),
          isClosestMatch: i > 0,
        );
      }
    }

    // Even the cost/transport-only base pool is empty (e.g. no activities
    // fit the budget/car constraints at all) — nothing to suggest.
    return const RecommendationResult(activities: [], isClosestMatch: true);
  }

  /// `homeOnly` activities are always exempt (no fixed place to measure
  /// distance to). If the radius filter is off (`maxDistanceKm` null) or
  /// missing coordinates, every activity passes.
  bool _matchesDistance(Activity a, UserPreferences prefs) {
    if (a.homeOnly) return true;
    if (prefs.maxDistanceKm == null || prefs.userLat == null || prefs.userLng == null) {
      return true;
    }
    if (a.lat == null || a.lng == null) return true;
    final distance = haversineKm(prefs.userLat!, prefs.userLng!, a.lat!, a.lng!);
    return distance <= prefs.maxDistanceKm!;
  }

  /// Boosts social/physicalActivity matches by duplicating
  /// them in the sampling pool, then draws up to 3 unique activities.
  /// Simplest mechanism that works for a catalog this small (see design.md);
  /// upgrade to real weighted sampling if the catalog grows significantly.
  List<Activity> _weightedPick(List<Activity> pool) {
    final weighted = <Activity>[];
    for (final a in pool) {
      var weight = 1;
      if (a.social) weight++;
      if (a.benefits.contains('physicalActivity')) weight++;
      weighted.addAll(List.filled(weight, a));
    }

    weighted.shuffle(_random);
    final picked = <Activity>[];
    for (final a in weighted) {
      if (picked.contains(a)) continue;
      picked.add(a);
      if (picked.length == 3) break;
    }
    return picked;
  }
}
