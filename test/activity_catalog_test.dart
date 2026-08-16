import 'package:flutter_test/flutter_test.dart';

import 'package:gorabra/models/activity_catalog.dart';

/// QA check for the curated dataset itself (not a user-facing feature —
/// see grill-me decision: no dedicated "unfiltered" screen state, just
/// verify the bundled catalog loads fully and cleanly).
void main() {
  testWidgets(
    'Activity catalog loads every entry with a unique, non-empty id',
    (tester) async {
      final activities = await ActivityCatalog.load();

      expect(activities, isNotEmpty);
      final ids = activities.map((a) => a.id).toList();
      expect(
        ids.toSet().length,
        ids.length,
        reason: 'duplicate activity id found',
      );
      expect(ids.every((id) => id.trim().isNotEmpty), isTrue);
    },
  );
}
