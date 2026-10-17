import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

enum DzikirPeriod { pagi, petang }

class DzikirItem {
  final String id;
  final String title;
  final String arabic;
  final String latin;
  final String meaning;
  final int repeat;
  final String source;

  const DzikirItem({
    required this.id,
    required this.title,
    required this.arabic,
    required this.latin,
    required this.meaning,
    required this.repeat,
    required this.source,
  });

  factory DzikirItem.fromJson(Map<String, dynamic> json) => DzikirItem(
        id: json['id'] as String,
        title: json['title'] as String? ?? '',
        arabic: json['arabic'] as String? ?? '',
        latin: json['latin'] as String? ?? '',
        meaning: json['meaning'] as String? ?? '',
        repeat: (json['repeat'] as num?)?.toInt() ?? 1,
        source: json['source'] as String? ?? '',
      );
}

/// Offline morning/evening dhikr checklist with per-item repeat counters.
class DzikirService {
  DzikirService._();
  static final DzikirService instance = DzikirService._();

  static const _assetPath = 'assets/dzikir/morning_evening.json';
  static const _progressKey = 'dzikir_progress_v1';
  static const _dateKey = 'dzikir_progress_date';

  final ValueNotifier<List<DzikirItem>> pagiNotifier = ValueNotifier([]);
  final ValueNotifier<List<DzikirItem>> petangNotifier = ValueNotifier([]);
  final ValueNotifier<Map<String, int>> countsNotifier = ValueNotifier({});
  final ValueNotifier<String> attributionNotifier = ValueNotifier('');

  bool _loaded = false;

  /// Test-only: clear cached pack + progress so cases stay isolated.
  @visibleForTesting
  void debugReset() {
    _loaded = false;
    pagiNotifier.value = [];
    petangNotifier.value = [];
    countsNotifier.value = {};
    attributionNotifier.value = '';
  }

  Future<void> load() async {
    if (!_loaded) {
      final raw = await rootBundle.loadString(_assetPath);
      final json = jsonDecode(raw) as Map<String, dynamic>;
      attributionNotifier.value = json['attribution'] as String? ?? '';
      pagiNotifier.value = (json['pagi'] as List)
          .whereType<Map>()
          .map((e) => DzikirItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      petangNotifier.value = (json['petang'] as List)
          .whereType<Map>()
          .map((e) => DzikirItem.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      _loaded = true;
    }
    await _loadOrResetProgress();
  }

  List<DzikirItem> itemsFor(DzikirPeriod period) =>
      period == DzikirPeriod.pagi ? pagiNotifier.value : petangNotifier.value;

  int countFor(String id) => countsNotifier.value[id] ?? 0;

  bool isComplete(DzikirItem item) => countFor(item.id) >= item.repeat;

  int completedCount(DzikirPeriod period) {
    final items = itemsFor(period);
    return items.where(isComplete).length;
  }

  int totalRepeatTarget(DzikirPeriod period) =>
      itemsFor(period).fold<int>(0, (sum, e) => sum + e.repeat);

  int totalRepeatDone(DzikirPeriod period) {
    var sum = 0;
    for (final item in itemsFor(period)) {
      final c = countFor(item.id);
      sum += c > item.repeat ? item.repeat : c;
    }
    return sum;
  }

  Future<void> increment(DzikirItem item) async {
    final current = countFor(item.id);
    if (current >= item.repeat) return;
    final next = Map<String, int>.from(countsNotifier.value);
    next[item.id] = current + 1;
    countsNotifier.value = next;
    await _persistProgress();
  }

  Future<void> resetItem(DzikirItem item) async {
    final next = Map<String, int>.from(countsNotifier.value);
    next.remove(item.id);
    countsNotifier.value = next;
    await _persistProgress();
  }

  Future<void> resetPeriod(DzikirPeriod period) async {
    final next = Map<String, int>.from(countsNotifier.value);
    for (final item in itemsFor(period)) {
      next.remove(item.id);
    }
    countsNotifier.value = next;
    await _persistProgress();
  }

  String _todayKey() {
    final n = DateTime.now();
    return '${n.year}-${n.month.toString().padLeft(2, '0')}-${n.day.toString().padLeft(2, '0')}';
  }

  Future<void> _loadOrResetProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final today = _todayKey();
    if (prefs.getString(_dateKey) != today) {
      countsNotifier.value = {};
      await prefs.setString(_dateKey, today);
      await prefs.setString(_progressKey, '{}');
      return;
    }
    final raw = prefs.getString(_progressKey);
    if (raw == null || raw.isEmpty) {
      countsNotifier.value = {};
      return;
    }
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      countsNotifier.value = map.map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
    } catch (e) {
      debugPrint('[DzikirService] progress parse failed: $e');
      countsNotifier.value = {};
    }
  }

  Future<void> _persistProgress() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_dateKey, _todayKey());
    await prefs.setString(_progressKey, jsonEncode(countsNotifier.value));
  }
}
