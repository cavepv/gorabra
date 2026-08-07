/// Cost tier for an activity. Order matters: index is used to compare
/// against a user's budget (e.g. `low.index <= budget.index`).
enum Cost { free, low, medium, high }

/// How an activity can be reached.
enum TransportMode { walk, bike, publicTransit, car }

Cost _costFromJson(String value) => Cost.values.byName(value);

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

  /// Parent interest tags — scoring boost only, never excludes.
  final List<String> parentInterest;

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

  /// Cost tier — hard filter vs. user's budget input.
  final Cost cost;

  /// Stay-at-home activity — hard filter vs. user's `stayHome` input,
  /// never relaxed (same tier as cost/transport). Defaults to false for
  /// existing "go somewhere" activities. See activity-recommender spec.
  final bool homeOnly;

  const Activity({
    required this.id,
    required this.name,
    required this.description,
    required this.minAge,
    required this.maxAge,
    required this.indoor,
    required this.interests,
    required this.parentInterest,
    required this.social,
    required this.benefits,
    required this.benefitNote,
    required this.openingHours,
    required this.location,
    required this.distanceKm,
    required this.transportModes,
    required this.cost,
    this.homeOnly = false,
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
      parentInterest: List<String>.from(json['parentInterest'] as List),
      social: json['social'] as bool,
      benefits: List<String>.from(json['benefits'] as List),
      benefitNote: json['benefitNote'] as String,
      openingHours: json['openingHours'] as String,
      location: json['location'] as String,
      distanceKm: (json['distanceKm'] as num).toDouble(),
      transportModes: (json['transportModes'] as List)
          .map((e) => _transportModeFromJson(e as String))
          .toList(),
      cost: _costFromJson(json['cost'] as String),
      homeOnly: json['homeOnly'] as bool? ?? false,
    );
  }
}
