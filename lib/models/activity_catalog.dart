import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import 'activity.dart';

/// Loads the bundled Gothenburg activity dataset. No network call — all
/// data ships in the app bundle (see activity-catalog spec).
class ActivityCatalog {
  static Future<List<Activity>> load() async {
    final raw = await rootBundle.loadString('assets/data/activities.json');
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
