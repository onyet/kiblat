// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../services/ad_service.dart';
import '../services/telemetry_service.dart';

/// Shows an exit confirmation dialog and, on confirmation, attempts to
/// show an interstitial ad while displaying a small loading state.
/// Regardless of ad success/failure, the app will exit afterwards.
Future<void> showExitAndMaybeShowAd(
  BuildContext context, {
  Duration adTimeout = const Duration(seconds: 4),
}) async {
  // Use a single dialog that swaps content to a loading state when the user
  // confirms. StatefulBuilder allows local state inside the dialog.
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      bool isLoading = false;
      double progress = 0.0;
      Timer? timer;
      final int totalMs = adTimeout.inMilliseconds;

      return StatefulBuilder(
        builder: (ctx2, setState) {
          return AlertDialog(
            title: Text(tr('exit_confirm_title')),
            content: isLoading
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(tr('exit_showing_ad')),
                      const SizedBox(height: 12),
                      LinearProgressIndicator(value: progress),
                    ],
                  )
                : Text(tr('exit_confirm_msg')),
            actions: isLoading
                ? null
                : [
                    TextButton(
                      onPressed: () =>
                          Navigator.of(ctx2, rootNavigator: true).pop(false),
                      child: Text(tr('stay')),
                    ),
                    TextButton(
                      onPressed: () async {
                        // Switch to loading state (disables buttons)
                        setState(() {
                          isLoading = true;
                          progress = 0.0;
                        });

                        // Start a timer to animate progress across the ad timeout using eased interpolation
                        final startMs = DateTime.now().millisecondsSinceEpoch;
                        timer = Timer.periodic(const Duration(milliseconds: 50), (
                          t,
                        ) {
                          final elapsed =
                              DateTime.now().millisecondsSinceEpoch - startMs;
                          final double normalized = math.min(
                            1.0,
                            elapsed / totalMs,
                          );
                          // easeOutCubic for smooth finish: f(t) = 1 - (1 - t)^3
                          final eased = 1 - math.pow((1 - normalized), 3);
                          setState(() {
                            progress = eased.toDouble();
                          });
                        });

                        // Track confirmed attempt
                        TelemetryService.instance.trackExitAttempt(
                          confirmed: true,
                        );

                        bool adShown = false;
                        try {
                          adShown = await AdService.instance.showInterstitialAd(
                            timeout: adTimeout,
                          );
                          TelemetryService.instance.trackAdResult(
                            shown: adShown,
                          );
                        } catch (e) {
                          TelemetryService.instance.logEvent('exit_ad_error', {
                            'error': e.toString(),
                          });
                        }

                        // Stop the timer and mark progress complete
                        timer?.cancel();
                        setState(() => progress = 1.0);

                        // Close dialog and return confirmed result
                        Navigator.of(ctx2, rootNavigator: true).pop(true);

                        // Note: exit will be performed after dialog completes (see below)
                      },
                      child: Text(tr('exit')),
                    ),
                  ],
          );
        },
      );
    },
  );

  // If user did not confirm, nothing else to do
  if (result != true) {
    TelemetryService.instance.trackExitAttempt(confirmed: false);
    return;
  }

  // Completed flow, track and exit
  TelemetryService.instance.trackExitCompleted();

  try {
    SystemNavigator.pop();
  } catch (_) {
    try {
      exit(0);
    } catch (_) {}
  }
}
