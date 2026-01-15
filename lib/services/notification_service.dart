import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/services/location_service.dart';
import 'package:easy_localization/easy_localization.dart';

/// Manages local notifications for prayer times.
///
/// Schedules daily notifications for Fajr, Dhuhr, Asr, Maghrib, Isha and
/// keeps them in sync with user settings (including language changes).
class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  late final AndroidNotificationChannel _channel;
  bool _initialized = false;

  GlobalKey<NavigatorState>? _navigatorKey;

  /// Initialize plugin and create channel. Call once during app startup and
  /// provide a [navigatorKey] so we can safely get a context when needed.
  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;
    _navigatorKey = navigatorKey;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) async {
        // Optionally handle opening specific screen when tapping the notification
      },
    );

    _channel = const AndroidNotificationChannel(
      'prayer_times',
      'Prayer times',
      description: 'Notifications for prayer times',
      importance: Importance.high,
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // Listen for settings changes to reschedule notifications with new locale/time
    SettingsService.instance.notifier.addListener(() async {
      final s = SettingsService.instance.notifier.value;
      final ctx = _navigatorKey?.currentContext;
      if (ctx == null) return; // can't localize without a valid context
      await _maybeReschedule(ctx, s);
    });

    // Ensure timezone data is initialized for scheduling
    try {
      tzdata.initializeTimeZones();
    } catch (_) {}

    _initialized = true;
  }

  Future<void> _maybeReschedule(BuildContext? context, PrayerSettings s) async {
    if (s.enablePrayerNotifications) {
      if (context == null) return;
      await schedulePrayerNotificationsForCurrentLocation(s);
    } else {
      await cancelAllPrayerNotifications();
    }
  }

  /// Request notification permissions (useful for iOS and Android 13+)
  Future<void> requestPermissions() async {
    // Request iOS permissions. Android 13+ should request at runtime via
    // permission_handler or similar; manifest contains POST_NOTIFICATIONS.
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    // Skipping explicit Android runtime permission request here to avoid
    // calling an API that may not exist across versions; use a permission
    // plugin in app flow if you want to proactively request POST_NOTIFICATIONS.
  }

  /// Cancel all scheduled prayer notifications
  Future<void> cancelAllPrayerNotifications() async {
    await _plugin.cancelAll();
  }

  static const Map<String, int> _prayerIds = {
    'Fajr': 100,
    'Dhuhr': 101,
    'Asr': 102,
    'Maghrib': 103,
    'Isha': 104,
  };

  /// Schedule daily notifications for the main prayers using current location
  Future<void> schedulePrayerNotificationsForCurrentLocation(
    PrayerSettings settings,
  ) async {
    try {
      // Ensure permissions and timezone data are ready
      await requestPermissions();

      final pos = await LocationService.getCurrentPosition();
      final lat = pos.latitude;
      final lon = pos.longitude;
      await schedulePrayerNotificationsForLocation(lat, lon, settings);
    } catch (e) {
      // Fallback to last known cached location if available
      final cached = await LocationService.getLastLocation();
      if (cached != null) {
        await schedulePrayerNotificationsForLocation(
          cached['lat'] as double,
          cached['lon'] as double,
          settings,
        );
      } else {
        // cannot schedule without location
      }
    }
  }

  /// Schedule daily repeating notifications for prayers at their local times
  Future<void> schedulePrayerNotificationsForLocation(
    double latitude,
    double longitude,
    PrayerSettings settings,
  ) async {
    // Cancel existing prayer notifications first
    await cancelAllPrayerNotifications();

    // Capture context early to avoid using BuildContext across async gaps
    final ctx = _navigatorKey?.currentContext;
    final Element? elem = ctx is Element ? ctx : null;
    final ctxMounted = elem?.mounted ?? false;

    // Compute today's prayer times for the given location/timezone
    final today = DateTime.now();
    final daily = await ps.PrayerService.calculatePrayerTimes(
      latitude: latitude,
      longitude: longitude,
      date: DateTime(today.year, today.month, today.day),
      settings: settings,
    );

    // We schedule notifications only for main prayers Fajr, Dhuhr, Asr, Maghrib, Isha
    final mainNames = {'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};

    for (final prayer in daily.prayers) {
      if (!mainNames.contains(prayer.name)) continue;

      final id = _prayerIds[prayer.name]!;

      // Build localized message using navigatorKey context if available and still mounted
      // We captured `elem` and `ctxMounted` before the async gap above. Use them
      // only when the element was mounted to avoid using a stale BuildContext.
      final prayerLabel = ctxMounted
          ? tr(prayer.name.toLowerCase(), context: elem)
          : prayer.name;
      // ignore: use_build_context_synchronously
      final title = ctxMounted
          ? tr('notification_prayer_title', context: elem)
          : 'Prayer time';
      // ignore: use_build_context_synchronously
      final body = ctxMounted
          ? tr(
              'notification_prayer_arrived',
              namedArgs: {'prayer': prayerLabel},
              context: elem,
            )
          : '$prayerLabel time has arrived';

      // Convert DateTime to tz aware time
      final tzTime = tz.TZDateTime.from(prayer.time, tz.local);
      // If the time already passed today, schedule starting tomorrow
      var scheduled = tzTime;
      if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      await _plugin.zonedSchedule(
        id,
        title,
        body,
        scheduled,
        NotificationDetails(
          android: AndroidNotificationDetails(
            _channel.id,
            _channel.name,
            channelDescription: _channel.description,
            importance: Importance.high,
            priority: Priority.high,
            ticker: 'prayer',
          ),
          iOS: const DarwinNotificationDetails(),
        ),
        // Use explicit Android scheduling mode to ensure alarms trigger on modern OS versions
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        matchDateTimeComponents: DateTimeComponents.time,
        payload: prayer.name,
      );
    }
  }
}
