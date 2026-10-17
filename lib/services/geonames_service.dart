import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

/// Local cache of places previously resolved by a geocoder.
///
/// This is a cache, not a bundled global city database: it becomes useful
/// offline after the app has resolved places while online.
class GeoNamesService {
  static final GeoNamesService instance = GeoNamesService._();
  GeoNamesService._();

  static const String _geoNamesUsername = String.fromEnvironment(
    'GEONAMES_USERNAME',
  );
  static const double _maxCacheDistanceKm = 60;

  Database? _db;

  Future<void> initialize() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'geonames.db');
    _db = await openDatabase(
      path,
      version: 2,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            admin1 TEXT NOT NULL DEFAULT '',
            country_code TEXT NOT NULL DEFAULT '',
            lat REAL NOT NULL,
            lon REAL NOT NULL
          )
        ''');
        await db.execute('CREATE INDEX idx_lat_lon ON cities (lat, lon)');
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          // The old table may contain duplicates because its primary key was
          // auto-incremented. Keep the closest row for each exact place tuple.
          await db.execute('''
            DELETE FROM cities
            WHERE id NOT IN (
              SELECT MIN(id) FROM cities
              GROUP BY name, admin1, country_code, lat, lon
            )
          ''');
        }
      },
    );
  }

  /// Returns the closest cached place within roughly 60 km, if one exists.
  Future<String?> findNearestCity(double lat, double lon) async {
    if (!_isValidCoordinate(lat, lon)) return null;
    try {
      if (_db == null) await initialize();

      final latRadius = _maxCacheDistanceKm / 110.574;
      final cosine = math.cos(lat * math.pi / 180).abs();
      final lonRadius = cosine < 0.001
          ? 180.0
          : math.min(180.0, _maxCacheDistanceKm / (111.320 * cosine));
      final south = math.max(-90.0, lat - latRadius);
      final north = math.min(90.0, lat + latRadius);
      final west = lon - lonRadius;
      final east = lon + lonRadius;

      String longitudeFilter;
      List<Object?> arguments;
      if (west < -180) {
        longitudeFilter = '(lon >= ? OR lon <= ?)';
        arguments = [south, north, west + 360, east];
      } else if (east > 180) {
        longitudeFilter = '(lon >= ? OR lon <= ?)';
        arguments = [south, north, west, east - 360];
      } else {
        longitudeFilter = 'lon BETWEEN ? AND ?';
        arguments = [south, north, west, east];
      }

      final results = await _db!.rawQuery('''
        SELECT name, admin1, country_code, lat, lon
        FROM cities
        WHERE lat BETWEEN ? AND ? AND $longitudeFilter
        ''', arguments);

      Map<String, dynamic>? nearest;
      var nearestDistance = _maxCacheDistanceKm;
      for (final row in results) {
        final distance = _distanceKm(
          lat,
          lon,
          (row['lat'] as num).toDouble(),
          (row['lon'] as num).toDouble(),
        );
        if (distance <= nearestDistance) {
          nearest = row;
          nearestDistance = distance;
        }
      }

      if (nearest == null) return null;
      return _formatLabel(
        (nearest['name'] ?? '').toString(),
        nearest['admin1']?.toString(),
        nearest['country_code']?.toString(),
      );
    } catch (e) {
      debugPrint('Local geocoder cache lookup failed: $e');
      return null;
    }
  }

  /// Looks up a label through GeoNames when configured, then caches the result.
  Future<String?> fetchFromApiAndCache(double lat, double lon) async {
    if (!_isValidCoordinate(lat, lon) || _geoNamesUsername.isEmpty) return null;

    try {
      final uri = Uri.https('secure.geonames.org', '/findNearbyPlaceNameJSON', {
        'lat': '$lat',
        'lng': '$lon',
        'username': _geoNamesUsername,
      });
      final response = await http.get(uri).timeout(const Duration(seconds: 5));
      if (response.statusCode != 200) {
        debugPrint('GeoNames lookup returned HTTP ${response.statusCode}');
        return null;
      }

      final decoded = json.decode(response.body);
      if (decoded is! Map<String, dynamic> || decoded['geonames'] is! List) {
        return null;
      }
      final places = decoded['geonames'] as List;
      if (places.isEmpty || places.first is! Map<String, dynamic>) return null;

      final place = places.first as Map<String, dynamic>;
      final name = place['name']?.toString().trim() ?? '';
      if (name.isEmpty) return null;
      final admin1 = place['adminName1']?.toString() ?? '';
      final countryCode = place['countryCode']?.toString() ?? '';
      final cityLat = double.tryParse(place['lat']?.toString() ?? '') ?? lat;
      final cityLon = double.tryParse(place['lng']?.toString() ?? '') ?? lon;

      if (!_isValidCoordinate(cityLat, cityLon)) return null;
      await importCities([
        {
          'name': name,
          'admin1': admin1,
          'country_code': countryCode,
          'lat': cityLat,
          'lon': cityLon,
        },
      ]);
      return _formatLabel(name, admin1, countryCode);
    } catch (e) {
      debugPrint('GeoNames lookup failed: $e');
      return null;
    }
  }

  static bool _isValidCoordinate(double lat, double lon) =>
      lat.isFinite &&
      lon.isFinite &&
      lat >= -90 &&
      lat <= 90 &&
      lon >= -180 &&
      lon <= 180;

  static double _distanceKm(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadiusKm = 6371.0088;
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final boundedA = a.clamp(0.0, 1.0);
    return earthRadiusKm *
        2 *
        math.atan2(math.sqrt(boundedA), math.sqrt(1 - boundedA));
  }

  static String _formatLabel(String name, String? admin1, String? countryCode) {
    final parts = <String>[];
    if (name.isNotEmpty) parts.add(name);
    if (admin1 != null && admin1.isNotEmpty && admin1 != name) {
      parts.add(admin1);
    }
    if (countryCode != null && countryCode.isNotEmpty) parts.add(countryCode);
    return parts.join(', ');
  }

  Future<void> importCities(List<Map<String, dynamic>> cities) async {
    if (_db == null) await initialize();

    await _db!.transaction((txn) async {
      for (final city in cities) {
        final name = city['name']?.toString().trim() ?? '';
        final admin1 = city['admin1']?.toString() ?? '';
        final countryCode = city['country_code']?.toString() ?? '';
        final lat = (city['lat'] as num?)?.toDouble();
        final lon = (city['lon'] as num?)?.toDouble();
        if (name.isEmpty ||
            lat == null ||
            lon == null ||
            !_isValidCoordinate(lat, lon)) {
          continue;
        }

        final nearby = await txn.query(
          'cities',
          columns: ['id'],
          where: '''
            name = ? AND admin1 = ? AND country_code = ?
            AND lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
          ''',
          whereArgs: [
            name,
            admin1,
            countryCode,
            lat - 0.001,
            lat + 0.001,
            lon - 0.001,
            lon + 0.001,
          ],
          limit: 1,
        );
        if (nearby.isEmpty) {
          await txn.insert('cities', {
            'name': name,
            'admin1': admin1,
            'country_code': countryCode,
            'lat': lat,
            'lon': lon,
          });
        }
      }
    });
  }
}
