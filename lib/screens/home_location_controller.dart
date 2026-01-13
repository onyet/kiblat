import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/telemetry_service.dart';

class LocationResult {
  final double qiblaDeg;
  final double distanceKm;
  final String label;
  final double lat;
  final double lon;
  final bool fromCache;

  LocationResult({
    required this.qiblaDeg,
    required this.distanceKm,
    required this.label,
    required this.lat,
    required this.lon,
    required this.fromCache,
  });
}

typedef PositionFetcher = Future<Position> Function();
typedef ReverseGeocodeFetcher = Future<String> Function(double lat, double lon);

class HomeLocationController {
  final PositionFetcher _fetchPos;
  final ReverseGeocodeFetcher _reverseGeo;

  HomeLocationController({
    PositionFetcher? fetchPos,
    ReverseGeocodeFetcher? reverseGeo,
  }) : _fetchPos = fetchPos ?? LocationService.getCurrentPosition,
       _reverseGeo = reverseGeo ?? LocationService.reverseGeocodeWithCache;

  /// Fetch current position and return computed LocationResult. If reverse geocode
  /// returns empty label, the label will be empty and caller should handle fallbacks.
  Future<LocationResult> fetchLocation() async {
    final pos = await _fetchPos();
    final label = await _reverseGeo(pos.latitude, pos.longitude);
    final qibla = LocationService.qiblaBearing(pos.latitude, pos.longitude);
    final dist = LocationService.distanceToKaabaKm(pos.latitude, pos.longitude);
    final cached = label.contains('(cached)');
    return LocationResult(
      qiblaDeg: qibla,
      distanceKm: dist,
      label: label,
      lat: pos.latitude,
      lon: pos.longitude,
      fromCache: cached,
    );
  }

  Future<void> saveManualCoordinates(
    String label,
    double lat,
    double lon,
  ) async {
    await LocationService.saveLastLocation(label, lat, lon);
    TelemetryService.instance.logEvent('manual_coords_saved', {
      'lat': lat,
      'lon': lon,
    });
  }
}
