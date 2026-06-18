import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';

/// Dedicated screen for Prayer Tracker (Catatan Sholat).
/// Accessible from the bottom nav bar (3rd tab) and from PrayerTimesScreen shortcut.
class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({super.key});

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  List<String> _completedPrayersToday = [];
  Map<String, List<String>> _weeklyPrayerHistory = {};

  final List<String> _prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  String _formatDateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDateKey(DateTime.now());
    final completedToday = prefs.getStringList('prayer_tracker_$todayKey') ?? [];

    final Map<String, List<String>> history = {};
    for (int i = 1; i <= 7; i++) {
      final prevDate = DateTime.now().subtract(Duration(days: i));
      final prevKey = _formatDateKey(prevDate);
      history[prevKey] = prefs.getStringList('prayer_tracker_$prevKey') ?? [];
    }

    if (mounted) {
      setState(() {
        _completedPrayersToday = completedToday;
        _weeklyPrayerHistory = history;
      });
    }
  }

  Future<void> _togglePrayer(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDateKey(DateTime.now());
    final currentList = List<String>.from(_completedPrayersToday);
    if (currentList.contains(prayerKey)) {
      currentList.remove(prayerKey);
    } else {
      currentList.add(prayerKey);
    }
    await prefs.setStringList('prayer_tracker_$todayKey', currentList);
    await _loadData();
  }

  String _localizedPrayerName(String key) {
    // Use translation system — all prayer keys (fajr, dhuhr, asr, maghrib, isha) are in all lang files
    final localized = EasyLocalization.of(context) != null ? tr(key) : key;
    if (localized == key) {
      // Last-resort fallback (should never happen if translations are complete)
      const fallback = {
        'fajr': 'Fajr',
        'dhuhr': 'Dhuhr',
        'asr': 'Asr',
        'maghrib': 'Maghrib',
        'isha': 'Isha',
      };
      return fallback[key] ?? key;
    }
    return localized;
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final bgColor = AppTheme.getBackgroundColor(settings, context);
    final cardColor = AppTheme.getCardColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);

    final completedCount = _completedPrayersToday.length;
    final progressValue = completedCount / 5.0;

    return ValueListenableBuilder(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, s, _) {
        final bg = AppTheme.getBackgroundColor(s, context);
        final card = AppTheme.getCardColor(s, context);
        final accent = AppTheme.getAccentColor(s, context);
        final text = AppTheme.getTextColor(s, context);
        final secText = AppTheme.getSecondaryTextColor(s, context);
        final border = AppTheme.getBorderColor(s, context);

        return Scaffold(
          backgroundColor: bg,
          appBar: AppBar(
            backgroundColor: bg,
            elevation: 0,
            leading: IconButton(
              icon: Icon(Icons.chevron_left, color: text, size: 28),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title: Text(
              EasyLocalization.of(context) != null
                  ? tr('prayer_tracker_title')
                  : 'Prayer Log',
              style: TextStyle(
                color: text,
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: RefreshIndicator(
            onRefresh: _loadData,
            color: accent,
            backgroundColor: card,
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              children: [
                // ── Today's summary card ──────────────────────────
                _buildSummaryCard(
                  completedCount: completedCount,
                  progressValue: progressValue,
                  accent: accent,
                  card: card,
                  text: text,
                  secText: secText,
                  border: border,
                ),

                const SizedBox(height: 24),

                // ── Today's checklist ─────────────────────────────
                Text(
                  EasyLocalization.of(context) != null
                      ? tr('today_prayer_log')
                      : 'Today\'s Prayer Log',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _prayerKeys.length,
                    separatorBuilder: (_, __) =>
                        Divider(color: border, height: 1),
                    itemBuilder: (context, index) {
                      final pKey = _prayerKeys[index];
                      final isCompleted =
                          _completedPrayersToday.contains(pKey);
                      return _buildPrayerTile(
                        pKey: pKey,
                        isCompleted: isCompleted,
                        accent: accent,
                        text: text,
                        secText: secText,
                        border: border,
                      );
                    },
                  ),
                ),

                const SizedBox(height: 28),

                // ── 7-day history ─────────────────────────────────
                Text(
                  EasyLocalization.of(context) != null
                      ? tr('last_7_days_history')
                      : 'Last 7 Days History',
                  style: TextStyle(
                    color: text,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: card,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: border),
                  ),
                  child: Column(
                    children: List.generate(7, (index) {
                      final prevDate =
                          DateTime.now().subtract(Duration(days: index + 1));
                      final dateKey = _formatDateKey(prevDate);
                      final completed =
                          _weeklyPrayerHistory[dateKey] ?? [];
                      final count = completed.length;
                      final formattedDate = DateFormat(
                        'EEEE, dd MMM',
                        context.locale.toString(),
                      ).format(prevDate);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment:
                              MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                formattedDate,
                                style: TextStyle(
                                  color: text,
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Row(
                              children: [
                                Text(
                                  '$count/5',
                                  style: TextStyle(
                                    color: count == 5
                                        ? accent
                                        : secText,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Row(
                                  children: _prayerKeys.map((pKey) {
                                    final done =
                                        completed.contains(pKey);
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                          horizontal: 2),
                                      width: 8,
                                      height: 8,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: done
                                            ? accent
                                            : secText.withValues(alpha: 0.2),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard({
    required int completedCount,
    required double progressValue,
    required Color accent,
    required Color card,
    required Color text,
    required Color secText,
    required Color border,
  }) {
    final isAllDone = completedCount == 5;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            accent.withValues(alpha: 0.15),
            accent.withValues(alpha: 0.04),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isAllDone
                        ? '🌟 ${EasyLocalization.of(context) != null ? tr('alhamdulillah_label') : 'Alhamdulillah!'}'
                        : '☀️ ${EasyLocalization.of(context) != null ? tr('today_label') : 'Today'}',
                    style: TextStyle(
                      color: accent,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    EasyLocalization.of(context) != null
                        ? tr('prayers_count_fmt', namedArgs: {'count': '$completedCount'})
                        : '$completedCount / 5 Prayers',
                    style: TextStyle(
                      color: text,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              CircleAvatar(
                radius: 32,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Text(
                  '${(progressValue * 100).toInt()}%',
                  style: TextStyle(
                    color: accent,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progressValue,
              minHeight: 8,
              backgroundColor: accent.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrayerTile({
    required String pKey,
    required bool isCompleted,
    required Color accent,
    required Color text,
    required Color secText,
    required Color border,
  }) {
    return ListTile(
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: GestureDetector(
        onTap: () => _togglePrayer(pKey),
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Icon(
            isCompleted ? Icons.check_circle : Icons.radio_button_unchecked,
            key: ValueKey(isCompleted),
            color: isCompleted ? accent : secText,
            size: 28,
          ),
        ),
      ),
      title: Text(
        _localizedPrayerName(pKey),
        style: TextStyle(
          color: isCompleted ? text : text.withValues(alpha: 0.65),
          fontWeight: isCompleted ? FontWeight.w700 : FontWeight.normal,
          fontSize: 16,
          decoration:
              isCompleted ? TextDecoration.none : TextDecoration.none,
        ),
      ),
      trailing: isCompleted
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                EasyLocalization.of(context) != null
                    ? tr('completed')
                    : 'Completed',
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          : null,
      onTap: () => _togglePrayer(pKey),
    );
  }
}
