import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/models/calc_preset.dart';
import 'package:kiblat/services/settings_service.dart';

class CalcPresetService {
  CalcPresetService._();
  static final CalcPresetService instance = CalcPresetService._();

  static const _key = 'pro_calc_presets';
  static const maxPresets = 8;

  final ValueNotifier<List<CalcPreset>> presetsNotifier = ValueNotifier([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    presetsNotifier.value =
        CalcPreset.listFromJsonString(prefs.getString(_key));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      CalcPreset.listToJsonString(presetsNotifier.value),
    );
  }

  Future<bool> addPreset(CalcPreset preset) async {
    if (presetsNotifier.value.length >= maxPresets) return false;
    presetsNotifier.value = [...presetsNotifier.value, preset];
    await _persist();
    return true;
  }

  Future<void> removePreset(String id) async {
    presetsNotifier.value =
        presetsNotifier.value.where((p) => p.id != id).toList();
    await _persist();
  }

  /// Apply preset onto current PrayerSettings and persist.
  Future<void> applyPreset(CalcPreset preset) async {
    final current = SettingsService.instance.notifier.value;
    final updated = current.copyWith(
      madhab: preset.madhab,
      calculationMethod: preset.calculationMethod,
      highLatitudeRule: preset.highLatitudeRule,
      adjustmentMinutes: preset.adjustmentMinutes,
      timezoneId: preset.timezoneId,
      clearTimezone: preset.timezoneId == null,
    );
    await SettingsService.instance.update(updated);
  }

  CalcPreset fromCurrentSettings(String id, String name) {
    final s = SettingsService.instance.notifier.value;
    return CalcPreset(
      id: id,
      name: name,
      madhab: s.madhab,
      calculationMethod: s.calculationMethod,
      highLatitudeRule: s.highLatitudeRule,
      adjustmentMinutes: s.adjustmentMinutes,
      timezoneId: s.timezoneId,
    );
  }
}
