import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kiblat/services/ad_service.dart';
import 'package:kiblat/screens/home_topbar.dart';
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/widgets/prayer_heatmap.dart';
import 'package:kiblat/services/location_service.dart';
import 'package:kiblat/widgets/ad_countdown_overlay.dart';

class PrayerTrackerScreen extends StatefulWidget {
  const PrayerTrackerScreen({super.key});

  @override
  State<PrayerTrackerScreen> createState() => _PrayerTrackerScreenState();
}

class _PrayerTrackerScreenState extends State<PrayerTrackerScreen> {
  List<String> _completedPrayersToday = [];
  Map<String, List<String>> _prayerHistory = {};
  final List<String> _prayerKeys = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha', 'dhuha', 'tahajjud'];
  String _historyFilter = '7_days'; // '7_days', '30_days', '1_year'

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadData();
    _loadBannerAd();
    SettingsService.instance.notifier.addListener(_onSettingsChanged);
  }

  void _loadBannerAd() async {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      _disposeBannerAd();
      return;
    }
    if (_bannerAd != null) return;

    if (!AdService.isInitialized) {
      await AdService.initialize();
    }

    _bannerAd = BannerAd(
      adUnitId: AdService.prayerLogBannerUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[PrayerTracker] Banner loaded successfully');
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('[PrayerTracker] Banner failed: $err');
          ad.dispose();
          _bannerAd = null;
          if (mounted) setState(() => _bannerLoaded = false);
          
          // Retry after 30 seconds
          Future.delayed(const Duration(seconds: 30), () {
            if (mounted) _loadBannerAd();
          });
        },
      ),
    )..load();
  }

  void _disposeBannerAd() {
    _bannerAd?.dispose();
    _bannerAd = null;
    _bannerLoaded = false;
  }

  void _onSettingsChanged() {
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) {
      if (_bannerAd != null) {
        setState(() => _disposeBannerAd());
      }
    } else {
      _loadBannerAd();
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    SettingsService.instance.notifier.removeListener(_onSettingsChanged);
    _bannerAd?.dispose();
    super.dispose();
  }

  String _formatDateKey(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDateKey(DateTime.now());
    final completedToday = prefs.getStringList('prayer_tracker_$todayKey') ?? [];

    final Map<String, List<String>> history = {};
    int daysToLoad = 365; 
    for (int i = 1; i <= daysToLoad; i++) {
      final prevDate = DateTime.now().subtract(Duration(days: i));
      final prevKey = _formatDateKey(prevDate);
      final data = prefs.getStringList('prayer_tracker_$prevKey');
      if (data != null) {
        history[prevKey] = data;
      }
    }

    if (mounted) {
      setState(() {
        _completedPrayersToday = completedToday;
        _prayerHistory = history;
      });
    }
  }

  Future<void> _togglePrayer(String prayerKey) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDateKey(DateTime.now());
    final currentList = List<String>.from(_completedPrayersToday);
    final settings = SettingsService.instance.notifier.value;

    if (currentList.contains(prayerKey)) {
      currentList.remove(prayerKey);
    } else {
      currentList.add(prayerKey);
      // Save location for Pro users
      if (settings.isProUser) {
        final loc = await LocationService.getLastLocation();
        if (loc != null) {
          await LocationService.savePrayerLocation(
            todayKey,
            prayerKey,
            loc['lat'],
            loc['lon'],
            loc['label'],
          );
        }
      }
    }
    await prefs.setStringList('prayer_tracker_$todayKey', currentList);
    await _loadData();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, settings, _) {
        final bg = AppTheme.getBackgroundColor(settings, context);
        final card = AppTheme.getCardColor(settings, context);
        final accent = AppTheme.getAccentColor(settings, context);
        final text = AppTheme.getTextColor(settings, context);
        final secText = AppTheme.getSecondaryTextColor(settings, context);
        final border = AppTheme.getBorderColor(settings, context);

        final regularPrayers = _completedPrayersToday.where((k) => !['dhuha', 'tahajjud'].contains(k)).toList();
        final completedCount = regularPrayers.length;
        final progressValue = completedCount / 5.0;

        return AdCountdownOverlay(
          screenName: 'prayer_tracker',
          child: Scaffold(
            backgroundColor: bg,
            body: SafeArea(
              child: Column(
                children: [
                  HomeTopBar(
                    title: tr('prayer_tracker_title'),
                    onSettingsTap: () => Navigator.of(context).pushNamed('/settings'),
                  ),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: _loadData,
                      color: accent,
                      backgroundColor: card,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                        children: [
                          _buildSectionTitle(tr('today_prayer_log'), accent),
                          const SizedBox(height: 12),
                          _buildChecklist(card, border, accent, text, secText, settings),
                          const SizedBox(height: 24),
                          _buildSummaryCard(completedCount, progressValue, accent, card, text),
                          const SizedBox(height: 24),
                          if (settings.isProUser) ...[
                            _buildProInsightSection(accent, card, text, border, settings),
                            const SizedBox(height: 24),
                          ],
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildSectionTitle(tr('prayer_history'), accent),
                              if (settings.isProUser)
                                _buildHistoryFilter(accent, text, card),
                            ],
                          ),
                          const SizedBox(height: 12),
                          _buildHistory(card, border, text, accent, secText),
                          const SizedBox(height: 24),
                          _buildSectionTitle(tr('prayer_heatmap'), accent),
                          const SizedBox(height: 12),
                          PrayerHeatmap(history: _prayerHistory, todayPrayers: _completedPrayersToday),
                        ],
                      ),
                    ),
                  ),
                  if (!settings.isProUser && _bannerAd != null)
                    Container(
                      alignment: Alignment.center,
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      color: bg,
                      child: _bannerLoaded 
                          ? AdWidget(ad: _bannerAd!) 
                          : const SizedBox.shrink(),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSummaryCard(int regularCount, double regularProgress, Color accent, Color card, Color text) {
    bool isAllDone = regularCount == 5;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [accent.withValues(alpha: 0.15), accent.withValues(alpha: 0.04)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accent.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isAllDone ? "🌟 ${tr('alhamdulillah')}" : "☀️ ${tr('today')}", 
                    style: TextStyle(color: accent, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(tr('prayers_count_fmt', namedArgs: {'count': '$regularCount'}), 
                    style: TextStyle(color: text, fontSize: 28, fontWeight: FontWeight.w900)),
                ],
              ),
              CircleAvatar(
                radius: 32,
                backgroundColor: accent.withValues(alpha: 0.15),
                child: Text("${(regularProgress * 100).toInt()}%", style: TextStyle(color: accent, fontWeight: FontWeight.w900)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(value: regularProgress, minHeight: 8, 
              backgroundColor: accent.withValues(alpha: 0.12), valueColor: AlwaysStoppedAnimation<Color>(accent)),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryFilter(Color accent, Color text, Color card) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        color: card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.2)),
      ),
      child: DropdownButton<String>(
        value: _historyFilter,
        underline: const SizedBox(),
        icon: Icon(Icons.filter_list, size: 16, color: accent),
        style: TextStyle(color: text, fontSize: 12, fontWeight: FontWeight.bold),
        items: [
          DropdownMenuItem(value: '7_days', child: Text(tr('filter_7_days'))),
          DropdownMenuItem(value: '30_days', child: Text(tr('filter_30_days'))),
          DropdownMenuItem(value: '1_year', child: Text(tr('filter_1_year'))),
        ],
        onChanged: (val) {
          if (val != null) setState(() => _historyFilter = val);
        },
      ),
    );
  }

  Widget _buildProInsightSection(Color accent, Color card, Color text, Color border, PrayerSettings settings) {
    int streak = _calculateStreak();
    int totalMonth = _calculateMonthlyTotal();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(tr('prayer_insights').toUpperCase(), 
                  style: TextStyle(color: text, fontSize: 14, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ],
            ),
            IconButton(
              icon: Icon(Icons.ios_share, size: 20, color: accent),
              onPressed: () => _exportLogs(settings),
              tooltip: tr('export_logs'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            _insightCard(Icons.local_fire_department, tr('streak'), "$streak ${tr('days')}", Colors.orangeAccent, card, text, border),
            const SizedBox(width: 12),
            _insightCard(Icons.calendar_month, tr('this_month'), "$totalMonth ${tr('prayers_short')}", accent, card, text, border),
          ],
        ),
      ],
    );
  }

  Widget _insightCard(IconData icon, String label, String value, Color color, Color card, Color text, Color border) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16), border: Border.all(color: border)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: text.withValues(alpha: 0.6), fontSize: 11)),
            const SizedBox(height: 4),
            Text(value, style: TextStyle(color: text, fontWeight: FontWeight.w900, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  int _calculateStreak() {
    int streak = 0;
    if (_completedPrayersToday.where((k) => !['dhuha', 'tahajjud'].contains(k)).length == 5) {
      streak++;
    }
    for (int i = 1; i <= 30; i++) {
      final key = _formatDateKey(DateTime.now().subtract(Duration(days: i)));
      final data = _prayerHistory[key] ?? [];
      if (data.where((k) => !['dhuha', 'tahajjud'].contains(k)).length == 5) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  int _calculateMonthlyTotal() {
    int total = _completedPrayersToday.length;
    for (var list in _prayerHistory.values) {
      total += list.length;
    }
    return total;
  }

  Future<void> _exportLogs(PrayerSettings settings) async {
    final sortedKeys = _prayerHistory.keys.toList()..sort((a, b) => b.compareTo(a));
    
    String exportText = "";
    String fileExtension = "csv";

    // Ask user for format if Pro? Actually let's just provide both or JSON if they prefer.
    // User asked for JSON export for Pro users.
    if (settings.isProUser) {
      final Map<String, dynamic> exportData = {
        "app": "Kiblat",
        "version": "2.1.1",
        "exported_at": DateTime.now().toIso8601String(),
        "today": {
          "date": _formatDateKey(DateTime.now()),
          "completed": _completedPrayersToday
        },
        "history": _prayerHistory
      };
      exportText = const JsonEncoder.withIndent('  ').convert(exportData);
      fileExtension = "json";
    } else {
      StringBuffer csv = StringBuffer();
      csv.writeln("Date,Prayers");
      csv.writeln("${_formatDateKey(DateTime.now())},\"${_completedPrayersToday.join(', ')}\"");
      for (var key in sortedKeys) {
        csv.writeln("$key,\"${_prayerHistory[key]!.join(', ')}\"");
      }
      exportText = csv.toString();
      fileExtension = "csv";
    }

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(settings, context),
        title: Text("${tr('export_logs')} ($fileExtension)", style: TextStyle(color: AppTheme.getTextColor(settings, context))),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Text(exportText, style: TextStyle(color: AppTheme.getSecondaryTextColor(settings, context), fontSize: 10, fontFamily: 'monospace')),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('dismiss'))),
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: exportText));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('copied_to_clipboard'))));
            },
            child: Text(tr('copy')),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, Color accent) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: accent,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        ),
      ],
    );
  }

  Widget _buildChecklist(Color card, Color border, Color accent, Color text, Color secText, PrayerSettings settings) {
    final activeKeys = List<String>.from(_prayerKeys);
    final todayKey = _formatDateKey(DateTime.now());
    if (!settings.showSunnahTimes) {
      activeKeys.remove('dhuha');
      activeKeys.remove('tahajjud');
    } else {
      if (!settings.showDhuha) activeKeys.remove('dhuha');
      if (!settings.showTahajjud) activeKeys.remove('tahajjud');
    }

    return Column(
      children: activeKeys.map((pKey) {
        final done = _completedPrayersToday.contains(pKey);
        final isSunnah = ['dhuha', 'tahajjud'].contains(pKey);
        
        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Material(
            color: done ? accent.withValues(alpha: 0.08) : card,
            borderRadius: BorderRadius.circular(16),
            child: InkWell(
              onTap: () => _togglePrayer(pKey),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: done ? accent.withValues(alpha: 0.5) : border,
                    width: done ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      done ? Icons.check_circle : Icons.radio_button_unchecked,
                      color: done ? (isSunnah ? Colors.amber : accent) : secText.withValues(alpha: 0.5),
                      size: 26,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            tr(pKey),
                            style: TextStyle(
                              color: done ? text : text.withValues(alpha: 0.7),
                              fontWeight: done ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 15,
                            ),
                          ),
                          if (isSunnah)
                            Text(
                              tr('sunnah_prayer'),
                              style: const TextStyle(fontSize: 10, color: Colors.amber, fontWeight: FontWeight.bold),
                            ),
                        ],
                      ),
                    ),
                    if (done && settings.isProUser)
                      IconButton(
                        icon: Icon(Icons.location_on_outlined, size: 20, color: accent.withValues(alpha: 0.7)),
                        onPressed: () => _showLocationInfo(todayKey, pKey, settings),
                      ),
                    if (done)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), 
                        decoration: BoxDecoration(
                          color: (isSunnah ? Colors.amber : accent).withValues(alpha: 0.15), 
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Text(
                          tr('completed').toUpperCase(),
                          style: TextStyle(color: isSunnah ? Colors.amber : accent, fontSize: 9, fontWeight: FontWeight.w900),
                        )
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  void _showLocationInfo(String dateKey, String prayerKey, PrayerSettings settings) async {
    final loc = await LocationService.getPrayerLocation(dateKey, prayerKey);
    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(settings, context),
        title: Text(tr('location_history'), style: TextStyle(color: AppTheme.getTextColor(settings, context))),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loc != null) ...[
              Icon(Icons.location_on, color: AppTheme.getAccentColor(settings, context), size: 40),
              const SizedBox(height: 12),
              Text(loc['label']!, textAlign: TextAlign.center, style: TextStyle(color: AppTheme.getTextColor(settings, context), fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text("${loc['lat']}, ${loc['lon']}", style: TextStyle(color: AppTheme.getSecondaryTextColor(settings, context), fontSize: 12)),
            ] else
              Text(tr('no_location_history'), style: TextStyle(color: AppTheme.getSecondaryTextColor(settings, context))),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tr('dismiss'))),
        ],
      ),
    );
  }

  Widget _buildHistory(Color card, Color border, Color text, Color accent, Color secText) {
    int daysToShow = 7;
    if (_historyFilter == '30_days') daysToShow = 30;
    if (_historyFilter == '1_year') daysToShow = 365;
    final settings = SettingsService.instance.notifier.value;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(20), border: Border.all(color: border)),
      child: Column(
        children: List.generate(daysToShow, (index) {
          final date = DateTime.now().subtract(Duration(days: index + 1));
          final key = _formatDateKey(date);
          final completed = _prayerHistory[key] ?? [];
          
          if (index >= 7 && completed.isEmpty) return const SizedBox.shrink();

          int regularDone = completed.where((k) => !['dhuha', 'tahajjud'].contains(k)).length;

          return InkWell(
            onTap: settings.isProUser && completed.isNotEmpty 
              ? () => _showDayLocationDetails(key, date, completed, settings) 
              : null,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(DateFormat('EEEE, dd MMM', context.locale.toString()).format(date), style: TextStyle(color: text, fontSize: 13)),
                  Row(
                    children: [
                      if (settings.isProUser && completed.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Icon(Icons.location_on_outlined, size: 12, color: accent.withValues(alpha: 0.5)),
                        ),
                      Text("$regularDone/5", style: TextStyle(color: regularDone == 5 ? accent : secText, fontWeight: FontWeight.bold, fontSize: 13)),
                      const SizedBox(width: 8),
                      Row(children: _prayerKeys.map((pk) {
                        final done = completed.contains(pk);
                        final isSunnah = ['dhuha', 'tahajjud'].contains(pk);
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 2), 
                          width: 8, height: 8, 
                          decoration: BoxDecoration(
                            shape: BoxShape.circle, 
                            color: done ? (isSunnah ? Colors.amber : accent) : secText.withValues(alpha: 0.2)
                          )
                        );
                      }).toList()),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  void _showDayLocationDetails(String dateKey, DateTime date, List<String> completed, PrayerSettings settings) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.getCardColor(settings, context),
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(DateFormat('EEEE, dd MMMM yyyy', context.locale.toString()).format(date), 
              style: TextStyle(color: AppTheme.getTextColor(settings, context), fontWeight: FontWeight.bold, fontSize: 18)),
            const SizedBox(height: 16),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: _prayerKeys.where((pk) => completed.contains(pk)).map((pk) => FutureBuilder<Map<String, String>?>(
                  future: LocationService.getPrayerLocation(dateKey, pk),
                  builder: (context, snapshot) {
                    final loc = snapshot.data;
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(Icons.check_circle, color: ['dhuha', 'tahajjud'].contains(pk) ? Colors.amber : AppTheme.getAccentColor(settings, context)),
                      title: Text(tr(pk), style: TextStyle(color: AppTheme.getTextColor(settings, context), fontWeight: FontWeight.w600)),
                      subtitle: Text(loc != null ? loc['label']! : tr('no_location_history'), 
                        style: TextStyle(color: AppTheme.getSecondaryTextColor(settings, context), fontSize: 12)),
                      trailing: loc != null ? Icon(Icons.location_on, color: AppTheme.getAccentColor(settings, context), size: 16) : null,
                    );
                  },
                )).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
