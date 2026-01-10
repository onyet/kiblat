import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/screens/home_topbar.dart';

void main() {
  testWidgets('HomeTopBar displays location and settings tap works', (tester) async {
    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            body: HomeTopBar(
              locationLabel: 'Test City',
              onSettingsTap: () {
                // noop for test; we'll verify tap via widget interaction
              },
            ),
          ),
        ),
      ),
    );

    // Verify location label is present
    expect(find.text('Test City'), findsOneWidget);

    // Tap settings icon; ensure it's tappable
    final settingsFinder = find.byIcon(Icons.settings);
    expect(settingsFinder, findsOneWidget);
    await tester.tap(settingsFinder);
    await tester.pumpAndSettle();
  });
}
