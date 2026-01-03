import 'dart:async';
import 'dart:math' as math;

import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';

class LocationService {
  static Future<bool> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<Position> getCurrentPosition() async {
    bool ok = await Geolocator.isLocationServiceEnabled();
    if (!ok) {
      throw Exception('Location services are disabled.');
    }
    final granted = await checkAndRequestPermission();
    if (!granted) throw Exception('Location permission not granted');
    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.best,
    );
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

  /// Calculate bearing (degrees from true north) from (lat, lon) to the Kaaba
  /// Uses great-circle navigation formula for initial bearing.
  static double qiblaBearing(double latDeg, double lonDeg) {
    const kaabaLat = 21.422487; // degrees
    const kaabaLon = 39.826206; // degrees
    final lat1 = _degToRad(latDeg);
    final lat2 = _degToRad(kaabaLat);
    final dLon = _degToRad(kaabaLon - lonDeg);

    final x = math.sin(dLon) * math.cos(lat2);
    final y =
        math.cos(lat1) * math.sin(lat2) -
        math.sin(lat1) * math.cos(lat2) * math.cos(dLon);
    var bearing = math.atan2(x, y) * (180 / math.pi);
    bearing = (bearing + 360) % 360;
    return bearing;
  }

  /// Returns distance in kilometers using the great-circle (spherical law of cosines) formula.
  /// This computes the central angle between two points on a sphere and multiplies by Earth's radius.
  static double distanceToKaabaKm(double latDeg, double lonDeg) {
    const kaabaLat = 21.422487;
    const kaabaLon = 39.826206;
    final lat1 = _degToRad(latDeg);
    final lat2 = _degToRad(kaabaLat);
    final dLon = _degToRad(kaabaLon - lonDeg);

    // spherical law of cosines: central_angle = acos(sinφ1 sinφ2 + cosφ1 cosφ2 cosΔλ)
    final cosCentral =
        (math.sin(lat1) * math.sin(lat2)) +
        (math.cos(lat1) * math.cos(lat2) * math.cos(dLon));
    // Clamp due to floating point errors
    final clamped = math.max(-1.0, math.min(1.0, cosCentral));
    final centralAngle = math.acos(clamped);
    const earthRadiusKm = 6371.0;
    return earthRadiusKm * centralAngle;
  }

  static double _degToRad(double deg) => deg * math.pi / 180.0;

  static Stream<double?> headingStream() {
    final events = FlutterCompass.events;
    if (events == null) return Stream<double?>.empty();
    return events.map<double?>((CompassEvent e) => e.heading);
  }

  /// Whether the device provides compass readings through flutter_compass.
  static bool hasCompass() {
    return FlutterCompass.events != null;
  }

  /// Open app settings to let user grant permissions
  static Future<bool> openAppSettings() async {
    return await Geolocator.openAppSettings();
  }

  /// Open location settings (device-level)
  static Future<bool> openLocationSettings() async {
    return await Geolocator.openLocationSettings();
  }
}
