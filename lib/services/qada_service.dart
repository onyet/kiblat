import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/models/qada_entry.dart';

class QadaService {
  QadaService._();
  static final QadaService instance = QadaService._();

  static const _key = 'pro_qada_entries';

  final ValueNotifier<List<QadaEntry>> entriesNotifier = ValueNotifier([]);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    entriesNotifier.value =
        QadaEntry.listFromJsonString(prefs.getString(_key));
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _key,
      QadaEntry.listToJsonString(entriesNotifier.value),
    );
  }

  List<QadaEntry> get pending =>
      entriesNotifier.value.where((e) => !e.completed).toList();

  Future<void> addMissed({
    required String prayerKey,
    required String missedDate,
  }) async {
    final id =
        '${missedDate}_${prayerKey}_${DateTime.now().millisecondsSinceEpoch}';
    entriesNotifier.value = [
      ...entriesNotifier.value,
      QadaEntry(id: id, prayerKey: prayerKey, missedDate: missedDate),
    ];
    await _persist();
  }

  Future<void> markCompleted(String id) async {
    entriesNotifier.value = entriesNotifier.value.map((e) {
      if (e.id != id) return e;
      return e.copyWith(
        completed: true,
        completedAt: DateTime.now().toIso8601String(),
      );
    }).toList();
    await _persist();
  }

  Future<void> remove(String id) async {
    entriesNotifier.value =
        entriesNotifier.value.where((e) => e.id != id).toList();
    await _persist();
  }
}
