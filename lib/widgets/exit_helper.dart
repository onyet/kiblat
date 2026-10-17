// ignore_for_file: use_build_context_synchronously

import 'dart:io';
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';

import '../utils/theme_util.dart';
import '../services/settings_service.dart';
import '../services/ad_service.dart';
import '../services/telemetry_service.dart';

/// Shows an exit confirmation dialog and, on confirmation, attempts to
/// show an interstitial ad while displaying a small loading state.
/// Regardless of ad success/failure, the app will exit afterwards.
Future<void> showExitAndMaybeShowAd(
  BuildContext context, {
  Duration adTimeout = const Duration(seconds: 4),
}) async {
  final settings = SettingsService.instance.notifier.value;

  // Use a single dialog that swaps content to a loading state when the user
  // confirms. StatefulBuilder allows local state inside the dialog.
  final result = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) {
      final isLight = AppTheme.isLight(settings, context);
      final textColor = AppTheme.getTextColor(settings, context);
      final cardColor = AppTheme.getCardColor(settings, context);
      final accentColor = AppTheme.getAccentColor(settings, context);

      return AlertDialog(
        backgroundColor: cardColor,
        title: Text(
          tr('exit_confirm_title'),
          style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
        ),
        content: Text(
          tr('exit_confirm_msg'),
          style: TextStyle(color: textColor.withValues(alpha: 0.8)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
            child: Text(tr('stay')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accentColor,
              foregroundColor: isLight ? Colors.white : Colors.black,
            ),
            onPressed: () {
              // Track confirmed attempt
              TelemetryService.instance.trackExitAttempt(confirmed: true);
              Navigator.of(ctx, rootNavigator: true).pop(true);
            },
            child: Text(tr('exit'),
                style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
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
