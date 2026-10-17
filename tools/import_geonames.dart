import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:path/path.dart' as p;

/// Creates a developer-only sample database. The app does not bundle this file;
/// its runtime database is a cache populated by successful lookups.
/// Run this with: dart tools/import_geonames.dart
void main() async {
  // Init sqflite for desktop
  sqfliteFfiInit();
  var databaseFactory = databaseFactoryFfi;

  final dbPath = p.join(Directory.current.path, 'assets', 'geonames.db');
  // ignore: avoid_print
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

  // ignore: avoid_print
  print('Populating sample data...');
  
  // Example hardcoded entry for testing
  await db.insert('cities', {
    'name': 'Jakarta',
    'admin1': 'Jakarta',
    'country_code': 'ID',
    'lat': -6.2088,
    'lon': 106.8456
  });

  // ignore: avoid_print
  print('Database created with sample data.');
  await db.close();
}
