import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:kiblat/services/prayer_service.dart';
import 'package:kiblat/models/prayer_settings_model.dart';

void main() {
  setUpAll(() {
    tzdata.initializeTimeZones();
  });

  test('calculatePrayerTimes respects per-sunnah toggles', () async {
    final baseSettings = PrayerSettings(timezoneId: 'UTC', showSunnahTimes: true);

    // Both enabled
    var settings = baseSettings.copyWith(showDhuha: true, showTahajjud: true);
    var res = await PrayerService.calculatePrayerTimes(latitude: 0.0, longitude: 0.0, date: DateTime.utc(2026,1,12), settings: settings);
    expect(res.prayers.any((p) => p.name == 'Dhuha'), isTrue);
    expect(res.prayers.any((p) => p.name == 'Tahajjud'), isTrue);

    // Dhuha disabled
    settings = baseSettings.copyWith(showDhuha: false, showTahajjud: true);
    res = await PrayerService.calculatePrayerTimes(latitude: 0.0, longitude: 0.0, date: DateTime.utc(2026,1,12), settings: settings);
    expect(res.prayers.any((p) => p.name == 'Dhuha'), isFalse);
    expect(res.prayers.any((p) => p.name == 'Tahajjud'), isTrue);

    // Tahajjud disabled
    settings = baseSettings.copyWith(showDhuha: true, showTahajjud: false);
    res = await PrayerService.calculatePrayerTimes(latitude: 0.0, longitude: 0.0, date: DateTime.utc(2026,1,12), settings: settings);
    expect(res.prayers.any((p) => p.name == 'Dhuha'), isTrue);
    expect(res.prayers.any((p) => p.name == 'Tahajjud'), isFalse);

    // Both disabled (but showSunnahTimes true) -> none
    settings = baseSettings.copyWith(showDhuha: false, showTahajjud: false);
    res = await PrayerService.calculatePrayerTimes(latitude: 0.0, longitude: 0.0, date: DateTime.utc(2026,1,12), settings: settings);
    expect(res.prayers.any((p) => p.name == 'Dhuha' || p.name == 'Tahajjud'), isFalse);
  });

  test('tahajjud time is between isha and next day fajr', () async {
    final settings = PrayerSettings(timezoneId: 'UTC', showSunnahTimes: true, showTahajjud: true);
    final res = await PrayerService.calculatePrayerTimes(latitude: 0.0, longitude: 0.0, date: DateTime.utc(2026,1,12), settings: settings);
    final tahajjud = res.prayers.firstWhere((p) => p.name == 'Tahajjud');
    final isha = res.prayers.firstWhere((p) => p.name == 'Isha');
    final fajr = res.prayers.firstWhere((p) => p.name == 'Fajr');
    var fajrNext = fajr.time;
    if (!fajrNext.isAfter(isha.time)) {
      fajrNext = fajrNext.add(const Duration(days: 1));
    }
    expect(tahajjud.time.isAfter(isha.time), isTrue);
    expect(tahajjud.time.isBefore(fajrNext), isTrue);
    // Ensure not around midday (safety check)
    expect(tahajjud.time.hour < 11 || tahajjud.time.hour > 13, isTrue);
  });
}
