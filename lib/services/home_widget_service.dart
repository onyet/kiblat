import 'dart:async';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/services/location_service.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/models/prayer_settings_model.dart';

/// Service to manage home screen widget data updates
/// 
/// Prinsip utama (dari WIDGET_HOME.md):
/// - Widget HARUS bisa dirender walau semua data NULL
/// - Selalu set default value
/// - Widget TIDAK BOLEH akses GPS/sensor/network langsung
/// - Gunakan cache sebagai sumber utama
class HomeWidgetService {
  static const String appGroupId = 'group.id.onyet.app.kiblat';
  static const String androidWidgetName = 'KiblatWidgetProvider';
  static const String iOSWidgetName = 'KiblatWidget';

  // Widget data keys
  static const String keyQiblaDegree = 'qibla_degree';
  static const String keyQiblaDirection = 'qibla_direction';
  static const String keyLocationName = 'location_name';
  static const String keyCurrentPrayer = 'current_prayer';
  static const String keyCurrentPrayerTime = 'current_prayer_time';
  static const String keyNextPrayer = 'next_prayer';
  static const String keyNextPrayerTime = 'next_prayer_time';
  static const String keyLastUpdated = 'last_updated';
  static const String keyLatitude = 'latitude';
  static const String keyLongitude = 'longitude';

  // Default values untuk fallback
  static const double defaultQiblaDegree = 0.0;
  static const String defaultDirection = 'N';
  static const String defaultLocation = 'Buka app untuk update';
  static const String defaultPrayer = '--';
  static const String defaultTime = '--:--';

  HomeWidgetService._();
  static final HomeWidgetService _instance = HomeWidgetService._();
  static HomeWidgetService get instance => _instance;

  Timer? _updateTimer;
  bool _initialized = false;

