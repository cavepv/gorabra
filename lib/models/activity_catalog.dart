import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;

import 'activity.dart';

/// Loads the bundled Gothenburg activity dataset. No network call — all
/// data ships in the app bundle (see activity-catalog spec).
class ActivityCatalog {
  static Future<List<Activity>> load() async {
    final data = await rootBundle.load('assets/data/activities.json');
    // Avoid loadString's isolate handoff for assets over 50 KB.
    final raw = utf8.decode(Uint8List.sublistView(data));
    final list = jsonDecode(raw) as List;
    return list
        .map((e) => Activity.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
