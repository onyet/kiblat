import 'dart:convert';

/// Missed prayer (qada) debt entry — distinct from completed heatmap logs.
class QadaEntry {
  final String id;
  final String prayerKey; // fajr, dhuhr, ...
  final String missedDate; // yyyy-MM-dd
  final bool completed;
  final String? completedAt; // ISO8601

  const QadaEntry({
    required this.id,
    required this.prayerKey,
    required this.missedDate,
    this.completed = false,
    this.completedAt,
  });

  QadaEntry copyWith({
    bool? completed,
    String? completedAt,
    bool clearCompletedAt = false,
  }) {
    return QadaEntry(
      id: id,
      prayerKey: prayerKey,
      missedDate: missedDate,
      completed: completed ?? this.completed,
      completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'prayerKey': prayerKey,
        'missedDate': missedDate,
        'completed': completed,
        'completedAt': completedAt,
      };

  factory QadaEntry.fromJson(Map<String, dynamic> json) {
    return QadaEntry(
      id: json['id'] as String,
      prayerKey: json['prayerKey'] as String,
      missedDate: json['missedDate'] as String,
      completed: json['completed'] as bool? ?? false,
      completedAt: json['completedAt'] as String?,
    );
  }

  static List<QadaEntry> listFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => QadaEntry.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<QadaEntry> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
}
