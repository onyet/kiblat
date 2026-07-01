import 'dart:async';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';

class GeoNamesService {
  static final GeoNamesService instance = GeoNamesService._();
  GeoNamesService._();

  Database? _db;

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
            id INTEGER PRIMARY KEY,
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
  /// This is an offline-first replacement for Google Geocoding.
  Future<String?> findNearestCity(double lat, double lon) async {
    try {
      if (_db == null) await initialize();

      // Simple Euclidean distance squared approximation for nearest neighbor.
      // Sufficient for city-level accuracy.
      final List<Map<String, dynamic>> results = await _db!.rawQuery('''
        SELECT name, admin1, country_code 
        FROM cities 
        ORDER BY ((lat - ?) * (lat - ?) + (lon - ?) * (lon - ?)) ASC 
        LIMIT 1
      ''', [lat, lat, lon, lon]);

      if (results.isNotEmpty) {
        final r = results.first;
        final name = r['name'] as String;
        final admin = r['admin1'] as String?;
        final country = r['country_code'] as String?;

        final List<String> parts = [name];
        if (admin != null && admin.isNotEmpty) parts.add(admin);
        if (country != null && country.isNotEmpty) parts.add(country);

        return parts.join(', ');
      }
    } catch (e) {
      debugPrint('GeoNames lookup error: $e');
    }
    return null;
  }

  /// Populate the database from a list of cities. 
  /// In a real scenario, this would import from a bundled asset or a one-time download.
  Future<void> importCities(List<Map<String, dynamic>> cities) async {
    if (_db == null) await initialize();
    
    await _db!.transaction((txn) async {
      final batch = txn.batch();
      for (var city in cities) {
        batch.insert('cities', city, conflictAlgorithm: ConflictAlgorithm.replace);
      }
      await batch.commit(noResult: true);
    });
  }
  
  Future<bool> hasData() async {
    if (_db == null) await initialize();
    final count = Sqflite.firstIntValue(await _db!.rawQuery('SELECT COUNT(*) FROM cities'));
    return count != null && count > 0;
  }
}
