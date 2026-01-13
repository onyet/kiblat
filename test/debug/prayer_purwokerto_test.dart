// ignore_for_file: avoid_print

import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/services/prayer_service.dart';
import 'package:kiblat/models/prayer_settings_model.dart';

void main() {
  test('purwokerto prayer times debug', () async {
    final lat = -7.434; // Purwokerto approx
    final lon = 109.246;

    final settings = PrayerSettings(timezoneId: 'Asia/Jakarta');

    final today = DateTime.now();
    final dt = await PrayerService.calculatePrayerTimes(
      latitude: lat,
      longitude: lon,
      date: DateTime(today.year, today.month, today.day),
      settings: settings,
    );

    final now = DateTime.now();

    print('Now local: $now');
    print('Prayers for ${dt.date}:');
    for (final p in dt.prayers) {
      print('  ${p.name}: ${p.time}  formatted=${p.timeString}  isSunnah=${p.isSunnah}');
    }

    final next = await PrayerService.getNextPrayerTime(latitude: lat, longitude: lon, settings: settings);
    final prev = await PrayerService.getPreviousPrayerTime(latitude: lat, longitude: lon, settings: settings);

    print('Prev: ${prev?.name} ${prev?.time}');
    print('Next: ${next?.name} ${next?.time}');

    expect(dt.prayers.isNotEmpty, true);
  });
}
