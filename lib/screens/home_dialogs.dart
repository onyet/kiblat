// ignore_for_file: use_build_context_synchronously

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';
import '../services/telemetry_service.dart';

class DialogAction {
  final String label;
  final FutureOr<void> Function(BuildContext) onPressed;
  DialogAction(this.label, this.onPressed);
}

/// Show a generic error alert with localized buttons
Future<void> showErrorAlert(
  BuildContext context, {
  required String title,
  required String message,
  List<DialogAction>? actions,
}) async {
  final dialogActions =
      actions ??
      [
        DialogAction(
          tr('ok'),
          (ctx) => Navigator.of(ctx, rootNavigator: true).pop(),
        ),
      ];

  showDialog<void>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: dialogActions
          .map(
            (a) => TextButton(
              onPressed: () => a.onPressed(ctx),
              child: Text(a.label),
            ),
          )
          .toList(),
    ),
  );
}

/// Show the enter coordinates dialog; returns true if user applied coordinates
Future<bool> showEnterCoordinatesDialog(BuildContext context) async {
  final latCtl = TextEditingController();
  final lonCtl = TextEditingController();
  final formKey = GlobalKey<FormState>();

  final res = await showDialog<bool>(
    context: context,
    barrierDismissible: true,
    builder: (ctx) => AlertDialog(
      title: Text(tr('enter_coordinates_title')),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextFormField(
              key: const ValueKey('lat'),
              controller: latCtl,
              decoration: InputDecoration(labelText: tr('latitude')),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null) return tr('invalid_lat');
                if (val < -90 || val > 90) return tr('invalid_lat_range');
                return null;
              },
            ),
            TextFormField(
              key: const ValueKey('lon'),
              controller: lonCtl,
              decoration: InputDecoration(labelText: tr('longitude')),
              keyboardType: const TextInputType.numberWithOptions(
                signed: true,
                decimal: true,
              ),
              validator: (v) {
                final val = double.tryParse(v ?? '');
                if (val == null) return tr('invalid_lon');
                if (val < -180 || val > 180) return tr('invalid_lon_range');
                return null;
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(false),
          child: Text(tr('dismiss')),
        ),
        TextButton(
          onPressed: () async {
            if (formKey.currentState?.validate() != true) return;
            final lat = double.parse(latCtl.text.trim());
            final lon = double.parse(lonCtl.text.trim());

            // Close dialog before performing async work to avoid using dialog BuildContext across awaits
            Navigator.of(ctx, rootNavigator: true).pop(true);

            // Apply manual coordinates (save in background)
            await LocationService.saveLastLocation(
              'Manual: ${lat.toStringAsFixed(3)}, ${lon.toStringAsFixed(3)}',
              lat,
              lon,
            );
            TelemetryService.instance.logEvent('manual_coords_saved', {
              'lat': lat,
              'lon': lon,
            });
          },
          child: Text(tr('apply')),
        ),
      ],
    ),
  );

  return res == true;
}

/// Show options when reverse geocoding failed. Callbacks are used to apply cached/manual coordinates
Future<void> showGeocodeFailureOptions(
  BuildContext context,
  Position pos, {
  required void Function(String label, double lat, double lon) onUseCached,
}) async {
  final cached = await LocationService.getLastLocation();

  final actions = <DialogAction>[];

  actions.add(
    DialogAction(tr('retry'), (ctx) async {
      Navigator.of(ctx, rootNavigator: true).pop();
      // caller will handle retry by calling the location controller
    }),
  );

  if (cached != null) {
    actions.add(
      DialogAction(tr('use_cached'), (ctx) {
        Navigator.of(ctx, rootNavigator: true).pop();
        onUseCached(cached['label'], cached['lat'], cached['lon']);
      }),
    );
  }

  actions.add(
    DialogAction(tr('enter_coordinates'), (ctx) async {
      Navigator.of(ctx, rootNavigator: true).pop();
      // Schedule follow-up to avoid using dialog BuildContext across async gaps
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        showEnterCoordinatesDialog(context).then((applied) async {
          if (!applied) return;
          final last = await LocationService.getLastLocation();
          if (last != null) {
            onUseCached(last['label'], last['lat'], last['lon']);
          }
        });
      });
    }),
  );

  actions.add(
    DialogAction(tr('open_location_settings'), (ctx) async {
      Navigator.of(ctx, rootNavigator: true).pop();
      await LocationService.openLocationSettings();
    }),
  );

  actions.add(
    DialogAction(
      tr('dismiss'),
      (ctx) => Navigator.of(ctx, rootNavigator: true).pop(),
    ),
  );

  await showErrorAlert(
    context,
    title: tr('location_unavailable_title'),
    message: tr('geocode_failed_msg'),
    actions: actions,
  );
}
