import 'package:adhan/adhan.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:kiblat/models/prayer_settings_model.dart';

/// Prayer time data for a single prayer
class PrayerTime {
  final String name;
  final DateTime time;
  final String timeString; // e.g., "05:42 AM"
  final String arabicName;
  final String subtitle;
  final bool isSunnah; // True for sunnah times like Dhuha, Tahajjud

  PrayerTime({
    required this.name,
    required this.time,
    required this.timeString,
    required this.arabicName,
    required this.subtitle,
    this.isSunnah = false,
  });

  /// Check if this prayer is currently active (within its time window)
  /// Returns true if current time is between this prayer and next prayer
  bool isActive(DateTime now) {
    return time.isBefore(now) &&
        time.add(const Duration(minutes: 30)).isAfter(now);
  }

  /// Check if this is the next upcoming prayer
  bool isNext(DateTime now, List<PrayerTime> allPrayers) {
    // Find the next prayer after now
    final upcoming = allPrayers.where((p) => p.time.isAfter(now)).toList();
    if (upcoming.isEmpty) return false;
    upcoming.sort((a, b) => a.time.compareTo(b.time));
    return this == upcoming.first;
  }
}

/// All prayer times for a specific date
class DailyPrayerTimes {
  final DateTime date;
  final List<PrayerTime> prayers;

  DailyPrayerTimes({required this.date, required this.prayers});

  /// Get the current active prayer, or null if no prayer is active
  PrayerTime? getActivePrayer() {
    try {
      return prayers.firstWhere((p) => p.isActive(DateTime.now()));
    } catch (e) {
      return null;
    }
  }

  /// Get the next upcoming prayer
  PrayerTime? getNextPrayer() {
    try {
      final upcoming = prayers
          .where((p) => p.time.isAfter(DateTime.now()))
          .toList();
      if (upcoming.isEmpty) return null;
      upcoming.sort((a, b) => a.time.compareTo(b.time));
      return upcoming.first;
    } catch (e) {
      return null;
    }
  }
}

