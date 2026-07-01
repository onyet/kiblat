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
class NotificationService {
  NotificationService._internal();

  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  static const MethodChannel _platformChannel = MethodChannel(
    'id.onyet.app.kiblat/platform',
  );
  bool _initialized = false;

  /// Current notification channel ID for Adzan (changes when custom sound is set)
  String _currentChannelId = 'prayer_times';
  
  /// Fixed channel ID for reminders (standard sound)
  static const String _reminderChannelId = 'prayer_reminders';

  Future<void> initialize(GlobalKey<NavigatorState> navigatorKey) async {
    if (_initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosInit = DarwinInitializationSettings(
      requestSoundPermission: true,
      requestBadgePermission: true,
      requestAlertPermission: true,
    );

    await _plugin.initialize(
      const InitializationSettings(android: androidInit, iOS: iosInit),
    );

    // Create default channels
    await _ensureNotificationChannels(null);

    // Listen for settings changes
    SettingsService.instance.notifier.addListener(() async {
      final s = SettingsService.instance.notifier.value;
      await schedulePrayerNotificationsForCurrentLocation(s);
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
        localTimezoneId = await _platformChannel.invokeMethod<String>('getLocalTimezone');
      } catch (_) {}
    }

    if (localTimezoneId == null || localTimezoneId.isEmpty) return;
    try {
      tz.setLocalLocation(tz.getLocation(localTimezoneId));
    } catch (_) {}
  }

  Future<String?> _usableAndroidSoundUri(String? customSoundPath) async {
    if (customSoundPath == null || customSoundPath.isEmpty) return null;
    if (!Platform.isAndroid) return customSoundPath;
    if (customSoundPath.startsWith('content://') || customSoundPath.startsWith('android.resource://')) {
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
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return AndroidScheduleMode.inexactAllowWhileIdle;
    try {
      final canScheduleExact = await androidPlugin.canScheduleExactNotifications();
      if (canScheduleExact ?? false) return AndroidScheduleMode.exactAllowWhileIdle;
    } catch (_) {}
    return AndroidScheduleMode.inexactAllowWhileIdle;
  }

  Future<void> _ensureNotificationChannels(String? customSoundPath) async {
    final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // 1. Adzan Channel
    final soundUri = await _usableAndroidSoundUri(customSoundPath);
    if (soundUri != null && soundUri.isNotEmpty) {
      final newChannelId = _channelIdForSound(soundUri);
      try {
        if (_currentChannelId != 'prayer_times' && _currentChannelId != newChannelId) {
          await androidPlugin.deleteNotificationChannel(_currentChannelId);
        }
      } catch (_) {}
      final channel = AndroidNotificationChannel(
        newChannelId, 'Adzan Notification',
        description: 'Daily adzan notifications',
        importance: Importance.high,
        sound: UriAndroidNotificationSound(soundUri),
        playSound: true,
      );
      await androidPlugin.createNotificationChannel(channel);
      _currentChannelId = newChannelId;
    } else {
      try {
        if (_currentChannelId != 'prayer_times') await androidPlugin.deleteNotificationChannel(_currentChannelId);
      } catch (_) {}
      const channel = AndroidNotificationChannel('prayer_times', 'Adzan Notification',
          description: 'Daily adzan notifications', importance: Importance.high);
      await androidPlugin.createNotificationChannel(channel);
      _currentChannelId = 'prayer_times';
    }

    // 2. Reminder Channel (Pro) - uses default sound
    const reminderChannel = AndroidNotificationChannel(_reminderChannelId, 'Prayer Reminders',
        description: 'Advanced pre/post prayer reminders', importance: Importance.high, playSound: true);
    await androidPlugin.createNotificationChannel(reminderChannel);
  }

  Future<bool> areNotificationsEnabled() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) return await androidPlugin.areNotificationsEnabled() ?? false;
    }
    return true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      if (androidPlugin != null) return await androidPlugin.requestNotificationsPermission() ?? false;
    }
    if (Platform.isIOS) {
      final iosPlugin = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      if (iosPlugin != null) return await iosPlugin.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return true;
  }

  Future<void> cancelAllPrayerNotifications() async => await _plugin.cancelAll();

  static const Map<String, int> _prayerIds = {'Fajr': 100, 'Dhuhr': 101, 'Asr': 102, 'Maghrib': 103, 'Isha': 104};

  Future<void> schedulePrayerNotificationsForCurrentLocation(PrayerSettings settings) async {
    try {
      if (!await areNotificationsEnabled() && !await requestPermissions()) return;
      await _ensureNotificationChannels(settings.customRingtonePath);
      final pos = await LocationService.getCurrentPosition();
      await schedulePrayerNotificationsForLocation(pos.latitude, pos.longitude, settings);
    } catch (e) {
      final cached = await LocationService.getLastLocation();
      if (cached != null) {
        await schedulePrayerNotificationsForLocation(cached['lat'] as double, cached['lon'] as double, settings);
      }
    }
  }

  Future<void> schedulePrayerNotificationsForLocation(double latitude, double longitude, PrayerSettings settings) async {
    await cancelAllPrayerNotifications();
    if (!settings.enablePrayerNotifications) return;
    
    await _configureLocalTimezone(settings.timezoneId);
    final androidScheduleMode = await _resolveAndroidScheduleMode();
    final customSoundUri = await _usableAndroidSoundUri(settings.customRingtonePath);
    final hasCustomSound = customSoundUri != null && customSoundUri.isNotEmpty;

    final mainNames = {'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};
    final today = DateTime.now();

    for (int dayOffset = 0; dayOffset < 7; dayOffset++) {
      final targetDate = today.add(Duration(days: dayOffset));
      final daily = await ps.PrayerService.calculatePrayerTimes(
        latitude: latitude, longitude: longitude,
        date: DateTime(targetDate.year, targetDate.month, targetDate.day), settings: settings,
      );

      for (final prayer in daily.prayers) {
        if (!mainNames.contains(prayer.name)) continue;

        // 1. MAIN ADZAN NOTIFICATION
        final scheduledAdzan = tz.TZDateTime.from(prayer.time, tz.local);
        if (scheduledAdzan.isAfter(tz.TZDateTime.now(tz.local))) {
          final adzanId = _prayerIds[prayer.name]! + (dayOffset * 100);
          final prayerLabel = tr(prayer.name.toLowerCase());
          
          await _plugin.zonedSchedule(
            adzanId, tr('notification_prayer_title'),
            tr('notification_prayer_arrived', namedArgs: {'prayer': prayerLabel}),
            scheduledAdzan,
            NotificationDetails(
              android: AndroidNotificationDetails(_currentChannelId, 'Adzan',
                importance: Importance.high, priority: Priority.high,
                sound: hasCustomSound ? UriAndroidNotificationSound(customSoundUri) : null),
              iOS: DarwinNotificationDetails(presentSound: true, sound: hasCustomSound ? settings.customRingtonePath : null),
            ),
            androidScheduleMode: androidScheduleMode,
            payload: 'adzan_${prayer.name}',
          );
        }

        // 2. ADVANCED REMINDER (PRO)
        if (settings.isProUser && settings.enableAdvancedReminders) {
          final reminderTime = prayer.time.add(Duration(minutes: settings.reminderOffset));
          final scheduledReminder = tz.TZDateTime.from(reminderTime, tz.local);
          
          if (scheduledReminder.isAfter(tz.TZDateTime.now(tz.local))) {
            final reminderId = _prayerIds[prayer.name]! + (dayOffset * 100) + 1000;
            final prayerLabel = tr(prayer.name.toLowerCase());
            final minutes = settings.reminderOffset.abs();
            final isBefore = settings.reminderOffset < 0;
            
            final body = isBefore 
                ? tr('reminder_before_fmt', namedArgs: {'min': '$minutes', 'prayer': prayerLabel})
                : tr('reminder_after_fmt', namedArgs: {'min': '$minutes', 'prayer': prayerLabel});

            await _plugin.zonedSchedule(
              reminderId, tr('prayer_reminder'), body,
              scheduledReminder,
              NotificationDetails(
                android: const AndroidNotificationDetails(_reminderChannelId, 'Reminders',
                  importance: Importance.high, priority: Priority.high), // Standard sound
                iOS: const DarwinNotificationDetails(presentSound: true),
              ),
              androidScheduleMode: androidScheduleMode,
              payload: 'reminder_${prayer.name}',
            );
          }
        }
      }
    }
  }

  Future<void> triggerTestNotification(PrayerSettings settings) async {
    final title = tr('notification_prayer_title');
    final body = 'Tes Adzan: ${settings.customRingtoneName ?? 'Default'}';
    await _ensureNotificationChannels(settings.customRingtonePath);
    String? customSoundUri = Platform.isAndroid ? await _usableAndroidSoundUri(settings.customRingtonePath) : null;
    final hasCustomSound = settings.customRingtonePath != null && settings.customRingtonePath!.isNotEmpty;

    await _plugin.show(999, title, body,
      NotificationDetails(
        android: AndroidNotificationDetails(_currentChannelId, 'Adzan',
          importance: Importance.high, priority: Priority.high,
          sound: hasCustomSound && customSoundUri != null ? UriAndroidNotificationSound(customSoundUri) : null),
        iOS: DarwinNotificationDetails(presentSound: true, sound: hasCustomSound ? settings.customRingtonePath : null),
      ),
      payload: 'test',
    );
  }
}