  /// Initialize widget service and register callbacks
  Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Set the app group ID for iOS (not used on Android but doesn't hurt)
      await HomeWidget.setAppGroupId(appGroupId);

      // PENTING: Inisialisasi data default terlebih dahulu
      // Ini memastikan widget tidak crash saat pertama kali ditambahkan
      await _initializeDefaultData();

      // Register background callback for widget interactions
      await HomeWidget.registerInteractivityCallback(backgroundCallback);

      // Initial widget update (non-blocking)
      _updateWidgetDataSafely();

      // Set up periodic updates (every 5 minutes)
      _updateTimer?.cancel();
      _updateTimer = Timer.periodic(const Duration(minutes: 5), (_) {
        _updateWidgetDataSafely();
      });
      
      _initialized = true;
    } catch (e) {
      // Silently fail - widget akan menampilkan data default
    }
  }

  /// Initialize default data untuk widget
  /// Dipanggil sebelum widget pertama kali dirender
  Future<void> _initializeDefaultData() async {
    try {
      // Cek apakah sudah ada data
      final existingDegree = await HomeWidget.getWidgetData<double>(keyQiblaDegree);
      
      // Jika belum ada data, set defaults
      if (existingDegree == null) {
        await Future.wait([
          HomeWidget.saveWidgetData<double>(keyQiblaDegree, defaultQiblaDegree),
          HomeWidget.saveWidgetData<String>(keyQiblaDirection, defaultDirection),
          HomeWidget.saveWidgetData<String>(keyLocationName, defaultLocation),
          HomeWidget.saveWidgetData<String>(keyCurrentPrayer, defaultPrayer),
          HomeWidget.saveWidgetData<String>(keyCurrentPrayerTime, defaultTime),
          HomeWidget.saveWidgetData<String>(keyNextPrayer, defaultPrayer),
          HomeWidget.saveWidgetData<String>(keyNextPrayerTime, defaultTime),
          HomeWidget.saveWidgetData<String>(keyLastUpdated, defaultTime),
          HomeWidget.saveWidgetData<double>(keyLatitude, 0.0),
          HomeWidget.saveWidgetData<double>(keyLongitude, 0.0),
        ]);
        
        // Request widget update dengan data default
        await _updateWidget();
      }
    } catch (e) {
      // Ignore - widget akan menggunakan defaults dari layout XML
    }
  }

  /// Dispose of timer
  void dispose() {
    _updateTimer?.cancel();
    _updateTimer = null;
    _initialized = false;
  }

  /// Background callback for widget interactions (e.g., refresh button tap)
  @pragma('vm:entry-point')
  static Future<void> backgroundCallback(Uri? uri) async {
    if (uri?.host == 'refresh') {
      await HomeWidgetService.instance._updateWidgetDataSafely();
    }
  }

  /// Update widget data safely (dengan try-catch)
  Future<void> _updateWidgetDataSafely() async {
    try {
      await updateWidgetData();
    } catch (e) {
      // Silently fail - widget akan menampilkan data cached atau default
    }
  }

  /// Update all widget data from current location and prayer times
  Future<void> updateWidgetData() async {
    try {
      // Get last known location from preferences
      final prefs = await SharedPreferences.getInstance();
      double? lat = prefs.getDouble('last_loc_lat');
      double? lon = prefs.getDouble('last_loc_lon');
      String locationName = prefs.getString('last_loc_label') ?? 'Unknown';

      // Try to get current position if no cached location
      if (lat == null || lon == null) {
        try {
          final position = await LocationService.getCurrentPosition();
          lat = position.latitude;
          lon = position.longitude;
          locationName = await LocationService.reverseGeocode(lat, lon);
          if (locationName.isEmpty) {
            locationName = '${lat.toStringAsFixed(2)}, ${lon.toStringAsFixed(2)}';
          }
        } catch (e) {
          // Use default values if location unavailable
          lat = 0.0;
          lon = 0.0;
          locationName = 'Location unavailable';
        }
      }

      // Calculate Qibla bearing
      final qiblaDeg = LocationService.qiblaBearing(lat, lon);
      final qiblaDirection = _getCardinalDirection(qiblaDeg);

      // Get prayer times
      final settings = await PrayerSettings.load();
      final now = DateTime.now();
      final dailyPrayers = await ps.PrayerService.calculatePrayerTimes(
        latitude: lat,
        longitude: lon,
        date: now,
        settings: settings,
      );

      // Find current and next prayer
      String currentPrayer = '';
      String currentPrayerTime = '';
      String nextPrayer = '';
      String nextPrayerTime = '';

      // Get only fard prayers (exclude sunnah)
      final fardPrayers = dailyPrayers.prayers.where((p) => !p.isSunnah).toList();
      
      // Find current active prayer (most recent past prayer)
      ps.PrayerTime? current;
      ps.PrayerTime? next;
      
      for (int i = fardPrayers.length - 1; i >= 0; i--) {
        if (fardPrayers[i].time.isBefore(now)) {
          current = fardPrayers[i];
          if (i + 1 < fardPrayers.length) {
            next = fardPrayers[i + 1];
          }
          break;
        }
      }

      // If no prayer has passed today, the current is the last from yesterday
      // and next is the first today
      if (current == null && fardPrayers.isNotEmpty) {
        next = fardPrayers.first;
        // For current, we'd need yesterday's Isha, but we'll just leave it empty
        currentPrayer = 'Isha';
        currentPrayerTime = '--:--';
      } else if (current != null) {
        currentPrayer = current.name;
        currentPrayerTime = current.timeString;
      }

      if (next != null) {
        nextPrayer = next.name;
        nextPrayerTime = next.timeString;
      } else {
        // Next prayer is Fajr tomorrow
        nextPrayer = 'Fajr';
        nextPrayerTime = fardPrayers.isNotEmpty ? fardPrayers.first.timeString : '--:--';
      }

      // Save data to widget storage
      await Future.wait([
        HomeWidget.saveWidgetData<double>(keyQiblaDegree, qiblaDeg),
        HomeWidget.saveWidgetData<String>(keyQiblaDirection, qiblaDirection),
        HomeWidget.saveWidgetData<String>(keyLocationName, locationName),
        HomeWidget.saveWidgetData<String>(keyCurrentPrayer, currentPrayer),
        HomeWidget.saveWidgetData<String>(keyCurrentPrayerTime, currentPrayerTime),
        HomeWidget.saveWidgetData<String>(keyNextPrayer, nextPrayer),
        HomeWidget.saveWidgetData<String>(keyNextPrayerTime, nextPrayerTime),
        HomeWidget.saveWidgetData<String>(keyLastUpdated, _formatTime(now)),
        HomeWidget.saveWidgetData<double>(keyLatitude, lat),
        HomeWidget.saveWidgetData<double>(keyLongitude, lon),
      ]);

      // Request widget update
      await _updateWidget();
    } catch (e) {
      // Silently fail - widget will show cached or default data
    }
  }

  /// Update specific prayer data (called when prayer times change)
  Future<void> updatePrayerData({
    required String currentPrayer,
    required String currentPrayerTime,
    required String nextPrayer,
    required String nextPrayerTime,
  }) async {
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(keyCurrentPrayer, currentPrayer.isNotEmpty ? currentPrayer : defaultPrayer),
        HomeWidget.saveWidgetData<String>(keyCurrentPrayerTime, currentPrayerTime.isNotEmpty ? currentPrayerTime : defaultTime),
        HomeWidget.saveWidgetData<String>(keyNextPrayer, nextPrayer.isNotEmpty ? nextPrayer : defaultPrayer),
        HomeWidget.saveWidgetData<String>(keyNextPrayerTime, nextPrayerTime.isNotEmpty ? nextPrayerTime : defaultTime),
        HomeWidget.saveWidgetData<String>(keyLastUpdated, _formatTime(DateTime.now())),
      ]);
      await _updateWidget();
    } catch (e) {
      // Silently fail
    }
  }

  /// Update qibla data (called when location changes)
  Future<void> updateQiblaData({
    required double qiblaDegree,
    required String locationName,
    required double latitude,
    required double longitude,
  }) async {
    try {
      final qiblaDirection = _getCardinalDirection(qiblaDegree);
      await Future.wait([
        HomeWidget.saveWidgetData<double>(keyQiblaDegree, qiblaDegree),
        HomeWidget.saveWidgetData<String>(keyQiblaDirection, qiblaDirection),
        HomeWidget.saveWidgetData<String>(keyLocationName, locationName.isNotEmpty ? locationName : defaultLocation),
        HomeWidget.saveWidgetData<double>(keyLatitude, latitude),
        HomeWidget.saveWidgetData<double>(keyLongitude, longitude),
        HomeWidget.saveWidgetData<String>(keyLastUpdated, _formatTime(DateTime.now())),
      ]);
      await _updateWidget();
    } catch (e) {
      // Silently fail
    }
  }

  /// Request native widget update
  Future<void> _updateWidget() async {
    try {
      await HomeWidget.updateWidget(
        name: androidWidgetName,
        androidName: androidWidgetName,
        iOSName: iOSWidgetName,
      );
    } catch (e) {
      // Widget might not exist yet
    }
  }

  /// Get cardinal direction from degrees
  String _getCardinalDirection(double degrees) {
    const directions = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((degrees + 22.5) % 360 / 45).floor();
    return directions[index];
  }

  /// Format time for display
  String _formatTime(DateTime time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }
}
