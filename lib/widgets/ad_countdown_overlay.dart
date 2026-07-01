import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
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
  bool _showingCountdown = false;
  int _secondsRemaining = 5;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _maybeTriggerAd();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _maybeTriggerAd() async {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) return;

    // Logic: 25% chance to show an ad when opening the screen
    // but only if an ad is actually ready.
    final bool shouldShow = AdService.instance.isInterstitialAdReady && 
                           (DateTime.now().millisecond % 4 == 0);

    if (shouldShow) {
      // Small delay to let screen transition finish
      await Future.delayed(const Duration(milliseconds: 800));
      if (!mounted) return;

      setState(() {
        _showingCountdown = true;
        _secondsRemaining = 5;
      });

      _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
        if (!mounted) {
          timer.cancel();
          return;
        }

        if (_secondsRemaining > 1) {
          setState(() => _secondsRemaining--);
        } else {
          timer.cancel();
          setState(() => _showingCountdown = false);
          // Show the ad
          await AdService.instance.showInterstitialAd();
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showingCountdown)
          Container(
            color: Colors.black.withValues(alpha: 0.8),
            child: Center(
              child: Card(
                color: const Color(0xFF1A1A1A),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: Color(0xFFD4AF37), width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.ads_click, color: Color(0xFFD4AF37), size: 48),
                      const SizedBox(height: 16),
                      Text(
                        tr('ad_starting_soon'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        tr('ad_countdown_fmt', namedArgs: {'sec': '$_secondsRemaining'}),
                        style: const TextStyle(
                          color: Color(0xFFD4AF37),
                          fontWeight: FontWeight.w900,
                          fontSize: 24,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tr('ad_support_note'),
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
