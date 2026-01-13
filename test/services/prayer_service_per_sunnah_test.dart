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
}
