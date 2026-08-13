import 'package:flutter_test/flutter_test.dart';
import 'package:gorabra/screens/planner_screen.dart';

void main() {
  group('isOpenNow', () {
    test('within a strict HH:MM–HH:MM range returns true', () {
      final now = DateTime(2026, 1, 1, 12, 0);
      expect(isOpenNow('10:00–17:00', now: now), isTrue);
    });

    test('outside a strict HH:MM–HH:MM range returns false', () {
      final now = DateTime(2026, 1, 1, 20, 0);
      expect(isOpenNow('10:00–17:00', now: now), isFalse);
    });

    test('at the closing minute returns false (exclusive close)', () {
      final now = DateTime(2026, 1, 1, 17, 0);
      expect(isOpenNow('10:00–17:00', now: now), isFalse);
    });

    test('free text (unparseable) returns null', () {
      expect(isOpenNow('Se jumpy.se för aktuella tider'), isNull);
    });

    test('range with a trailing qualifier returns null, not a guess', () {
      expect(isOpenNow('10:00–17:00 (vardagar)'), isNull);
    });

    test('"Alltid öppet" returns null (not parsed as a time range)', () {
      expect(isOpenNow('Alltid öppet'), isNull);
    });

    test('overnight range (close <= open) returns null, not a guess', () {
      expect(isOpenNow('22:00–02:00', now: DateTime(2026, 1, 1, 23, 0)), isNull);
    });

    test('invalid hour/minute values are rejected, not silently parsed', () {
      expect(isOpenNow('99:99–10:00'), isNull);
      expect(isOpenNow('10:00–24:00'), isNull);
    });
  });
}
