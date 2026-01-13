import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/widgets/sunnah_compact.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;


void main() {
  testWidgets('SunnahCompact shows chips and expands on tap', (tester) async {
    final now = DateTime.now();
    final dhuha = ps.PrayerTime(
      name: 'Dhuha',
      arabicName: 'الضحى',
      time: now.add(const Duration(hours: 4)),
      timeString: '11:00 AM',
      subtitle: 'MORNING PRAYER',
      isSunnah: true,
    );

    final tahajjud = ps.PrayerTime(
      name: 'Tahajjud',
      arabicName: 'التهجد',
      time: now.subtract(const Duration(hours: 2)),
      timeString: '01:00 AM',
      subtitle: 'NIGHT PRAYER',
      isSunnah: true,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SunnahCompact(sunnahList: [dhuha, tahajjud], activePrayer: null),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Chips are visible
    expect(find.text('Dhuha'), findsOneWidget);
    expect(find.text('Tahajjud'), findsOneWidget);

    // Expanded content not visible initially
    expect(find.text('MORNING PRAYER'), findsNothing);

    // Tap the chip to expand (choose the chip, not the expanded card)
    await tester.tap(find.text('Dhuha').at(0));
    await tester.pumpAndSettle();

    // Now the expanded section should be visible
    expect(find.text('MORNING PRAYER'), findsOneWidget);

    // Label should change (chevron rotation label toggled)
    expect(find.textContaining('View Sunnah'), findsNothing);
    // Either translation or key may be present depending on test environment
    final foundFull = find.textContaining('VIEW FULL SCHEDULE');
    final foundFullKey = find.textContaining('view_full_schedule');
    // Accept either translated label or the translation key (depends on test env)
    expect(tester.any(foundFull) || tester.any(foundFullKey), isTrue);

    // Tap again to collapse (tap the chip again, index 0)
    await tester.tap(find.text('Dhuha').at(0));
    await tester.pumpAndSettle();
    expect(find.text('MORNING PRAYER'), findsNothing);
  });
}