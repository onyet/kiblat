import 'package:timezone/timezone.dart' as tz;

/// Utility for timezone management
class TimezoneUtil {
  /// List of popular timezones for the UI picker
  /// Format: 'Continent/City'
  static const List<String> popularTimezones = [
    // Default (device timezone)
    'Device Timezone',

    // Asia
    'Asia/Jakarta',
    'Asia/Bangkok',
    'Asia/Riyadh',
    'Asia/Dubai',
    'Asia/Kolkata',
    'Asia/Singapore',
    'Asia/Hong_Kong',
    'Asia/Tokyo',
    'Asia/Shanghai',
    'Asia/Manila',
    'Asia/Istanbul',
    'Asia/Tehran',

    // Europe
    'Europe/London',
    'Europe/Berlin',
    'Europe/Paris',
    'Europe/Madrid',
    'Europe/Rome',
    'Europe/Amsterdam',
    'Europe/Moscow',
    'Europe/Istanbul',

    // Africa
    'Africa/Cairo',
    'Africa/Johannesburg',
    'Africa/Lagos',
    'Africa/Nairobi',
    'Africa/Casablanca',

    // Americas
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
    'America/Toronto',
    'America/Mexico_City',
    'America/Sao_Paulo',
    'America/Buenos_Aires',

    // Australia & Pacific
    'Australia/Sydney',
    'Australia/Melbourne',
    'Australia/Brisbane',
    'Pacific/Auckland',
    'Pacific/Fiji',
  ];

  /// Get all available timezones
  /// Returns a sorted list of valid IANA timezone identifiers
  static List<String> getAllTimezones() {
    try {
      final allZones = tz.timeZoneDatabase.locations.keys.toList();
      allZones.sort();
      return allZones;
    } catch (e) {
      // Fallback to popular timezones if database fails
      return popularTimezones.where((tz) => tz != 'Device Timezone').toList();
    }
  }

  /// Get timezone offset as a readable string
  /// Example: "UTC+05:30", "UTC-08:00"
  static String getOffsetString(String? timezoneId) {
    try {
      if (timezoneId == null || timezoneId == 'Device Timezone') {
        final offset = DateTime.now().timeZoneOffset;
        return _formatOffset(offset);
      }

      final location = tz.getLocation(timezoneId);
      final now = tz.TZDateTime.now(location);
      return _formatOffset(now.timeZoneOffset);
    } catch (e) {
      return 'UTC±00:00';
    }
  }

  /// Get current time in specified timezone
  static String getCurrentTimeInTimezone(String? timezoneId) {
    try {
      if (timezoneId == null || timezoneId == 'Device Timezone') {
        final now = DateTime.now();
        return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      }

      final location = tz.getLocation(timezoneId);
      final now = tz.TZDateTime.now(location);
      return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return '--:--';
    }
  }

  /// Validate if a timezone ID is valid
  static bool isValidTimezone(String timezoneId) {
    try {
      if (timezoneId == 'Device Timezone') return true;
      tz.getLocation(timezoneId);
      return true;
    } catch (e) {
      return false;
    }
  }

  /// Format offset duration to readable string
  static String _formatOffset(Duration offset) {
    final hours = offset.inHours;
    final minutes = offset.inMinutes % 60;
    final sign = hours >= 0 ? '+' : '-';
    final absHours = hours.abs();

    return 'UTC$sign${absHours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
  }

  /// Get display name for timezone
  /// Shows timezone and current offset
  static String getDisplayName(String? timezoneId) {
    if (timezoneId == null || timezoneId == 'Device Timezone') {
      return 'Device Timezone (${getOffsetString(null)})';
    }

    return '$timezoneId (${getOffsetString(timezoneId)})';
  }
}
