import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:kiblat/services/prayer_service.dart';
import 'package:kiblat/models/prayer_settings_model.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  test('calculatePrayerTimes excludes sunnah when disabled', () async {
    final settings = PrayerSettings(showSunnahTimes: false, timezoneId: 'UTC');
    final res = await PrayerService.calculatePrayerTimes(
      latitude: 0.0,
      longitude: 0.0,
      date: DateTime.utc(2026, 1, 12),
      settings: settings,
    );

    final hasSunnah = res.prayers.any((p) => p.isSunnah);
    expect(hasSunnah, isFalse);
  });

  test('calculatePrayerTimes includes sunnah when enabled', () async {
    final settings = PrayerSettings(showSunnahTimes: true, timezoneId: 'UTC');
    final res = await PrayerService.calculatePrayerTimes(
      latitude: 0.0,
      longitude: 0.0,
      date: DateTime.utc(2026, 1, 12),
      settings: settings,
    );

    final hasSunnah = res.prayers.any((p) => p.isSunnah);
    expect(hasSunnah, isTrue);
  });
}
