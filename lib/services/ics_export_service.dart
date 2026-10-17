import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;

/// Generates an .ics calendar of upcoming prayer times (Pro).
class IcsExportService {
  IcsExportService._();
  static final IcsExportService instance = IcsExportService._();

  static const _mainNames = {'Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'};

  Future<void> exportAndShare({
    required double latitude,
    required double longitude,
    required PrayerSettings settings,
    int days = 60,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCALENDAR');
    buffer.writeln('VERSION:2.0');
    buffer.writeln('PRODID:-//Kiblat//Prayer Times//EN');
    buffer.writeln('CALSCALE:GREGORIAN');
    buffer.writeln('METHOD:PUBLISH');

    final now = DateTime.now();
    for (int d = 0; d < days; d++) {
      final date = DateTime(now.year, now.month, now.day).add(Duration(days: d));
      final daily = await ps.PrayerService.calculatePrayerTimes(
        latitude: latitude,
        longitude: longitude,
        date: date,
        settings: settings,
      );
      for (final prayer in daily.prayers) {
        if (!_mainNames.contains(prayer.name)) continue;
        final start = prayer.time;
        final end = start.add(const Duration(minutes: 15));
        final uid =
            'kiblat-${date.year}${date.month}${date.day}-${prayer.name}@kiblat.app';
        buffer.writeln('BEGIN:VEVENT');
        buffer.writeln('UID:$uid');
        buffer.writeln('DTSTAMP:${_fmtUtc(DateTime.now().toUtc())}');
        buffer.writeln('DTSTART:${_fmtLocal(start)}');
        buffer.writeln('DTEND:${_fmtLocal(end)}');
        buffer.writeln('SUMMARY:${prayer.name}');
        buffer.writeln('DESCRIPTION:Kiblat prayer time');
        buffer.writeln('END:VEVENT');
      }
    }

    buffer.writeln('END:VCALENDAR');

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kiblat_prayer_times.ics');
    await file.writeAsString(buffer.toString());
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'text/calendar')],
        subject: 'Kiblat Prayer Times',
      ),
    );
  }

  String _fmtUtc(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${p(dt.month)}${p(dt.day)}T${p(dt.hour)}${p(dt.minute)}${p(dt.second)}Z';
  }

  String _fmtLocal(DateTime dt) {
    String p(int n) => n.toString().padLeft(2, '0');
    return '${dt.year}${p(dt.month)}${p(dt.day)}T${p(dt.hour)}${p(dt.minute)}${p(dt.second)}';
  }
}
