import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/services/prayer_service.dart';

void main() {
  test('progressBetween calculates correct fraction', () {
    final start = DateTime.now();
    final end = start.add(const Duration(seconds: 100));
    final mid = start.add(const Duration(seconds: 25));

    final progress = PrayerService.progressBetween(start, end, mid);

    expect(progress, closeTo(0.25, 1e-6));
  });

  test('progressBetween clamps to 0 and 1', () {
    final start = DateTime.now();
    final end = start.add(const Duration(seconds: 10));
    final before = start.subtract(const Duration(seconds: 5));
    final after = end.add(const Duration(seconds: 20));

    expect(PrayerService.progressBetween(start, end, before), 0.0);
    expect(PrayerService.progressBetween(start, end, after), 1.0);
  });
}
