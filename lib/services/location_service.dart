import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart' as google_geocoding;
import 'package:geolocator/geolocator.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'telemetry_service.dart';
import 'geonames_service.dart';

class LocationService {
  static Future<bool> checkAndRequestPermission() async {
    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }

  static Future<bool> isPermissionGranted() async {
    final permission = await Geolocator.checkPermission();
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

    // 1. Try to get last known position first (fast)
    final lastKnown = await Geolocator.getLastKnownPosition();
    if (lastKnown != null) {
      // Return last known immediately if it's fresh (less than 1 minute old)
      final age = DateTime.now().difference(lastKnown.timestamp);
      if (age.inMinutes < 1) {
        return lastKnown;
      }
    }

    // 2. Request current position with a timeout
    try {
      return await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium, // Best can hang on some devices
          timeLimit: Duration(seconds: 10),
        ),
      );
    } catch (e) {
      // 3. Fallback to last known if request timed out
      if (lastKnown != null) return lastKnown;
      rethrow;
    }
  }

  static Future<String> reverseGeocode(double lat, double lon) async {
    // 1. Try Offline GeoNames SQLite first
    try {
      final offlineLabel = await GeoNamesService.instance.findNearestCity(lat, lon);
      if (offlineLabel != null && offlineLabel.isNotEmpty) {
        return offlineLabel;
      }
    } catch (e) {
      debugPrint('Offline geocode lookup failed: $e');
    }

    // 2. If offline fails (no data), try GeoNames API and cache result
    try {
      final apiLabel = await GeoNamesService.instance.fetchFromApiAndCache(lat, lon);
      if (apiLabel != null && apiLabel.isNotEmpty) {
        return apiLabel;
      }
    } catch (e) {
      debugPrint('GeoNames API geocode failed: $e');
    }

    // 3. Last fallback: Google/Apple Geocoding (original method)
    try {
      final places = await google_geocoding.placemarkFromCoordinates(lat, lon);
      if (places.isNotEmpty) {
        final p = places.first;
        return '${p.locality ?? ''}${p.locality != null && p.country != null ? ', ' : ''}${p.country ?? ''}';
      }
    } catch (_) {}

    return '';
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

  /// Persist last successful location label and coordinates for offline fallback
  static Future<void> saveLastLocation(
    String label,
    double lat,
    double lon,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_loc_label', label);
      await prefs.setDouble('last_loc_lat', lat);
      await prefs.setDouble('last_loc_lon', lon);
    } catch (e) {
      TelemetryService.instance.logEvent('save_last_location_error', {
        'error': e.toString(),
      });
    }
  }

  /// Returns a cached last location as a map {label, lat, lon} or null if none
  static Future<Map<String, dynamic>?> getLastLocation() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final label = prefs.getString('last_loc_label');
      final lat = prefs.getDouble('last_loc_lat');
      final lon = prefs.getDouble('last_loc_lon');
      if (label != null && lat != null && lon != null) {
        return {'label': label, 'lat': lat, 'lon': lon};
      }
    } catch (e) {
      TelemetryService.instance.logEvent('get_last_location_error', {
        'error': e.toString(),
      });
    }
    return null;
  }

  /// Save location for a specific prayer log (Pro Feature)
  static Future<void> savePrayerLocation(
    String dateKey,
    String prayerKey,
    double lat,
    double lon,
    String label,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'prayer_loc_${dateKey}_$prayerKey';
      await prefs.setString(key, '$label|$lat|$lon');
    } catch (_) {}
  }

  /// Get location for a specific prayer log
  static Future<Map<String, String>?> getPrayerLocation(
    String dateKey,
    String prayerKey,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'prayer_loc_${dateKey}_$prayerKey';
      final val = prefs.getString(key);
      if (val != null) {
        final parts = val.split('|');
        if (parts.length == 3) {
          return {'label': parts[0], 'lat': parts[1], 'lon': parts[2]};
        }
      }
    } catch (_) {}
    return null;
  }

  /// Attempt reverse geocoding with a timeout, save successful result to cache,
  /// and fall back to cached value if network/geocoding fails.
  static Future<String> reverseGeocodeWithCache(
    double lat,
    double lon, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    try {
      final label = await reverseGeocode(lat, lon).timeout(timeout);
      if (label.isNotEmpty) {
        await saveLastLocation(label, lat, lon);
        return label;
      }
      TelemetryService.instance.logEvent('reverse_geocode_empty');
    } catch (e) {
      TelemetryService.instance.logEvent('reverse_geocode_failed', {
        'error': e.toString(),
      });
    }

    final cached = await getLastLocation();
    if (cached != null) {
      TelemetryService.instance.logEvent('reverse_geocode_used_cache', {
        'cached_label': cached['label'],
      });
      return cached['label'];
    }

    return '';
  }

  /// Whether the device provides compass readings through flutter_compass.
  static bool hasCompass() {
    return FlutterCompass.events != null;
  }

  /// Checks if heading data is "stale" (hasn't changed despite accelerometer movement).
  /// This is a heuristic. Returns true if we suspect the sensor is stuck.
  static bool isCompassStale(double lastHeading, double newHeading, double movementMagnitude) {
    // If heading hasn't changed at all but device is moving significantly
    if (lastHeading == newHeading && movementMagnitude > 0.5) {
      return true;
    }
    return false;
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
