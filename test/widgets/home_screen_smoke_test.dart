import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/screens/home_screen.dart';
import 'package:kiblat/screens/home_location_controller.dart';
import 'package:kiblat/screens/home_compass_controller.dart';

class FakeController extends HomeLocationController {
  @override
  Future<LocationResult> fetchLocation() async {
    return LocationResult(
      qiblaDeg: 42.0,
      distanceKm: 100.0,
      label: 'Fake City',
      lat: 1.0,
      lon: 2.0,
      fromCache: false,
    );
  }
}

void main() {
  testWidgets('HomeScreen shows location from injected controller', (tester) async {
    final fake = FakeController();
    final noCompass = CompassHeadingController(source: Stream<double?>.empty());

    await EasyLocalization.ensureInitialized();
    await tester.pumpWidget(
      EasyLocalization(
        supportedLocales: const [Locale('en')],
        path: 'assets/translations',
        startLocale: const Locale('en'),
        child: MaterialApp(
          home: Scaffold(body: HomeScreen(locationController: fake, compassController: noCompass, skipPermissionCheck: true)),
        ),
      ),
    );

    // Allow async flows to run (give reasonable timeout)
    await tester.pumpAndSettle(const Duration(seconds: 2));

    expect(find.text('Fake City'), findsOneWidget);
  });
}
