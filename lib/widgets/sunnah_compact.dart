import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;

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
            color: const Color.fromRGBO(255, 255, 255, 0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: const Color.fromRGBO(255, 255, 255, 0.06),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _iconForPrayer(p.name),
                color: const Color(0xFFD4AF37),
                size: 14,
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    localized,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    p.timeString,
                    style: const TextStyle(
                      color: Colors.white60,
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
                const Icon(Icons.star, color: Color(0xFFD4AF37), size: 16),
                const SizedBox(width: 8),
                Text(
                  EasyLocalization.of(context) != null
                      ? tr('sunnah_times')
                      : 'Sunnah times',
                  style: const TextStyle(
                    color: Color(0xFFD4AF37),
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
                    style: const TextStyle(
                      color: Colors.white60,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 6),
                  AnimatedRotation(
                    turns: _expanded ? 0.5 : 0.0,
                    duration: _animDuration,
                    child: const Icon(
                      Icons.expand_more,
                      color: Colors.white60,
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
                          ? (p.name == widget.activePrayer!.name &&
                                p.time == widget.activePrayer!.time)
                          : p.isActive(now);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: _smallPrayerCard(p, icon, isActive, isSunrise),
                      );
                    }).toList(),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
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

  Widget _smallPrayerCard(
    ps.PrayerTime prayer,
    IconData iconData,
    bool isActive,
    bool isSunrise,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromRGBO(212, 175, 55, 0.1)
            : isSunrise
            ? const Color.fromRGBO(255, 255, 255, 0.02)
            : const Color.fromRGBO(255, 255, 255, 0.05),
        border: Border.all(
          color: isActive
              ? const Color(0xFFD4AF37)
              : const Color.fromRGBO(255, 255, 255, 0.1),
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? const Color(0xFFD4AF37)
                  : const Color.fromRGBO(212, 175, 55, 0.08),
            ),
            child: Icon(
              iconData,
              color: isActive
                  ? const Color(0xFF050505)
                  : const Color(0xFFD4AF37),
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prayer.name,
                  style: TextStyle(
                    color: isActive
                        ? Colors.white
                        : const Color.fromRGBO(255, 255, 255, 0.9),
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  prayer.subtitle,
                  style: TextStyle(
                    color: isActive
                        ? const Color.fromRGBO(212, 175, 55, 0.8)
                        : const Color.fromRGBO(255, 255, 255, 0.3),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          Text(
            prayer.timeString,
            style: TextStyle(
              color: isActive
                  ? const Color(0xFFD4AF37)
                  : const Color.fromRGBO(255, 255, 255, 0.9),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
