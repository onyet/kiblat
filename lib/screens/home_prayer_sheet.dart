import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class HomePrayerSheet extends StatelessWidget {
  final String prayerKey; // localization key e.g. 'maghrib'
  final String prayerTime;
  final String countdownDur; // e.g. '1h 20m'
  final VoidCallback? onViewFullSchedule;

  const HomePrayerSheet({
    super.key,
    required this.prayerKey,
    required this.prayerTime,
    required this.countdownDur,
    this.onViewFullSchedule,
  });

  @override
  Widget build(BuildContext context) {
    final prayerName = tr(prayerKey);
    final countdownText = tr('time_to_prayer_fmt', namedArgs: {'dur': countdownDur, 'prayer': prayerName});

    // Local helper to map prayer key to IconData (kept consistent with PrayerTimesScreen)
    IconData iconForPrayer(String name) {
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

    final isCompact = MediaQuery.of(context).size.height < 700;

    final horizontalMargin = isCompact ? 16.0 : 20.0;
    final contentPadding = isCompact ? 14.0 : 20.0;
    final titleSpacing = isCompact ? 8.0 : 12.0;
    final iconSize = isCompact ? 22.0 : 28.0;
    final nameFontSize = isCompact ? 20.0 : 24.0;
    final timeFontSize = isCompact ? 12.0 : 14.0;
    final badgeHPadding = isCompact ? 10.0 : 14.0;
    final badgeVPadding = isCompact ? 6.0 : 7.0;
    final badgeFontSize = isCompact ? 12.0 : 13.0;
    final betweenBadgeAndButton = isCompact ? 12.0 : 16.0;
    final buttonHeight = isCompact ? 44.0 : 52.0;

    return Container(
      width: double.infinity,
      margin: EdgeInsets.only(left: horizontalMargin, right: horizontalMargin, bottom: horizontalMargin),
      padding: EdgeInsets.all(contentPadding),
      decoration: BoxDecoration(
        color: const Color(0xFF0A0A0A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color.fromRGBO(212, 175, 55, 0.2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // "NEXT PRAYER" label - centered
          Text(
            tr('next_prayer').toUpperCase(),
            style: TextStyle(
              color: const Color.fromRGBO(212, 175, 55, 0.6),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: titleSpacing),

          // Icon + Prayer name + Time - animated when prayer changes
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutBack,
            switchOutCurve: Curves.easeIn,
            layoutBuilder: (currentChild, previousChildren) => Stack(children: [...previousChildren, if (currentChild != null) currentChild]),
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: ScaleTransition(scale: anim, child: child)),
            child: SizedBox(
              key: ValueKey('${prayerKey}_$prayerTime'),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(iconForPrayer(prayerKey), color: const Color(0xFFD4AF37), size: iconSize),
                  SizedBox(width: isCompact ? 10 : 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        prayerName,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          fontSize: nameFontSize,
                          height: 1.0,
                        ),
                      ),
                      SizedBox(height: isCompact ? 3 : 4),
                      Text(
                        prayerTime,
                        style: TextStyle(
                          color: Color.fromRGBO(255, 255, 255, 0.5),
                          fontSize: timeFontSize,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: isCompact ? 10 : 14),

          // Golden countdown badge - animated only when prayer name changes
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(opacity: anim, child: SlideTransition(position: Tween<Offset>(begin: const Offset(0, 0.2), end: Offset.zero).animate(anim), child: child)),
            child: Container(
              key: ValueKey('badge_$prayerKey'),
              padding: EdgeInsets.symmetric(horizontal: badgeHPadding, vertical: badgeVPadding),
              decoration: BoxDecoration(
                color: const Color.fromRGBO(212, 175, 55, 0.12),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: const Color.fromRGBO(212, 175, 55, 0.25)),
              ),
              child: Text(
                countdownText,
                style: TextStyle(
                  color: const Color(0xFFD4AF37),
                  fontSize: badgeFontSize,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),

          SizedBox(height: betweenBadgeAndButton),

          // Full-width gradient button
          SizedBox(
            width: double.infinity,
            height: buttonHeight,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFFBF953F),
                    const Color(0xFFFCF6BA),
                    const Color(0xFFBF953F),
                  ],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromRGBO(212, 175, 55, 0.3),
                    blurRadius: 20,
                    spreadRadius: -2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: onViewFullSchedule,
                  borderRadius: BorderRadius.circular(14),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tr('view_full_schedule').toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                          fontSize: 13,
                          letterSpacing: 1.0,
                        ),
                      ),
                      SizedBox(width: isCompact ? 6 : 8),
                      Icon(Icons.calendar_today, size: isCompact ? 16 : 18, color: Colors.black),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
