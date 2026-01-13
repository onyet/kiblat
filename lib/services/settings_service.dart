import 'package:flutter/foundation.dart';
import 'package:kiblat/models/prayer_settings_model.dart';

/// Singleton service exposing current PrayerSettings as a ValueListenable
/// so UI can react immediately when user updates settings.
class SettingsService {
  SettingsService._internal();

  static final SettingsService instance = SettingsService._internal();

  /// Exposed listenable for settings changes
  final ValueNotifier<PrayerSettings> notifier = ValueNotifier(PrayerSettings());

  /// Load persisted settings and update notifier
  Future<void> load() async {
    final s = await PrayerSettings.load();
    notifier.value = s;
  }

  /// Persist and broadcast updated settings
  Future<void> update(PrayerSettings s) async {
    await s.save();
    notifier.value = s;
  }
}
