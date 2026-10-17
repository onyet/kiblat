import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/models/location_profile.dart';

/// Pro: saved location profiles + optional GPS override for prayer calc / widget.
class LocationProfileService {
  LocationProfileService._();
  static final LocationProfileService instance = LocationProfileService._();

  static const _profilesKey = 'pro_location_profiles';
  static const _activeIdKey = 'pro_active_location_profile_id';
  static const _followGpsKey = 'pro_follow_gps';
  static const maxProfiles = 5;

  final ValueNotifier<List<LocationProfile>> profilesNotifier =
      ValueNotifier([]);
  final ValueNotifier<String?> activeProfileIdNotifier = ValueNotifier(null);
  final ValueNotifier<bool> followGpsNotifier = ValueNotifier(true);

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    profilesNotifier.value =
        LocationProfile.listFromJsonString(prefs.getString(_profilesKey));
    activeProfileIdNotifier.value = prefs.getString(_activeIdKey);
    followGpsNotifier.value = prefs.getBool(_followGpsKey) ?? true;
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _profilesKey,
      LocationProfile.listToJsonString(profilesNotifier.value),
    );
    final id = activeProfileIdNotifier.value;
    if (id == null) {
      await prefs.remove(_activeIdKey);
    } else {
      await prefs.setString(_activeIdKey, id);
    }
    await prefs.setBool(_followGpsKey, followGpsNotifier.value);
  }

  LocationProfile? get activeProfile {
    final id = activeProfileIdNotifier.value;
    if (id == null) return null;
    try {
      return profilesNotifier.value.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  /// When follow GPS is off and a profile is selected, use that lat/lon.
  Future<({double lat, double lon, String label})?> overrideCoordinates() async {
    if (followGpsNotifier.value) return null;
    final p = activeProfile;
    if (p == null) return null;
    return (lat: p.latitude, lon: p.longitude, label: p.name);
  }

  Future<bool> addProfile(LocationProfile profile) async {
    if (profilesNotifier.value.length >= maxProfiles) return false;
    profilesNotifier.value = [...profilesNotifier.value, profile];
    await _persist();
    return true;
  }

  Future<void> removeProfile(String id) async {
    profilesNotifier.value =
        profilesNotifier.value.where((p) => p.id != id).toList();
    if (activeProfileIdNotifier.value == id) {
      activeProfileIdNotifier.value = null;
      followGpsNotifier.value = true;
    }
    await _persist();
  }

  Future<void> setActiveProfile(String? id) async {
    activeProfileIdNotifier.value = id;
    if (id != null) followGpsNotifier.value = false;
    await _persist();
  }

  Future<void> setFollowGps(bool follow) async {
    followGpsNotifier.value = follow;
    if (follow) activeProfileIdNotifier.value = null;
    await _persist();
  }
}
