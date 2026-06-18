import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';

/// Small top bar widget displaying current location and a settings button.
class HomeTopBar extends StatelessWidget {
  final String locationLabel;
  final VoidCallback onSettingsTap;

  const HomeTopBar({
    super.key,
    required this.locationLabel,
    required this.onSettingsTap,
  });

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const SizedBox(width: 36), // spacer
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.location_on,
                      color: secTextColor,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        tr('current_location'),
                        style: TextStyle(
                          color: secTextColor,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  locationLabel,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.settings, color: secTextColor),
            onPressed: onSettingsTap,
          ),
        ],
      ),
    );
  }
}
