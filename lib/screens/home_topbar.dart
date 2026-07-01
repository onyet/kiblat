import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';

/// Unified top bar widget displaying current location or a custom title,
/// and a settings button. Now includes AR trigger and GPS refresh.
class HomeTopBar extends StatelessWidget {
  final String? locationLabel;
  final String? title;
  final VoidCallback onSettingsTap;
  final VoidCallback? onArTap;
  final VoidCallback? onRefreshTap;
  final bool showArIcon;
  final bool isRefreshing;

  const HomeTopBar({
    super.key,
    this.locationLabel,
    this.title,
    required this.onSettingsTap,
    this.onArTap,
    this.onRefreshTap,
    this.showArIcon = false,
    this.isRefreshing = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final bgColor = AppTheme.getBackgroundColor(settings, context);
    final cardColor = AppTheme.getCardColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: bgColor,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Left: AR Qibla Icon
          SizedBox(
            width: 40,
            height: 40,
            child: showArIcon 
              ? Material(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    onTap: onArTap,
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Icon(Icons.view_in_ar, color: accentColor, size: 22),
                        if (!settings.isProUser)
                          Positioned(
                            top: 6,
                            right: 6,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.amber,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                )
              : const SizedBox(width: 40),
          ),

          // Center content: Location or Title
          Expanded(
            child: GestureDetector(
              onTap: onRefreshTap,
              behavior: HitTestBehavior.opaque,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (locationLabel != null) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (isRefreshing)
                          Container(
                            margin: const EdgeInsets.only(right: 6),
                            width: 10,
                            height: 10,
                            child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                          )
                        else
                          Icon(
                            Icons.location_on,
                            size: 14,
                            color: accentColor,
                          ),
                        const SizedBox(width: 6),
                        Text(
                          tr('current_location').toUpperCase(),
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: secTextColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            locationLabel!,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ),
                        if (onRefreshTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(Icons.refresh, size: 14, color: secTextColor.withValues(alpha: 0.5)),
                        ],
                      ],
                    ),
                  ] else if (title != null)
                    Text(
                      title!.toUpperCase(),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 1.2,
                        color: textColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                ],
              ),
            ),
          ),

          // Right: Settings button
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              child: InkWell(
                onTap: onSettingsTap,
                borderRadius: BorderRadius.circular(10),
                child: Icon(
                  Icons.settings,
                  color: secTextColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
