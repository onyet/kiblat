import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  static const MethodChannel _platformChannel = MethodChannel(
    'id.onyet.app.kiblat/platform',
  );
  bool _initialized = false;

  /// Current notification channel ID (changes when custom sound is set)
  String _currentChannelId = 'prayer_times';

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

    // Create default channel
    await _ensureNotificationChannel(null);

    // Listen for settings changes to reschedule notifications with new locale/time
    SettingsService.instance.notifier.addListener(() async {
      final s = SettingsService.instance.notifier.value;
      final ctx = _navigatorKey?.currentContext;
      if (ctx == null) return;
      await _maybeReschedule(ctx, s);
    });

    await _configureLocalTimezone();

    _initialized = true;
  }

  Future<void> _configureLocalTimezone([String? timezoneId]) async {
    try {
      tzdata.initializeTimeZones();
    } catch (_) {}

    String? localTimezoneId = timezoneId;
    if (localTimezoneId == null || localTimezoneId.isEmpty) {
      try {
        localTimezoneId = await _platformChannel.invokeMethod<String>(
          'getLocalTimezone',
        );
      } catch (_) {}
    }

    if (localTimezoneId == null || localTimezoneId.isEmpty) return;

    try {
      tz.setLocalLocation(tz.getLocation(localTimezoneId));
    } catch (_) {
      // Keep timezone's default UTC location if the OS returns an unknown ID.
    }
  }

  Future<String?> _usableAndroidSoundUri(String? customSoundPath) async {
    if (customSoundPath == null || customSoundPath.isEmpty) return null;
    if (!Platform.isAndroid) return customSoundPath;

    // Android's NotificationManager cannot reliably read app-private file
    // paths. Use persisted content/resource URIs, otherwise fall back to the
    // default channel sound instead of creating a broken custom channel.
    if (customSoundPath.startsWith('content://') ||
        customSoundPath.startsWith('android.resource://')) {
      return customSoundPath;
    }
    return null;
  }

  String _channelIdForSound(String? soundUri) {
    if (soundUri == null || soundUri.isEmpty) return 'prayer_times';

    var hash = 2166136261;
    for (final unit in soundUri.codeUnits) {
      hash ^= unit;
      hash = (hash * 16777619) & 0xffffffff;
    }
    return 'prayer_times_custom_${hash.toRadixString(16)}';
  }

  Future<AndroidScheduleMode> _resolveAndroidScheduleMode() async {
    if (!Platform.isAndroid) return AndroidScheduleMode.exactAllowWhileIdle;

    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return AndroidScheduleMode.inexactAllowWhileIdle;

    try {
      final canScheduleExact = await androidPlugin
          .canScheduleExactNotifications();
      if (canScheduleExact ?? false) {
        return AndroidScheduleMode.exactAllowWhileIdle;
      }
    } catch (_) {}

    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  /// Create or update the notification channel with optional custom sound
  Future<void> _ensureNotificationChannel(String? customSoundPath) async {
    final androidPlugin = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidPlugin == null) return;

    final soundUri = await _usableAndroidSoundUri(customSoundPath);

    if (soundUri != null && soundUri.isNotEmpty) {
      // Use a dedicated channel for custom sound
      final newChannelId = _channelIdForSound(soundUri);

      // Clean up the previous custom channel when changing sounds. Android
      // channel sounds are immutable after first creation, so each sound gets a
      // stable dedicated channel ID.
      try {
        if (_currentChannelId != 'prayer_times' &&
            _currentChannelId != newChannelId) {
          await androidPlugin.deleteNotificationChannel(_currentChannelId);
        }
      } catch (_) {}

      final channel = AndroidNotificationChannel(
        newChannelId,
        'Prayer times (Custom Adzan)',
        description: 'Adzan notifications for prayer times',
        importance: Importance.high,
        sound: UriAndroidNotificationSound(soundUri),
        playSound: true,
      );
      await androidPlugin.createNotificationChannel(channel);
      _currentChannelId = newChannelId;
    } else {
      // Delete custom channel if switching back to default
      try {
        if (_currentChannelId != 'prayer_times') {
          await androidPlugin.deleteNotificationChannel(_currentChannelId);
        }
      } catch (_) {}

      const channel = AndroidNotificationChannel(
        'prayer_times',
        'Prayer times',
        description: 'Notifications for prayer times',
        importance: Importance.high,
      );
      await androidPlugin.createNotificationChannel(channel);
      _currentChannelId = 'prayer_times';
    }
  }

  Future<void> _maybeReschedule(BuildContext? context, PrayerSettings s) async {
    if (s.enablePrayerNotifications) {
      if (context == null) return;
      await schedulePrayerNotificationsForCurrentLocation(s);
    } else {
      await cancelAllPrayerNotifications();
    }
  }

  /// Check if notification permissions are granted (Android 13+)
  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final enabled = await androidPlugin.areNotificationsEnabled();
        return enabled ?? false;
      }
    }
    // On iOS, assume enabled unless we can check
    return true;
  }

  /// Request notification permissions (Android 13+ and iOS)
  /// Returns true if permission was granted
  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      if (androidPlugin != null) {
        final granted = await androidPlugin.requestNotificationsPermission();
        return granted ?? false;
      }
    }

    if (Platform.isIOS) {
      final iosPlugin = _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      if (iosPlugin != null) {
        final granted = await iosPlugin.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
    }

    return true;
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
      // Check and request permissions first
      final hasPermission = await areNotificationsEnabled();
      if (!hasPermission) {
        final granted = await requestPermissions();
        if (!granted) return; // Can't schedule without permission
      }

      // Ensure the notification channel matches the current ringtone setting
      await _ensureNotificationChannel(settings.customRingtonePath);

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
    await _configureLocalTimezone(settings.timezoneId);

    // Capture context early to avoid using BuildContext across async gaps
    final ctx = _navigatorKey?.currentContext;
    final Element? elem = ctx is Element ? ctx : null;
    final ctxMounted = elem?.mounted ?? false;

    // Build notification details with custom sound if set
    final customSoundUri = await _usableAndroidSoundUri(
      settings.customRingtonePath,
    );
    final hasCustomSound = customSoundUri != null && customSoundUri.isNotEmpty;
    await _ensureNotificationChannel(settings.customRingtonePath);
    final androidScheduleMode = await _resolveAndroidScheduleMode();

    // We schedule notifications only for main prayers Fajr, Dhuhr, Asr, Maghrib, Isha
    final mainNames = {'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};

    final today = DateTime.now();

    // Loop through the next 10 days (from day 0 to day 9)
    for (int dayOffset = 0; dayOffset < 10; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final daily = await ps.PrayerService.calculatePrayerTimes(
        latitude: latitude,
        longitude: longitude,
        date: DateTime(targetDate.year, targetDate.month, targetDate.day),
        settings: settings,
      );

      for (final prayer in daily.prayers) {
        if (!mainNames.contains(prayer.name)) continue;

        // Assign a unique ID based on prayer ID and dayOffset (e.g. 100 for Fajr day 0, 110 for Fajr day 1)
        final baseId = _prayerIds[prayer.name]!;
        final id = baseId + (dayOffset * 10);

        // Convert to tz.TZDateTime using wall clock values from prayer.time
        final scheduled = tz.TZDateTime(
          tz.local,
          prayer.time.year,
          prayer.time.month,
          prayer.time.day,
          prayer.time.hour,
          prayer.time.minute,
          prayer.time.second,
        );

        // If this scheduled prayer time is in the past (e.g. earlier today), skip scheduling it
        if (scheduled.isBefore(tz.TZDateTime.now(tz.local))) {
          continue;
        }

        // Build localized message
        final prayerLabel = ctxMounted
            ? tr(prayer.name.toLowerCase(), context: elem)
            : prayer.name;
        final title = ctxMounted
            ? tr('notification_prayer_title', context: elem)
            : 'Prayer time';
        final body = ctxMounted
            ? tr(
                'notification_prayer_arrived',
                namedArgs: {'prayer': prayerLabel},
                context: elem,
              )
            : '$prayerLabel time has arrived';

        await _plugin.zonedSchedule(
          id,
          title,
          body,
          scheduled,
          NotificationDetails(
            android: AndroidNotificationDetails(
              _currentChannelId,
              'Prayer times',
              channelDescription: 'Adzan notifications for prayer times',
              importance: Importance.high,
              priority: Priority.high,
              ticker: 'prayer',
              sound: hasCustomSound
                  ? UriAndroidNotificationSound(customSoundUri)
                  : null,
              playSound: true,
            ),
            iOS: DarwinNotificationDetails(
              presentSound: true,
              sound: hasCustomSound ? settings.customRingtonePath : null,
            ),
          ),
          androidScheduleMode: androidScheduleMode,
          payload: prayer.name,
        );
      }
    }
  }

  Future<void> triggerTestNotification(PrayerSettings settings) async {
    final ctx = _navigatorKey?.currentContext;
    final title = ctx != null ? tr('notification_prayer_title') : 'Tes Notifikasi';
    final body = 'Ini adalah tes suara Adzan: ${settings.customRingtoneName ?? 'Default'}';

    await _ensureNotificationChannel(settings.customRingtonePath);

    String? customSoundUri;
    if (Platform.isAndroid && settings.customRingtonePath != null) {
      customSoundUri = await _usableAndroidSoundUri(settings.customRingtonePath);
    }

    final hasCustomSound = settings.customRingtonePath != null && settings.customRingtonePath!.isNotEmpty;

    await _plugin.show(
      999,
      title,
      body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _currentChannelId,
          'Prayer times',
          channelDescription: 'Adzan notifications for prayer times',
          importance: Importance.high,
          priority: Priority.high,
          sound: hasCustomSound && customSoundUri != null
              ? UriAndroidNotificationSound(customSoundUri)
              : null,
          playSound: true,
        ),
        iOS: DarwinNotificationDetails(
          presentSound: true,
          sound: hasCustomSound ? settings.customRingtonePath : null,
        ),
      ),
      payload: 'test',
    );
  }
}
