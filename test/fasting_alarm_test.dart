import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:deenmate_sdp2/services/notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({
      'fasting_alarm_dates': [
        '20260907', // Monday
        '20260910', // Thursday
      ],
    });
  });

  test('NotificationService parses and returns earliest upcoming fasting date', () async {
    final service = NotificationService.instance;
    final keys = await service.getFastingAlarmDateKeys();
    expect(keys, containsAll(['20260907', '20260910']));

    final earliest = await service.getEarliestUpcomingFastingDate();
    expect(earliest, isNotNull);
    // Earliest must be 2026-09-07 (Monday)
    expect(earliest!.year, equals(2026));
    expect(earliest.month, equals(9));
    expect(earliest.day, equals(7));
  });

  test('NotificationService advances to Thursday after Monday passes', () async {
    // When Monday has passed, only Thursday remains upcoming
    SharedPreferences.setMockInitialValues({
      'fasting_alarm_dates': [
        '20260901', // Passed date
        '20260910', // Upcoming Thursday
      ],
    });

    final service = NotificationService.instance;
    final earliest = await service.getEarliestUpcomingFastingDate();
    expect(earliest, isNotNull);
    expect(earliest!.day, equals(10));
  });
}
