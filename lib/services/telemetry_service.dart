import 'package:flutter/foundation.dart';
import 'package:kiblat/services/settings_service.dart';

/// Lightweight telemetry helper for QA and debugging.
/// Currently logs to console. Can be extended to integrate analytics later.
class TelemetryService {
  static TelemetryService? _instance;
  static TelemetryService get instance => _instance ??= TelemetryService._();
  TelemetryService._();

  void logEvent(String name, [Map<String, dynamic>? params]) {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser || !kDebugMode) return;
    debugPrint('[Telemetry] $name ${params ?? {}}');
  }

  void trackExitAttempt({required bool confirmed}) {
    logEvent('exit_attempt', {'confirmed': confirmed});
  }

  void trackAdResult({required bool shown}) {
    logEvent('exit_ad_result', {'shown': shown});
  }

  void trackExitCompleted() {
    logEvent('exit_completed');
  }
}
