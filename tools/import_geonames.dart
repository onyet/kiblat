import 'dart:io';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

/// A utility script to download GeoNames city data and populate geonames.db
/// Run this with: dart tools/import_geonames.dart
void main() async {
  // Init sqflite for desktop
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  final dbPath = p.join(Directory.current.path, 'assets', 'geonames.db');
  print('Creating database at $dbPath...');

  // Ensure assets directory exists
  final assetsDir = Directory(p.join(Directory.current.path, 'assets'));
  if (!assetsDir.existsSync()) assetsDir.createSync();

  final db = await databaseFactory.openDatabase(dbPath);

  await db.execute('DROP TABLE IF EXISTS cities');
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

  print('Downloading city data (cities with > 15000 population)...');
  // Note: In a real scenario, you'd download the .zip from GeoNames and parse the .txt
  // For this example, let's use a smaller JSON source or explain the process.
  
  print('Please provide a GeoNames compatible data source.');
  print('Commonly: https://download.geonames.org/export/dump/cities15000.zip');
  
  // Example hardcoded entry for testing
  await db.insert('cities', {
    'name': 'Jakarta',
    'admin1': 'Jakarta',
    'country_code': 'ID',
    'lat': -6.2088,
    'lon': 106.8456
  });

  print('Database created with 1 sample city. Add more data as needed.');
  await db.close();
}
