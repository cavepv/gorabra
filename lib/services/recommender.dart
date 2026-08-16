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

  /// When true, hard-filters to `indoor` activities only (never relaxed,
  /// same tier as cost/transport/stayHome). No-op when `stayHome` is also
  /// true since every `homeOnly` activity is already indoor.
  final bool indoorOnly;

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
    this.indoorOnly = false,
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

  /// Size of the eligible pool this pick was drawn from (after whichever
  /// relaxation tier matched). Callers can compare their cumulative
  /// "shown so far" count against this to know when every eligible
  /// activity has been shown at least once and it's time to start a new
  /// cycle (see planner_screen.dart's `_shownIds`).
  final int eligiblePoolSize;

  const RecommendationResult({
    required this.activities,
    required this.isClosestMatch,
    required this.eligiblePoolSize,
  });
}

/// Filters the activity catalog and randomly picks 1-3 suggestions.
///
/// Filter tiers (see design.md): interests → cost/budget → transport/car →
/// stayHome/homeOnly → indoorOnly → distance radius → age. Cost,
/// transport, stayHome, indoorOnly, and distance radius are hard filters
/// that are never relaxed; interests and age are relaxed in that order if
/// the pool is empty. Weather is advisory, not a hard filter — it boosts
/// (never excludes) activities whose indoor/outdoor nature matches the
/// forecast, same weighting mechanism as social/physicalActivity.
/// transport/hasCar and the distance radius never exclude a `homeOnly`
/// activity — there's nowhere to drive to (or measure distance to) when
/// staying home.
class ActivityRecommender {
  final Random _random;

  ActivityRecommender({Random? random}) : _random = random ?? Random();

  RecommendationResult recommend({
    required List<Activity> catalog,
    required UserPreferences prefs,
    required WeatherResult? weather,
    Set<String> excludeIds = const {},
  }) {
    // Cost, transport, stayHome, indoorOnly, and distance radius are never
    // relaxed —
    // this is the floor every candidate pool must satisfy.
    final base = catalog.where((a) {
      final withinBudget = a.costSek <= prefs.maxBudgetSek;
      // hasCar never affects home activities — there's nowhere to drive to.
      final reachable =
          a.homeOnly ||
          prefs.hasCar ||
          a.transportModes.any((m) => m != TransportMode.car);
      final homeMatch = prefs.stayHome ? a.homeOnly : !a.homeOnly;
      // homeOnly activities are always indoor, so this is a no-op when
      // stayHome is also on — nothing to hard-filter out there.
      final indoorMatch = prefs.indoorOnly ? a.indoor : true;
      final withinDistance = _matchesDistance(a, prefs);
      return withinBudget &&
          reachable &&
          homeMatch &&
          indoorMatch &&
          withinDistance;
    }).toList();

    bool matchesInterests(Activity a) =>
        prefs.kidInterests.isEmpty ||
        a.interests.any(prefs.kidInterests.contains);

    bool matchesAge(Activity a) =>
        prefs.kidAges.every((age) => age >= a.minAge && age <= a.maxAge);

    // Try progressively relaxed filter combinations, in the locked order:
    // full filters -> drop interests -> base only. Weather never excludes,
    // so it's not one of these tiers — see _weightedPick.
    final attempts = <bool Function(Activity)>[
      (a) => matchesInterests(a) && matchesAge(a),
      (a) => matchesAge(a),
      (a) => true,
    ];

    for (var i = 0; i < attempts.length; i++) {
      final pool = base.where(attempts[i]).toList();
      if (pool.isNotEmpty) {
        return RecommendationResult(
          activities: _weightedPick(
            pool,
            weather: weather,
            excludeIds: excludeIds,
          ),
          isClosestMatch: i > 0,
          // Unique ids, not raw entry count — a caller's cumulative
          // excludeIds set is id-based, so a hypothetical duplicate-id
          // catalog entry must not make full coverage unreachable.
          eligiblePoolSize: pool.map((a) => a.id).toSet().length,
        );
      }
    }

    // Even the cost/transport-only base pool is empty (e.g. no activities
    // fit the budget/car constraints at all) — nothing to suggest.
    return const RecommendationResult(
      activities: [],
      isClosestMatch: true,
      eligiblePoolSize: 0,
    );
  }

  /// `homeOnly` activities are always exempt (no fixed place to measure
  /// distance to). If the radius filter is off (`maxDistanceKm` null) or
  /// missing coordinates, every activity passes.
  bool _matchesDistance(Activity a, UserPreferences prefs) {
    if (a.homeOnly) return true;
    if (prefs.maxDistanceKm == null ||
        prefs.userLat == null ||
        prefs.userLng == null) {
      return true;
    }
    if (a.lat == null || a.lng == null) return true;
    final distance = haversineKm(
      prefs.userLat!,
      prefs.userLng!,
      a.lat!,
      a.lng!,
    );
    return distance <= prefs.maxDistanceKm!;
  }

  /// Boosts social/physicalActivity/weather-matching activities by
  /// duplicating them in the sampling pool, then draws up to 3 unique
  /// activities. Simplest mechanism that works for a catalog this small
  /// (see design.md); upgrade to real weighted sampling if the catalog
  /// grows significantly.
  ///
  /// [excludeIds] (previous spin's activities) are preferred against, but
  /// topped up from if the non-excluded pool can't fill all 3 slots — a
  /// repeat is better than fewer results (see "results are never empty").
  List<Activity> _weightedPick(
    List<Activity> pool, {
    WeatherResult? weather,
    Set<String> excludeIds = const {},
  }) {
    final weighted = <Activity>[];
    for (final a in pool) {
      var weight = 1;
      if (a.social) weight++;
      if (a.benefits.contains('physicalActivity')) weight++;
      // Advisory only — a mismatch never excludes, it just doesn't get the
      // extra weight a matching activity gets.
      if (weather != null && a.indoor == weather.isIndoorFavoring) weight++;
      weighted.addAll(List.filled(weight, a));
    }

    weighted.shuffle(_random);
    final picked = <Activity>[];
    for (final a in weighted) {
      if (picked.contains(a) || excludeIds.contains(a.id)) continue;
      picked.add(a);
      if (picked.length == 3) break;
    }
    if (picked.length < 3) {
      for (final a in weighted) {
        if (picked.contains(a)) continue;
        picked.add(a);
        if (picked.length == 3) break;
      }
    }
    return picked;
  }
}
