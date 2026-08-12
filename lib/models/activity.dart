/// How an activity can be reached.
enum TransportMode { walk, bike, publicTransit, car }

TransportMode _transportModeFromJson(String value) =>
    TransportMode.values.byName(value);

/// A single curated activity suggestion.
///
/// Schema locked in openspec/changes/gorabra-activity-planner-mvp/design.md.
class Activity {
  final String id;
  final String name;
  final String description;
  final int minAge;
  final int maxAge;
  final bool indoor;

  /// Kid interest tags — hard filter, relaxed first if the pool is empty.
  final List<String> interests;

  /// Good for meeting other parents/kids — scoring boost only.
  final bool social;

  /// Evidence-based benefit tags, e.g. "physicalActivity", "motorSkills".
  /// Only "physicalActivity" affects scoring in v1; others are informational.
  final List<String> benefits;

  /// Short evidence-based "why this is good" blurb shown to the user.
  final String benefitNote;

  /// Manually maintained, static — no live places API.
  final String openingHours;

  /// Free-text location description (city is hardcoded to Gothenburg).
  final String location;

  /// Manually estimated distance from Gothenburg city center.
  final double distanceKm;

  /// How this activity can be reached — hard filter vs. user's hasCar input.
  final List<TransportMode> transportModes;

  /// Cost in SEK for the whole outing (flat, not scaled by party size) —
  /// hard filter vs. user's budget slider input. 0 means free.
  final int costSek;

  /// Stay-at-home activity — hard filter vs. user's `stayHome` input,
  /// never relaxed (same tier as cost/transport). Defaults to false for
  /// existing "go somewhere" activities. See activity-recommender spec.
  final bool homeOnly;

  /// Manually estimated coordinates, null for `homeOnly` activities (a
  /// stay-at-home activity has no fixed place to measure distance to).
  /// Used by the optional distance-radius filter — hard filter, never
  /// relaxed, and never applied to `homeOnly` activities.
  final double? lat;
  final double? lng;

  const Activity({
    required this.id,
    required this.name,
    required this.description,
    required this.minAge,
    required this.maxAge,
    required this.indoor,
    required this.interests,
    required this.social,
    required this.benefits,
    required this.benefitNote,
    required this.openingHours,
    required this.location,
    required this.distanceKm,
    required this.transportModes,
    required this.costSek,
    this.homeOnly = false,
    this.lat,
    this.lng,
  });

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      minAge: json['minAge'] as int,
      maxAge: json['maxAge'] as int,
      indoor: json['indoor'] as bool,
      interests: List<String>.from(json['interests'] as List),
      social: json['social'] as bool,
      benefits: List<String>.from(json['benefits'] as List),
      benefitNote: json['benefitNote'] as String,
      openingHours: json['openingHours'] as String,
      location: json['location'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      transportModes: (json['transportModes'] as List)
          .map((e) => _transportModeFromJson(e as String))
          .toList(),
      costSek: json['costSek'] as int,
      homeOnly: json['homeOnly'] as bool? ?? false,
      lat: (json['lat'] as num?)?.toDouble(),
      lng: (json['lng'] as num?)?.toDouble(),
    );
  }
}
