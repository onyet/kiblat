import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/screens/home_location_controller.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('fetchLocation returns expected LocationResult', () async {
    // stub fetchPos and reverseGeo
    Future<Position> fetchPos() async => Position(
      latitude: 10.0,
      longitude: 20.0,
      timestamp: DateTime.now(),
      accuracy: 1.0,
      altitude: 0.0,
      altitudeAccuracy: 0.0,
      heading: 0.0,
      headingAccuracy: 0.0,
      speed: 0.0,
      speedAccuracy: 0.0,
    );

    // reverse returns a label
    Future<String> reverseGeo(double lat, double lon) async => 'City, Country';

    final controller = HomeLocationController(fetchPos: fetchPos, reverseGeo: reverseGeo);

    final res = await controller.fetchLocation();

    expect(res.label, 'City, Country');
    expect(res.lat, 10.0);
    expect(res.lon, 20.0);
    expect(res.fromCache, false);
    expect(res.qiblaDeg, isA<double>());
    expect(res.distanceKm, isA<double>());
  });
}
