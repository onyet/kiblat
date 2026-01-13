import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/screens/home_prayer_sheet.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    // Provide mock prefs to satisfy EasyLocalization's use of SharedPreferences
    SharedPreferences.setMockInitialValues({});
    await EasyLocalization.ensureInitialized();
  });

  testWidgets('auto-collapse after duration', (WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: HomePrayerSheet(
              prayerKey: 'maghrib',
              prayerTime: '18:00',
              countdownDur: '5m',
              startExpanded: true,
              autoCollapseDuration: const Duration(seconds: 2),
            ),
          ),
        ),
      ),
    );

    // Verify expanded content exists (look for calendar icon in button)
    expect(find.byIcon(Icons.calendar_today), findsOneWidget);

    // Wait longer than collapse duration
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();

    // Now collapsed view should be present (expand_more icon is visible)
    expect(find.byIcon(Icons.expand_more), findsOneWidget);
  });

  testWidgets('pulse appears when imminent and collapsed', (WidgetTester tester) async {
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        fallbackLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: HomePrayerSheet(
              prayerKey: 'maghrib',
              prayerTime: '18:00',
              countdownDur: '5m',
              isImminent: true,
              startExpanded: false,
            ),
          ),
        ),
      ),
    );

    // Pulse wrapper key should exist
    expect(find.byKey(const ValueKey('pulse_wrap')), findsOneWidget);
  });
}
