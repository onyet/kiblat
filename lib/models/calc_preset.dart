import 'dart:convert';
import 'package:adhan/adhan.dart';

/// Named calculation preset (Pro): method + madhab + high-lat + adjustment + timezone.
class CalcPreset {
  final String id;
  final String name;
  final Madhab madhab;
  final CalculationMethod calculationMethod;
  final HighLatitudeRule highLatitudeRule;
  final int adjustmentMinutes;
  final String? timezoneId;

  const CalcPreset({
    required this.id,
    required this.name,
    required this.madhab,
    required this.calculationMethod,
    required this.highLatitudeRule,
    this.adjustmentMinutes = 0,
    this.timezoneId,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'madhab': madhab.name,
        'calculationMethod': calculationMethod.name,
        'highLatitudeRule': highLatitudeRule.name,
        'adjustmentMinutes': adjustmentMinutes,
        'timezoneId': timezoneId,
      };

  factory CalcPreset.fromJson(Map<String, dynamic> json) {
    return CalcPreset(
      id: json['id'] as String,
      name: json['name'] as String,
      madhab: Madhab.values.firstWhere(
        (e) => e.name == json['madhab'],
        orElse: () => Madhab.shafi,
      ),
      calculationMethod: CalculationMethod.values.firstWhere(
        (e) => e.name == json['calculationMethod'],
        orElse: () => CalculationMethod.muslim_world_league,
      ),
      highLatitudeRule: HighLatitudeRule.values.firstWhere(
        (e) => e.name == json['highLatitudeRule'],
        orElse: () => HighLatitudeRule.middle_of_the_night,
      ),
      adjustmentMinutes: json['adjustmentMinutes'] as int? ?? 0,
      timezoneId: json['timezoneId'] as String?,
    );
  }

  static List<CalcPreset> listFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => CalcPreset.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<CalcPreset> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
}
