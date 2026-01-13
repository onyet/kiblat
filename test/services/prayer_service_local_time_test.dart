import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/services/prayer_service.dart';
import 'package:kiblat/models/prayer_settings_model.dart';

void main() {
  test('prayer times are local DateTimes (not UTC) for Asia/Jakarta', () async {
    final lat = -7.434;
    final lon = 109.246;
    final settings = PrayerSettings(timezoneId: 'Asia/Jakarta');

    final dt = await PrayerService.calculatePrayerTimes(
      latitude: lat,
      longitude: lon,
      date: DateTime.now(),
      settings: settings,
    );

    for (final p in dt.prayers) {
      // Ensure the DateTime returned does not carry UTC flag
      expect(p.time.isUtc, isFalse, reason: 'Prayer ${p.name} should be local DateTime');
    }
  });
}
