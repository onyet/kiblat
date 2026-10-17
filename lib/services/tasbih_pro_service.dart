import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class TasbihWirid {
  final String id;
  final String name;
  final int target;

  const TasbihWirid({
    required this.id,
    required this.name,
    required this.target,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'target': target};

  factory TasbihWirid.fromJson(Map<String, dynamic> json) => TasbihWirid(
        id: json['id'] as String,
        name: json['name'] as String,
        target: json['target'] as int? ?? 33,
      );
}

class TasbihSession {
  final String wiridId;
  final String wiridName;
  final int count;
  final String completedAt;

  const TasbihSession({
    required this.wiridId,
    required this.wiridName,
    required this.count,
    required this.completedAt,
  });

  Map<String, dynamic> toJson() => {
        'wiridId': wiridId,
        'wiridName': wiridName,
        'count': count,
        'completedAt': completedAt,
      };

  factory TasbihSession.fromJson(Map<String, dynamic> json) => TasbihSession(
        wiridId: json['wiridId'] as String,
        wiridName: json['wiridName'] as String,
        count: json['count'] as int? ?? 0,
        completedAt: json['completedAt'] as String,
      );
}

/// Pro tasbih: custom wirid list, daily target, session history (local only).
class TasbihProService {
  TasbihProService._();
  static final TasbihProService instance = TasbihProService._();

  static const _wiridKey = 'pro_tasbih_wirids';
  static const _sessionsKey = 'pro_tasbih_sessions';
  static const _dailyTargetKey = 'pro_tasbih_daily_target';
  static const _dailyCountKey = 'pro_tasbih_daily_count';
  static const _dailyDateKey = 'pro_tasbih_daily_date';

  final ValueNotifier<List<TasbihWirid>> wiridsNotifier = ValueNotifier([]);
  final ValueNotifier<List<TasbihSession>> sessionsNotifier = ValueNotifier([]);
  final ValueNotifier<int> dailyTargetNotifier = ValueNotifier(100);
  final ValueNotifier<int> dailyCountNotifier = ValueNotifier(0);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final wiridRaw = prefs.getString(_wiridKey);
    if (wiridRaw != null && wiridRaw.isNotEmpty) {
      try {
        final list = jsonDecode(wiridRaw) as List;
        wiridsNotifier.value = list
            .whereType<Map>()
            .map((e) => TasbihWirid.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {
        wiridsNotifier.value = _defaults();
      }
    } else {
      wiridsNotifier.value = _defaults();
    }

    final sessRaw = prefs.getString(_sessionsKey);
    if (sessRaw != null && sessRaw.isNotEmpty) {
      try {
        final list = jsonDecode(sessRaw) as List;
        sessionsNotifier.value = list
            .whereType<Map>()
            .map((e) => TasbihSession.fromJson(Map<String, dynamic>.from(e)))
            .toList();
      } catch (_) {}
    }

    dailyTargetNotifier.value = prefs.getInt(_dailyTargetKey) ?? 100;
    final today = _todayKey();
    if (prefs.getString(_dailyDateKey) == today) {
      dailyCountNotifier.value = prefs.getInt(_dailyCountKey) ?? 0;
    } else {
      dailyCountNotifier.value = 0;
      await prefs.setString(_dailyDateKey, today);
      await prefs.setInt(_dailyCountKey, 0);
    }
  }

  List<TasbihWirid> _defaults() => const [
        TasbihWirid(id: 'subhanallah', name: 'Subhanallah', target: 33),
        TasbihWirid(id: 'alhamdulillah', name: 'Alhamdulillah', target: 33),
        TasbihWirid(id: 'allahuakbar', name: 'Allahu Akbar', target: 34),
      ];

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _persistWirids() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _wiridKey,
      jsonEncode(wiridsNotifier.value.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> _persistSessions() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _sessionsKey,
      jsonEncode(sessionsNotifier.value.map((e) => e.toJson()).toList()),
    );
  }

  Future<void> setDailyTarget(int target) async {
    dailyTargetNotifier.value = target;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_dailyTargetKey, target);
  }

  Future<void> addCount(int delta) async {
    dailyCountNotifier.value += delta;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dailyDateKey, _todayKey());
    await prefs.setInt(_dailyCountKey, dailyCountNotifier.value);
  }

  Future<void> addWirid(TasbihWirid wirid) async {
    wiridsNotifier.value = [...wiridsNotifier.value, wirid];
    await _persistWirids();
  }

  Future<void> removeWirid(String id) async {
    wiridsNotifier.value =
        wiridsNotifier.value.where((w) => w.id != id).toList();
    await _persistWirids();
  }

  Future<void> recordSession(TasbihWirid wirid, int count) async {
    final session = TasbihSession(
      wiridId: wirid.id,
      wiridName: wirid.name,
      count: count,
      completedAt: DateTime.now().toIso8601String(),
    );
    sessionsNotifier.value = [session, ...sessionsNotifier.value].take(50).toList();
    await _persistSessions();
    await addCount(count);
  }
}
