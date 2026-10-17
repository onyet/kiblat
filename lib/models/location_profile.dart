import 'dart:convert';

/// Saved location for Pro multi-location profiles (not prayer log history).
class LocationProfile {
  final String id;
  final String name;
  final double latitude;
  final double longitude;

  const LocationProfile({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'latitude': latitude,
        'longitude': longitude,
      };

  factory LocationProfile.fromJson(Map<String, dynamic> json) {
    return LocationProfile(
      id: json['id'] as String,
      name: json['name'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
    );
  }

  static List<LocationProfile> listFromJsonString(String? raw) {
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return decoded
          .whereType<Map>()
          .map((e) => LocationProfile.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  static String listToJsonString(List<LocationProfile> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());
}
