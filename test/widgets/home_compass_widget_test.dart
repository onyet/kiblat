import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/screens/home_compass_widget.dart';

void main() {
  testWidgets('HomeCompass shows loader when not ready and shows readout when ready', (tester) async {
    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(
            backgroundColor: Colors.black,
            body: HomeCompass(
              headingDeg: 0,
              qiblaDeg: 90,
              distanceKm: 1234.5,
              isLocationReady: false,
            ),
          ),
        ),
      ),
    );

    // Loader present
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Now pump with ready state
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        child: MaterialApp(
          home: Scaffold(
            body: HomeCompass(
              headingDeg: 0,
              qiblaDeg: 90,
              distanceKm: 1234.5,
              isLocationReady: true,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Degrees readout should be present (90° E)
    expect(find.textContaining('90'), findsOneWidget);
    // Distance formatted should be present
    expect(find.textContaining('1,234'), findsOneWidget);
  });
}
