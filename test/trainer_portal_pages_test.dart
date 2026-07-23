import 'package:flutter_test/flutter_test.dart';
import 'package:pocketbase/pocketbase.dart';
import 'package:tc_moeckmuehl/tabs/trainer_portal_pages.dart';

void main() {
  group('parseShareValue', () {
    test('interprets percentages correctly', () {
      expect(parseShareValue('50'), 0.5);
      expect(parseShareValue('50%'), 0.5);
      expect(parseShareValue('0,5'), 0.5);
      expect(parseShareValue('1'), 1.0);
      expect(parseShareValue('0.25'), 0.25);
    });
  });

  group('buildAutoShareText', () {
    test('computes equal shares for the current player count', () {
      expect(buildAutoShareText(0), '0%');
      expect(buildAutoShareText(1), '100%');
      expect(buildAutoShareText(2), '50%');
      expect(buildAutoShareText(3), '33%');
    });
  });

  group('buildManualTemplateDefaults', () {
    test('prefills values from a group template', () {
      final group = RecordModel({
        'id': 'group-1',
        'collectionId': '1',
        'collectionName': 'trainer_groups',
        'name': 'Testgruppe',
        'duration': 1.5,
        'cost': 90.0,
        'cost_center': 15,
      });

      final defaults = buildManualTemplateDefaults(group, true);

      expect(defaults['service'], 'Testgruppe');
      expect(defaults['duration'], '1.5');
      expect(defaults['cost'], '90.0');
      expect(defaults['hallCost'], '15');
    });
  });

  group('formatDateTimeInput', () {
    test('formats date and time for the attendance form', () {
      final value = DateTime(2024, 1, 2, 3, 4);
      expect(formatDateForInput(value), '02.01.2024');
      expect(formatTimeForInput(value), '03:04');
    });
  });

  group('buildTrainingSuggestions', () {
    test('uses the latest interval occurrence when state is older', () {
      final startDate = DateTime(2024, 1, 1);
      final now = DateTime(2024, 1, 20);
      final stateDate = DateTime(2024, 1, 10);
      final group = RecordModel({
        'id': 'group-1',
        'collectionId': '1',
        'collectionName': 'trainer_groups',
        'name': 'Testgruppe',
        'start': startDate.toIso8601String(),
        'interval': 'weekly',
        'member': <String>[],
        'state': stateDate.toIso8601String(),
      });

      final suggestions = buildTrainingSuggestions(
        [group],
        fallbackParticipants: const [],
        horizonDays: 30,
        now: now,
      );

      expect(suggestions, hasLength(1));
      expect(suggestions.single.startAt, DateTime(2024, 1, 15));
    });
  });
}
