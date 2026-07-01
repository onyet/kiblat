import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';

class SunnahCompact extends StatefulWidget {
  final List<ps.PrayerTime> sunnahList;
  final ps.PrayerTime? activePrayer;

  const SunnahCompact({super.key, required this.sunnahList, this.activePrayer});

  @override
  State<SunnahCompact> createState() => _SunnahCompactState();
}

class _SunnahCompactState extends State<SunnahCompact>
    with TickerProviderStateMixin {
  bool _expanded = false;
  final Duration _animDuration = const Duration(milliseconds: 280);

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, settings, _) {
        final isLight = AppTheme.isLight(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);
        final textColor = AppTheme.getTextColor(settings, context);
        final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
        final cardColor = AppTheme.getCardColor(settings, context);
        final borderColor = isLight ? Colors.black.withValues(alpha: 0.08) : AppTheme.getBorderColor(settings, context);

        final chips = widget.sunnahList.map((p) {
          final nameKey = p.name.toLowerCase();
          final localized =
              (EasyLocalization.of(context) != null && tr(nameKey) != nameKey)
              ? tr(nameKey)
              : p.name;
          return GestureDetector(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: isLight ? Colors.black.withValues(alpha: 0.04) : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isLight ? Colors.black.withValues(alpha: 0.08) : Colors.white.withValues(alpha: 0.06),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _iconForPrayer(p.name),
                    color: accentColor,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        localized,
                        style: TextStyle(
                          color: textColor.withValues(alpha: 0.9),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        p.timeString,
                        style: TextStyle(
                          color: secTextColor.withValues(alpha: 0.9),
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }).toList();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.star, color: accentColor, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      EasyLocalization.of(context) != null
                          ? tr('sunnah_times')
                          : 'Sunnah times',
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                GestureDetector(
                  onTap: () => setState(() => _expanded = !_expanded),
                  child: Row(
                    children: [
                      Text(
                        _expanded
                            ? (EasyLocalization.of(context) != null
                                  ? tr('view_full_schedule')
                                  : 'VIEW FULL SCHEDULE')
                            : (EasyLocalization.of(context) != null
                                  ? (tr('view_sunnah') == 'view_sunnah'
                                        ? 'View Sunnah'
                                        : tr('view_sunnah'))
                                  : 'View Sunnah'),
                        style: TextStyle(
                          color: secTextColor.withValues(alpha: 0.8),
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      AnimatedRotation(
                        turns: _expanded ? 0.5 : 0.0,
                        duration: _animDuration,
                        child: Icon(
                          Icons.expand_more,
                          color: secTextColor.withValues(alpha: 0.8),
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(children: chips),
            ),
            AnimatedSize(
              duration: _animDuration,
              curve: Curves.easeInOut,
              child: _expanded
                  ? Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Column(
                        children: widget.sunnahList.map((p) {
                          final icon = _iconForPrayer(p.name);
                          final isSunrise = p.name.toLowerCase() == 'sunrise';
                          final now = DateTime.now();
                          final isActive = widget.activePrayer != null
                              ? (p.name.toLowerCase() == widget.activePrayer!.name.toLowerCase() &&
                                  (p.time.isAtSameMomentAs(widget.activePrayer!.time) ||
                                      (p.time.difference(widget.activePrayer!.time).inSeconds).abs() <= 86400))
                              : p.isActive(now);
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _smallPrayerCard(
                              p, 
                              icon, 
                              isActive, 
                              isSunrise,
                              accentColor,
                              textColor,
                              secTextColor,
                              cardColor,
                              borderColor,
                              isLight,
                            ),
                          );
                        }).toList(),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        );
      },
    );
  }

  IconData _iconForPrayer(String name) {
    switch (name.toLowerCase()) {
      case 'fajr':
        return Icons.wb_twilight;
      case 'dhuhr':
        return Icons.wb_sunny;
      case 'asr':
        return Icons.sunny;
      case 'maghrib':
        return Icons.wb_twilight;
      case 'isha':
        return Icons.bedtime;
      case 'sunrise':
        return Icons.sunny_snowing;
      default:
        return Icons.access_time;
    }
  }

  // Localized subtitle helper used by both build and small cards
  String _localizedSubtitle(String raw) {
    final key = raw.toLowerCase();
    if (EasyLocalization.of(context) != null && tr(key) != key) return tr(key);
    final s = raw.replaceAll('_', ' ').toLowerCase();
    return s[0].toUpperCase() + s.substring(1);
  }

  Widget _smallPrayerCard(
    ps.PrayerTime prayer,
    IconData iconData,
    bool isActive,
    bool isSunrise,
    Color accentColor,
    Color textColor,
    Color secTextColor,
    Color cardColor,
    Color borderColor,
    bool isLight,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: 0.1)
            : (isSunrise
                ? cardColor.withValues(alpha: 0.4)
                : cardColor),
        border: Border.all(
          color: isActive
              ? accentColor
              : (isSunrise ? Colors.transparent : borderColor),
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: isLight && !isSunrise && !isActive ? [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          )
        ] : null,
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? accentColor
                  : accentColor.withValues(alpha: 0.08),
            ),
            child: Icon(
              iconData,
              color: isActive
                  ? Colors.white
                  : accentColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (EasyLocalization.of(context) != null && tr(prayer.name.toLowerCase()) != prayer.name.toLowerCase())
                      ? tr(prayer.name.toLowerCase())
                      : prayer.name,
                  style: TextStyle(
                    color: isActive ? textColor : textColor.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _localizedSubtitle(prayer.subtitle),
                  style: TextStyle(
                    color: isActive
                        ? accentColor.withValues(alpha: 0.8)
                        : secTextColor.withValues(alpha: 0.7),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                prayer.timeString,
                style: TextStyle(
                  color: isActive
                      ? accentColor
                      : textColor.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              if (isActive) const SizedBox(height: 4),
              if (isActive)
                Text(
                  tr('status_active').toUpperCase(),
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
