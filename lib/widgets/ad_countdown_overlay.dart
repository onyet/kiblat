import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/services/ad_service.dart';
import 'package:kiblat/services/settings_service.dart';

/// An overlay widget that shows a 5-second countdown before displaying an interstitial ad.
/// Only displays for non-pro users.
class AdCountdownOverlay extends StatefulWidget {
  final Widget child;
  final String screenName;

  const AdCountdownOverlay({
    super.key,
    required this.child,
    required this.screenName,
  });

  @override
  State<AdCountdownOverlay> createState() => _AdCountdownOverlayState();
}

class _AdCountdownOverlayState extends State<AdCountdownOverlay> {

  @override
  void initState() {
    super.initState();
    _maybeTriggerAd();
  }

  @override
  void dispose() {
    super.dispose();
  }

  void _maybeTriggerAd() async {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) return;

    // Check if this is the first launch after install
    final prefs = await SharedPreferences.getInstance();
    final bool adSkippedOnFirstLaunch = prefs.getBool('first_launch_ad_skipped') ?? false;

    if (!adSkippedOnFirstLaunch) {
      debugPrint('[AdOverlay] First launch detected, skipping ad to improve UX');
      await prefs.setBool('first_launch_ad_skipped', true);
      return;
    }

    // Logic: 25% chance to show an ad when opening the screen
    // but only if an ad is actually ready.
    final bool shouldShow = AdService.instance.isInterstitialAdReady && 
                           (DateTime.now().millisecond % 4 == 0);

    if (shouldShow) {
      // Defer slightly to ensure smooth transition, but NO countdown
      await Future.delayed(const Duration(milliseconds: 1500));
      if (!mounted) return;

      // Show the ad directly or log for future triggering
      // We remove the blocking 5-second countdown entirely.
      await AdService.instance.showInterstitialAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
