import 'package:adhan/adhan.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Prayer times configuration settings
/// Supports different madhabs, calculation methods, and high latitude rules
class PrayerSettings {
  /// Islamic school of thought for fiqh-related calculations
  final Madhab madhab;

  /// Prayer times calculation method
  final CalculationMethod calculationMethod;

  /// Rule for high latitude areas (where some prayers may not have standard times)
  final HighLatitudeRule highLatitudeRule;

  /// Adjustment in minutes to add/subtract from calculated prayer times
  /// (for local conditions, imam preferences, etc.)
  final int adjustmentMinutes;

  /// Whether to show sunnah times (Dhuha, Tahajjud, etc.)
  final bool showSunnahTimes;
  final bool showDhuha;
  final bool showTahajjud;

  /// Timezone for prayer time calculations
  /// Examples: 'Asia/Jakarta', 'Asia/Riyadh', 'America/New_York'
  /// If null, uses device timezone
  final String? timezoneId;

  /// Whether to display prayer times in 24-hour format (e.g., 16:21). Default: true.
  final bool use24Hour;

  /// Whether to show local prayer notifications
  final bool enablePrayerNotifications;

  PrayerSettings({
    this.madhab = Madhab.shafi,
    this.calculationMethod = CalculationMethod.muslim_world_league,
    this.highLatitudeRule = HighLatitudeRule.middle_of_the_night,
    this.adjustmentMinutes = 0,
    this.showSunnahTimes = true,
    this.showDhuha = true,
    this.showTahajjud = true,
    this.timezoneId,
    this.use24Hour = true,
    this.enablePrayerNotifications = true,
  });

  /// Create a copy of this settings with optional modifications
  PrayerSettings copyWith({
    Madhab? madhab,
    CalculationMethod? calculationMethod,
    HighLatitudeRule? highLatitudeRule,
    int? adjustmentMinutes,
    bool? showSunnahTimes,
    bool? showDhuha,
    bool? showTahajjud,
    String? timezoneId,
    bool? use24Hour,
    bool? enablePrayerNotifications,
  }) {
    return PrayerSettings(
      madhab: madhab ?? this.madhab,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      highLatitudeRule: highLatitudeRule ?? this.highLatitudeRule,
      adjustmentMinutes: adjustmentMinutes ?? this.adjustmentMinutes,
      showSunnahTimes: showSunnahTimes ?? this.showSunnahTimes,
      showDhuha: showDhuha ?? this.showDhuha,
      showTahajjud: showTahajjud ?? this.showTahajjud,
      timezoneId: timezoneId ?? this.timezoneId,
      use24Hour: use24Hour ?? this.use24Hour,
      enablePrayerNotifications: enablePrayerNotifications ?? this.enablePrayerNotifications,
    );
  }

  /// Save settings to SharedPreferences
  Future<void> save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('madhab', madhab.name);
    await prefs.setString('calculationMethod', calculationMethod.name);
    await prefs.setString('highLatitudeRule', highLatitudeRule.name);
    await prefs.setInt('adjustmentMinutes', adjustmentMinutes);
    await prefs.setBool('showSunnahTimes', showSunnahTimes);
    await prefs.setBool('showDhuha', showDhuha);
    await prefs.setBool('showTahajjud', showTahajjud);
    if (timezoneId != null) {
      await prefs.setString('timezoneId', timezoneId!);
    } else {
      await prefs.remove('timezoneId');
    }
    await prefs.setBool('use24Hour', use24Hour);
    await prefs.setBool('enablePrayerNotifications', enablePrayerNotifications);
  }

  /// Load settings from SharedPreferences
  static Future<PrayerSettings> load() async {
    final prefs = await SharedPreferences.getInstance();

    final madhab = Madhab.values.firstWhere(
      (e) => e.name == prefs.getString('madhab'),
      orElse: () => Madhab.shafi,
    );

    final calculationMethod = CalculationMethod.values.firstWhere(
      (e) => e.name == prefs.getString('calculationMethod'),
      orElse: () => CalculationMethod.muslim_world_league,
    );

    final highLatitudeRule = HighLatitudeRule.values.firstWhere(
      (e) => e.name == prefs.getString('highLatitudeRule'),
      orElse: () => HighLatitudeRule.middle_of_the_night,
    );

    final adjustmentMinutes = prefs.getInt('adjustmentMinutes') ?? 0;
    final showSunnahTimes = prefs.getBool('showSunnahTimes') ?? true;
    final showDhuha = prefs.getBool('showDhuha') ?? true;
    final showTahajjud = prefs.getBool('showTahajjud') ?? true;
    final timezoneId = prefs.getString('timezoneId');
    final use24Hour = prefs.getBool('use24Hour') ?? true;
    final enablePrayerNotifications = prefs.getBool('enablePrayerNotifications') ?? true;

    return PrayerSettings(
      madhab: madhab,
      calculationMethod: calculationMethod,
      highLatitudeRule: highLatitudeRule,
      adjustmentMinutes: adjustmentMinutes,
      showSunnahTimes: showSunnahTimes,
      showDhuha: showDhuha,
      showTahajjud: showTahajjud,
      timezoneId: timezoneId,
      use24Hour: use24Hour,
      enablePrayerNotifications: enablePrayerNotifications,
    );
  }

  /// Get human-readable name for madhab
  static String madhubDisplay(Madhab madhab) {
    switch (madhab) {
      case Madhab.shafi:
        return 'Shafi\'i';
      case Madhab.hanafi:
        return 'Hanafi';
    }
  }

  /// Get human-readable name for calculation method
  static String calculationMethodDisplay(CalculationMethod method) {
    switch (method) {
      case CalculationMethod.muslim_world_league:
        return 'Muslim World League (MWL)';
      case CalculationMethod.egyptian:
        return 'Egyptian Authority';
      case CalculationMethod.karachi:
        return 'University of Islamic Sciences, Karachi';
      case CalculationMethod.umm_al_qura:
        return 'Umm al-Qura';
      case CalculationMethod.dubai:
        return 'Dubai (UAE)';
      case CalculationMethod.moon_sighting_committee:
        return 'Moon Sighting Committee';
      case CalculationMethod.north_america:
        return 'North America (ISNA)';
      case CalculationMethod.kuwait:
        return 'Kuwait';
      case CalculationMethod.qatar:
        return 'Qatar';
      case CalculationMethod.singapore:
        return 'Singapore';
      case CalculationMethod.turkey:
        return 'Turkey (Diyanet)';
      case CalculationMethod.tehran:
        return 'Tehran (Iran)';
      case CalculationMethod.other:
        return 'Custom';
    }
  }

  /// Get human-readable name for high latitude rule
  static String highLatitudeRuleDisplay(HighLatitudeRule rule) {
    switch (rule) {
      case HighLatitudeRule.middle_of_the_night:
        return 'Middle of the Night';
      case HighLatitudeRule.seventh_of_the_night:
        return 'Seventh of the Night';
      case HighLatitudeRule.twilight_angle:
        return 'Twilight Angle';
    }
  }

  /// Human readable names for per-sunnah toggles
  static String showDhuhaDisplay(bool enabled) => enabled ? 'Shown' : 'Hidden';
  static String showTahajjudDisplay(bool enabled) =>
      enabled ? 'Shown' : 'Hidden';
}