/// Service to calculate prayer times using Adhan library
class PrayerService {
  /// Calculate prayer times for a specific date and location
  static Future<DailyPrayerTimes> calculatePrayerTimes({
    required double latitude,
    required double longitude,
    required DateTime date,
    required PrayerSettings settings,
  }) async {
    try {
      // Create coordinates for the location
      final coordinates = Coordinates(latitude, longitude);

      // Get calculation parameters for the selected method
      final params = settings.calculationMethod.getParameters();

      // Set the madhab
      params.madhab = settings.madhab;

      // Set the high latitude rule
      params.highLatitudeRule = settings.highLatitudeRule;

      // Create date components from the DateTime
      final dateComponents = DateComponents(date.year, date.month, date.day);

      // Determine UTC offset based on timezone settings (Duration)
      final utcOffsetDur = await _getUtcOffset(settings.timezoneId, date);

      // Create prayer times object with timezone (use named utcOffset param to ensure
      // Adhan converts results to local times for that UTC offset)
      PrayerTimes? prayerTimes;
      bool useFallback = false;
      DateTime? fajrFallback;
      DateTime? dhuhrFallback;
      DateTime? maghribFallback;
      DateTime? ishaFallback;

      try {
        prayerTimes = PrayerTimes(
          coordinates,
          dateComponents,
          params,
          utcOffset: utcOffsetDur,
        );
      } catch (e) {
        // Some extreme latitudes / parameter combos may cause internal NaN/Inf in
        // the adhan library. Try a set of fallback high-latitude rules before
        // giving up and using a crude fallback.
        final fallbackRules = [
          HighLatitudeRule.middle_of_the_night,
          HighLatitudeRule.seventh_of_the_night,
          HighLatitudeRule.twilight_angle,
        ];

        PrayerTimes? tmp;
        for (final r in fallbackRules) {
          if (r == params.highLatitudeRule) continue;
          try {
            params.highLatitudeRule = r;
            tmp = PrayerTimes(
              coordinates,
              dateComponents,
              params,
              utcOffset: utcOffsetDur,
            );
            break;
          } catch (_) {
            // continue trying
          }
        }

        if (tmp == null) {
          // Last-resort fallback: approximate with fixed times (safe non-throwing defaults)
          useFallback = true;
          final tzDate = DateTime(date.year, date.month, date.day);
          fajrFallback = DateTime(tzDate.year, tzDate.month, tzDate.day, 5, 0);
          dhuhrFallback = DateTime(
            tzDate.year,
            tzDate.month,
            tzDate.day,
            12,
            0,
          );
          maghribFallback = DateTime(
            tzDate.year,
            tzDate.month,
            tzDate.day,
            18,
            0,
          );
          ishaFallback = DateTime(
            tzDate.year,
            tzDate.month,
            tzDate.day,
            19,
            30,
          );
        } else {
          prayerTimes = tmp;
        }
      }

      // Build list of prayers with translations
      final List<PrayerTime> prayers = [];

      // Helper: convert DateTime returned by Adhan to a local wall-clock DateTime
      DateTime toLocalWallClock(DateTime d) => DateTime(
        d.year,
        d.month,
        d.day,
        d.hour,
        d.minute,
        d.second,
        d.millisecond,
        d.microsecond,
      );

      // If we had to fall back, construct times from fallback values; otherwise use prayerTimes from adhan
      final fajrTime = useFallback
          ? fajrFallback!
          : _applyAdjustment(
              toLocalWallClock(prayerTimes!.fajr),
              settings.adjustmentMinutes,
            );
      final sunriseTime = useFallback
          ? fajrFallback!.add(const Duration(hours: 3))
          : _applyAdjustment(
              toLocalWallClock(prayerTimes!.sunrise),
              settings.adjustmentMinutes,
            );
      final dhuhrTime = useFallback
          ? dhuhrFallback!
          : _applyAdjustment(
              toLocalWallClock(prayerTimes!.dhuhr),
              settings.adjustmentMinutes,
            );
      final asrTime = useFallback
          ? dhuhrFallback!.add(const Duration(hours: 4))
          : _applyAdjustment(
              toLocalWallClock(prayerTimes!.asr),
              settings.adjustmentMinutes,
            );
      final maghribTime = useFallback
          ? maghribFallback!
          : _applyAdjustment(
              toLocalWallClock(prayerTimes!.maghrib),
              settings.adjustmentMinutes,
            );
      final ishaTime = useFallback
          ? ishaFallback!
          : _applyAdjustment(
              toLocalWallClock(prayerTimes!.isha),
              settings.adjustmentMinutes,
            );

      // Fajr (Dawn)
      prayers.add(
        PrayerTime(
          name: 'Fajr',
          arabicName: 'الفجر',
          time: fajrTime,
          timeString: _formatTime(fajrTime, settings.use24Hour),
          subtitle: 'DAWN',
        ),
      );

      // Sunrise
      prayers.add(
        PrayerTime(
          name: 'Sunrise',
          arabicName: 'الشروق',
          time: sunriseTime,
          timeString: _formatTime(sunriseTime, settings.use24Hour),
          subtitle: 'SHURUQ',
        ),
      );

      // Dhuhr (Noon)
      prayers.add(
        PrayerTime(
          name: 'Dhuhr',
          arabicName: 'الظهر',
          time: dhuhrTime,
          timeString: _formatTime(dhuhrTime, settings.use24Hour),
          subtitle: 'NOON',
        ),
      );

      // Asr (Afternoon) - affected by madhab
      prayers.add(
        PrayerTime(
          name: 'Asr',
          arabicName: 'العصر',
          time: asrTime,
          timeString: _formatTime(asrTime, settings.use24Hour),
          subtitle: 'AFTERNOON',
        ),
      );

      // Maghrib (Sunset)
      prayers.add(
        PrayerTime(
          name: 'Maghrib',
          arabicName: 'المغرب',
          time: maghribTime,
          timeString: _formatTime(maghribTime, settings.use24Hour),
          subtitle: 'SUNSET',
        ),
      );

      // Isha (Night)
      prayers.add(
        PrayerTime(
          name: 'Isha',
          arabicName: 'العشاء',
          time: ishaTime,
          timeString: _formatTime(ishaTime, settings.use24Hour),
          subtitle: 'NIGHT',
        ),
      );

      // Add sunnah times if enabled (and per-sunnah toggles)
      if (settings.showSunnahTimes) {
        final includeDhuha = settings.showDhuha;
        final includeTahajjud = settings.showTahajjud;
        // Tahajjud (Night prayer) - approximately middle of night
        late final DateTime tahajjudTime;
        if (!useFallback) {
          final pt = prayerTimes!;
          final ishaLocal = DateTime(
            pt.isha.year,
            pt.isha.month,
            pt.isha.day,
            pt.isha.hour,
            pt.isha.minute,
            pt.isha.second,
          );
          final fajrLocal = DateTime(
            pt.fajr.year,
            pt.fajr.month,
            pt.fajr.day,
            pt.fajr.hour,
            pt.fajr.minute,
            pt.fajr.second,
          );
          tahajjudTime = ishaLocal.add(
            Duration(
              hours: (fajrLocal.difference(ishaLocal).inHours) ~/ 2,
              minutes: (fajrLocal.difference(ishaLocal).inMinutes % 60) ~/ 2,
            ),
          );
        } else {
          tahajjudTime = ishaFallback!.subtract(
            const Duration(hours: 6),
          ); // crude fallback
        }

        if (includeTahajjud) {
          prayers.add(
            PrayerTime(
              name: 'Tahajjud',
              arabicName: 'التهجد',
              time: tahajjudTime,
              timeString: _formatTime(tahajjudTime, settings.use24Hour),
              subtitle: 'NIGHT PRAYER',
              isSunnah: true,
            ),
          );
        }

        // Dhuha (Morning prayer) - approximately 20-30 min after sunrise
        late final DateTime dhuhaTime;
        if (!useFallback) {
          dhuhaTime = toLocalWallClock(
            prayerTimes!.sunrise,
          ).add(const Duration(minutes: 25));
        } else {
          dhuhaTime = fajrFallback!.add(const Duration(hours: 3));
        }

        if (includeDhuha) {
          prayers.add(
            PrayerTime(
              name: 'Dhuha',
              arabicName: 'الضحى',
              time: dhuhaTime,
              timeString: _formatTime(dhuhaTime, settings.use24Hour),
              subtitle: 'MORNING PRAYER',
              isSunnah: true,
            ),
          );
        }
      }

      // Sort by time
      prayers.sort((a, b) => a.time.compareTo(b.time));

      return DailyPrayerTimes(date: date, prayers: prayers);
    } catch (e) {
      rethrow;
    }
  }

