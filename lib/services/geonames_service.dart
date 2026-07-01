import 'dart:async';
import 'dart:convert';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GeoNamesService {
  static final GeoNamesService instance = GeoNamesService._();
  GeoNamesService._();

  Database? _db;
  
  // Placeholder username. In production, this should be moved to a config/env.
  static const String _geonamesUsername = 'kiblat_app'; 

  Future<void> initialize() async {
    if (_db != null) return;

    final dbPath = await getDatabasesPath();
    final path = join(dbPath, "geonames.db");

    _db = await openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE cities (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT,
            admin1 TEXT,
            country_code TEXT,
            lat REAL,
            lon REAL
          )
        ''');
        await db.execute('CREATE INDEX idx_lat_lon ON cities (lat, lon)');
      },
    );
  }

  /// Finds the nearest city/district in the local SQLite database.
  Future<String?> findNearestCity(double lat, double lon) async {
    try {
      if (_db == null) await initialize();

      // Simple Euclidean distance squared approximation for nearest neighbor.
      // We limit to results within a reasonable range (approx 50km) to avoid 
      // returning a city from across the world if the DB is sparse.
      final List<Map<String, dynamic>> results = await _db!.rawQuery('''
        SELECT name, admin1, country_code, lat, lon
        FROM cities 
        WHERE lat BETWEEN ? AND ? AND lon BETWEEN ? AND ?
        ORDER BY ((lat - ?) * (lat - ?) + (lon - ?) * (lon - ?)) ASC 
        LIMIT 1
      ''', [lat - 0.5, lat + 0.5, lon - 0.5, lon + 0.5, lat, lat, lon, lon]);

      if (results.isNotEmpty) {
        final r = results.first;
        return _formatLabel(r['name'], r['admin1'], r['country_code']);
      }
    } catch (e) {
      debugPrint('Offline geocode lookup error: $e');
    }
    return null;
  }

  /// Fetches place name from GeoNames API and caches it in SQLite.
  Future<String?> fetchFromApiAndCache(double lat, double lon) async {
    try {
      final url = Uri.parse(
        'https://secure.geonames.org/findNearbyPlaceNameJSON?lat=$lat&lng=$lon&username=$_geonamesUsername'
      );
      
      final response = await http.get(url).timeout(const Duration(seconds: 5));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['geonames'] != null && (data['geonames'] as List).isNotEmpty) {
          final place = data['geonames'][0];
          
          final String name = place['name'] ?? '';
          final String admin1 = place['adminName1'] ?? '';
          final String countryCode = place['countryCode'] ?? '';
          final double cityLat = double.tryParse(place['lat'].toString()) ?? lat;
          final double cityLon = double.tryParse(place['lng'].toString()) ?? lon;

          // Cache in SQLite
          await importCities([{
            'name': name,
            'admin1': admin1,
            'country_code': countryCode,
            'lat': cityLat,
            'lon': cityLon,
          }]);

          return _formatLabel(name, admin1, countryCode);
        }
      }
    } catch (e) {
      debugPrint('GeoNames API error: $e');
    }
    return null;
  }

  String _formatLabel(String name, String? admin1, String? countryCode) {
    final List<String> parts = [name];
    if (admin1 != null && admin1.isNotEmpty && admin1 != name) parts.add(admin1);
    if (countryCode != null && countryCode.isNotEmpty) parts.add(countryCode);
    return parts.join(', ');
  }

  Future<void> importCities(List<Map<String, dynamic>> cities) async {
    if (_db == null) await initialize();
    
    await _db!.transaction((txn) async {
      final batch = txn.batch();
      for (var city in cities) {
        // Check if city already exists roughly at the same location to avoid duplicates
        batch.insert('cities', city, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
      await batch.commit(noResult: true);
    });
  }
}
