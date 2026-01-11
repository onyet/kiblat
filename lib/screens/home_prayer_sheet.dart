import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

class HomePrayerSheet extends StatelessWidget {
  final String prayerKey; // localization key e.g. 'maghrib'
  final String prayerTime;
  final String countdownDur; // e.g. '1h 20m'

  const HomePrayerSheet({
    super.key,
    required this.prayerKey,
    required this.prayerTime,
    required this.countdownDur,
  });

  @override
  Widget build(BuildContext context) {
    final prayerName = tr(prayerKey);
    final countdownText = tr('time_to_prayer_fmt', namedArgs: {'dur': countdownDur, 'prayer': prayerName});

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(left: 20, right: 20, bottom: 20),
      padding: const EdgeInsets.all(20),
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
          const SizedBox(height: 12),

          // Icon + Prayer name + Time - centered row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.wb_twilight, color: const Color(0xFFD4AF37), size: 28),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    prayerName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                      fontSize: 24,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    prayerTime,
                    style: const TextStyle(
                      color: Color.fromRGBO(255, 255, 255, 0.5),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Golden countdown badge - centered
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: const Color.fromRGBO(212, 175, 55, 0.12),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: const Color.fromRGBO(212, 175, 55, 0.25)),
            ),
            child: Text(
              countdownText,
              style: const TextStyle(
                color: Color(0xFFD4AF37),
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          const SizedBox(height: 16),

          // Full-width gradient button
          SizedBox(
            width: double.infinity,
            height: 52,
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
                  onTap: () {},
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
                      const SizedBox(width: 8),
                      const Icon(Icons.calendar_today, size: 18, color: Colors.black),
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