  /// Get UTC offset for the given timezone
  /// If timezoneId is null, uses device timezone
  static Future<Duration> _getUtcOffset(
    String? timezoneId,
    DateTime date,
  ) async {
    try {
      if (timezoneId != null && timezoneId.isNotEmpty) {
        // Use specified timezone
        final location = tz.getLocation(timezoneId);
        final tzDate = tz.TZDateTime.from(date, location);
        return tzDate.timeZoneOffset;
      } else {
        // Use device timezone (default)
        return DateTime.now().timeZoneOffset;
      }
    } catch (e) {
      // Fallback to device timezone if specified timezone is invalid
      return DateTime.now().timeZoneOffset;
    }
  }

  /// Apply adjustment minutes to a prayer time
  static DateTime _applyAdjustment(DateTime time, int adjustmentMinutes) {
    return time.add(Duration(minutes: adjustmentMinutes));
  }

  /// Format DateTime to time string (e.g., "05:42 AM")
  static String _formatTime(DateTime time, bool use24Hour) {
    final hour = time.hour;
    final minute = time.minute;
    if (use24Hour) {
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final period = hour >= 12 ? 'PM' : 'AM';
    final displayHour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

    return '$displayHour:${minute.toString().padLeft(2, '0')} $period';
  }

  /// Get the next prayer time from now
  /// Searches through today and tomorrow if needed
  static Future<PrayerTime?> getNextPrayerTime({
    required double latitude,
    required double longitude,
    required PrayerSettings settings,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Try to find next prayer today
    final todayPrayers = await calculatePrayerTimes(
      latitude: latitude,
      longitude: longitude,
      date: today,
      settings: settings,
    );

    final upcoming = todayPrayers.prayers
        .where((p) => p.time.isAfter(now))
        .toList();

    if (upcoming.isNotEmpty) {
      upcoming.sort((a, b) => a.time.compareTo(b.time));
      return upcoming.first;
    }

    // If no prayer today, get first prayer tomorrow
    final tomorrow = today.add(const Duration(days: 1));
    final tomorrowPrayers = await calculatePrayerTimes(
      latitude: latitude,
      longitude: longitude,
      date: tomorrow,
      settings: settings,
    );

    if (tomorrowPrayers.prayers.isNotEmpty) {
      return tomorrowPrayers.prayers.first;
    }

    return null;
  }

  /// Get the previous (most recent) prayer time before now.
  /// Searches today and falls back to yesterday if needed.
  static Future<PrayerTime?> getPreviousPrayerTime({
    required double latitude,
    required double longitude,
    required PrayerSettings settings,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Try to find last prayer today
    final todayPrayers = await calculatePrayerTimes(
      latitude: latitude,
      longitude: longitude,
      date: today,
      settings: settings,
    );

    final past = todayPrayers.prayers
        .where((p) => p.time.isBefore(now))
        .toList();
    if (past.isNotEmpty) {
      past.sort((a, b) => b.time.compareTo(a.time));
      return past.first;
    }

    // Fallback to yesterday's last prayer
    final yesterday = today.subtract(const Duration(days: 1));
    final yesterdayPrayers = await calculatePrayerTimes(
      latitude: latitude,
      longitude: longitude,
      date: yesterday,
      settings: settings,
    );

    if (yesterdayPrayers.prayers.isNotEmpty) {
      final list = yesterdayPrayers.prayers;
      list.sort((a, b) => b.time.compareTo(a.time));
      return list.first;
    }

    return null;
  }

  /// Convenience to get both previous and next prayer times
  static Future<Map<String, PrayerTime?>> getPrevAndNextPrayerTimes({
    required double latitude,
    required double longitude,
    required PrayerSettings settings,
  }) async {
    final next = await getNextPrayerTime(
      latitude: latitude,
      longitude: longitude,
      settings: settings,
    );
    final prev = await getPreviousPrayerTime(
      latitude: latitude,
      longitude: longitude,
      settings: settings,
    );
    return {'previous': prev, 'next': next};
  }

  /// Progress (0.0 - 1.0) between two moments
  static double progressBetween(DateTime start, DateTime end, DateTime now) {
    final total = end.difference(start).inSeconds;
    if (total <= 0) return 0.0;
    final passed = now.difference(start).inSeconds;
    return (passed / total).clamp(0.0, 1.0);
  }

  /// Time until the given prayer from now
  static Duration timeUntil(PrayerTime prayer) =>
      prayer.time.difference(DateTime.now());
}
