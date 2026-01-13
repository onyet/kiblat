import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:adhan/adhan.dart';
import 'package:kiblat/services/prayer_service.dart';
import 'package:kiblat/models/prayer_settings_model.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  test('calculatePrayerTimes handles high-latitude rules without throwing', () async {
    // Svalbard (Longyearbyen) - high latitude where sun behavior is extreme
    const lat = 78.2232;
    const lon = 15.6469;
    final date = DateTime.utc(2026, 6, 21); // Summer solstice

    for (final rule in [
      HighLatitudeRule.middle_of_the_night,
      HighLatitudeRule.seventh_of_the_night,
      HighLatitudeRule.twilight_angle,
    ]) {
      final settings = PrayerSettings(highLatitudeRule: rule, timezoneId: 'UTC');
      final res = await PrayerService.calculatePrayerTimes(
        latitude: lat,
        longitude: lon,
        date: date,
        settings: settings,
      );

      // Basic sanity: we should have fajr, dhuhr, maghrib, isha present and ordered
      final names = res.prayers.map((p) => p.name.toLowerCase()).toList();
      expect(names.contains('fajr'), true);
      expect(names.contains('dhuhr'), true);
      expect(names.contains('maghrib'), true);
      expect(names.contains('isha'), true);

      final fajr = res.prayers.firstWhere((p) => p.name.toLowerCase() == 'fajr');
      final dhuhr = res.prayers.firstWhere((p) => p.name.toLowerCase() == 'dhuhr');
      final maghrib = res.prayers.firstWhere((p) => p.name.toLowerCase() == 'maghrib');
      final isha = res.prayers.firstWhere((p) => p.name.toLowerCase() == 'isha');

      expect(fajr.time.isBefore(dhuhr.time) || fajr.time.isAtSameMomentAs(dhuhr.time), true);
      expect(maghrib.time.isBefore(isha.time) || maghrib.time.isAtSameMomentAs(isha.time), true);
    }
  });

  test('calculatePrayerTimes falls back gracefully on invalid timezone', () async {
    final settings = PrayerSettings(timezoneId: 'Invalid/Timezone');
    final res = await PrayerService.calculatePrayerTimes(
      latitude: 0.0,
      longitude: 0.0,
      date: DateTime.utc(2026, 1, 12),
      settings: settings,
    );

    expect(res.prayers.isNotEmpty, true);
  });
}
