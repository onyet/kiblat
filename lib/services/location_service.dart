import 'dart:async';

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

class LocationService {
  static Future<bool> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  static Future<Position> getCurrentPosition() async {
    bool ok = await Geolocator.isLocationServiceEnabled();
    if (!ok) {
      throw Exception('Location services are disabled.');
    }
    final granted = await checkAndRequestPermission();
    if (!granted) throw Exception('Location permission not granted');
    return await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.best);
  }

  static Future<String> reverseGeocode(double lat, double lon) async {
    try {
      final places = await placemarkFromCoordinates(lat, lon);
      if (places.isNotEmpty) {
        final p = places.first;
        return '${p.locality ?? ''}${p.locality != null && p.country != null ? ', ' : ''}${p.country ?? ''}';
      }
      return '';
    } catch (_) {
      return '';
    }
  }

  static Stream<double?> headingStream() {
    final events = FlutterCompass.events;
    if (events == null) return Stream<double?>.empty();
    return events.map<double?>((CompassEvent e) => e.heading);
  }
}
