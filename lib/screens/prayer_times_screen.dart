import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/services/location_service.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/hijri_converter.dart';
import 'package:kiblat/widgets/sunnah_compact.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:kiblat/screens/prayer_tracker_screen.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with TickerProviderStateMixin {
  int _selectedTabIndex = 0;

  // Live data
  bool _loading = true;
  String _error = '';

  double? _latitude;
  double? _longitude;
  double? _qiblaDeg;
  String _locationLabel = '';

  ps.DailyPrayerTimes? _todayPrayers;
  ps.DailyPrayerTimes? _tomorrowPrayers;
  List<ps.DailyPrayerTimes> _weekPrayers = [];

  PrayerSettings? _settings;
  List<String> _completedPrayersToday = [];
  Map<String, List<String>> _weeklyPrayerHistory = {};

  // Active prayer / countdown state
  Timer? _countdownTimer;
  ps.PrayerTime? _activePrayer;
  ps.PrayerTime? _nextPrayer;
  Duration _timeToNext = Duration.zero;
  double _progressToNext = 0.0;
  bool _refreshingPrevNext = false;

  DateTime get _todayDate => DateTime.now();
  DateTime get _tomorrowDate => DateTime.now().add(const Duration(days: 1));

  String _getQiblaDirection(double degrees) {
    if (degrees >= 337.5 || degrees < 22.5) return 'N';
    if (degrees >= 22.5 && degrees < 67.5) return 'NE';
    if (degrees >= 67.5 && degrees < 112.5) return 'E';
    if (degrees >= 112.5 && degrees < 157.5) return 'SE';
    if (degrees >= 157.5 && degrees < 202.5) return 'S';
    if (degrees >= 202.5 && degrees < 247.5) return 'SW';
    if (degrees >= 247.5 && degrees < 292.5) return 'W';
    return 'NW';
  }

  // Localize a subtitle key or prettify a raw subtitle string
  String _localizedSubtitle(String raw) {
    final key = raw.toLowerCase();
    if (EasyLocalization.of(context) != null && tr(key) != key) return tr(key);
    final s = key.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  /// Load location, settings, and compute prayer times for today, tomorrow and this week
  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      // Location
      final pos = await LocationService.getCurrentPosition();
      _latitude = pos.latitude;
      _longitude = pos.longitude;
      _locationLabel = await LocationService.reverseGeocodeWithCache(
        _latitude!,
        _longitude!,
      );
      _qiblaDeg = LocationService.qiblaBearing(_latitude!, _longitude!);

      // Settings
      _settings = await PrayerSettings.load();

      // Today & tomorrow
      _todayPrayers = await ps.PrayerService.calculatePrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: DateTime(_todayDate.year, _todayDate.month, _todayDate.day),
        settings: _settings!,
      );

      _tomorrowPrayers = await ps.PrayerService.calculatePrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: DateTime(
          _tomorrowDate.year,
          _tomorrowDate.month,
          _tomorrowDate.day,
        ),
        settings: _settings!,
      );

      // Week
      _weekPrayers = [];
      for (var i = 0; i < 7; i++) {
        final d = DateTime.now().add(Duration(days: i));
        final dt = await ps.PrayerService.calculatePrayerTimes(
          latitude: _latitude!,
          longitude: _longitude!,
          date: DateTime(d.year, d.month, d.day),
          settings: _settings!,
        );
        _weekPrayers.add(dt);
      }

      // Persist last known location label
      if (_locationLabel.isNotEmpty) {
        await LocationService.saveLastLocation(
          _locationLabel,
          _latitude!,
          _longitude!,
        );
      }

      // Update previous/next prayer references and start countdown
      await _updatePrevNext();
      _startCountdownUpdater();

      if (!mounted) return;
      setState(() {
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load prayer times: ${e.toString()}';
      });
    }
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

  @override
  void initState() {
    super.initState();
    _loadAll();
    _loadPrayerTrackerData();
    // Refresh when global settings change (e.g., 24/12h format)
    SettingsService.instance.notifier.addListener(_onSettingsChanged);
  }

  void _onSettingsChanged() {
    // Reload everything so formatted times update according to new settings
    _loadAll();
  }

  @override
  Widget build(BuildContext context) {
    final settings = _settings ?? SettingsService.instance.notifier.value;

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(settings, context),
      body: SafeArea(
        child: Column(
          children: [
            // Header with back button and location
            _buildHeader(),

            // Tabs
            _buildTabs(),

            // Main content
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _loadAll(),
                child: ListView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  children: [
                    // Islamic and Gregorian dates
                    _buildDateSection(),

                    const SizedBox(height: 24),

                    // Body content
                    if (_loading)
                      Center(
                        child: Column(
                          children: [
                            const SizedBox(height: 40),
                            CircularProgressIndicator(
                              color: AppTheme.getAccentColor(
                                _settings ?? SettingsService.instance.notifier.value,
                                context,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              EasyLocalization.of(context) != null
                                  ? tr('calculating')
                                  : 'Loading prayer times...',
                              style: TextStyle(
                                color: AppTheme.getSecondaryTextColor(
                                  _settings ?? SettingsService.instance.notifier.value,
                                  context,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else if (_error.isNotEmpty)
                      Center(
                        child: Text(
                          _error,
                          style: const TextStyle(color: Colors.redAccent),
                        ),
                      )
                    else ...[
                      if (_selectedTabIndex != 2) _buildCountdownBanner(),

                      if (_selectedTabIndex == 2)
                        _buildWeekView()
                      else
                        _buildDayView(
                          _selectedTabIndex == 0
                              ? _todayPrayers
                              : _tomorrowPrayers,
                          isToday: _selectedTabIndex == 0,
                        ),

                      const SizedBox(height: 32),

                      _buildQiblaCard(),

                      const SizedBox(height: 40),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final bgColor = AppTheme.getBackgroundColor(settings, context);
    final cardColor = AppTheme.getCardColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);

    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: bgColor,
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Location
          Expanded(
            child: Column(
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.location_on,
                      size: 14,
                      color: accentColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      EasyLocalization.of(context) != null
                          ? tr('current_location').toUpperCase()
                          : 'CURRENT LOCATION',
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
                Text(
                  _locationLabel.isNotEmpty ? _locationLabel : '...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // Settings button (right)
          SizedBox(
            width: 40,
            height: 40,
            child: Material(
              color: cardColor,
              borderRadius: BorderRadius.circular(8),
              child: InkWell(
                onTap: () => Navigator.of(context).pushNamed('/settings'),
                borderRadius: BorderRadius.circular(8),
                child: Icon(
                  Icons.settings,
                  color: textColor,
                  size: 20,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final borderColor = AppTheme.getBorderColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: borderColor),
        ),
      ),
      child: Row(
        children: [
          _buildTabButton('today', 0),
          const SizedBox(width: 4),
          _buildTabButton('tomorrow', 1),
          const SizedBox(width: 4),
          _buildTabButton('this_week', 2),
          const Spacer(),
          // Shortcut to Prayer Tracker screen
          GestureDetector(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => const PrayerTrackerScreen(),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              margin: const EdgeInsets.only(bottom: 12),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.assignment_outlined, color: accentColor, size: 14),
                  const SizedBox(width: 4),
                  Text(
                    EasyLocalization.of(context) != null ? tr('catatan') : 'Catatan',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: accentColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabButton(String labelKey, int index) {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);

    final isActive = _selectedTabIndex == index;
    final label = (EasyLocalization.of(context) != null && tr(labelKey) != labelKey)
        ? tr(labelKey)
        : labelKey[0].toUpperCase() + labelKey.substring(1);
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive
                  ? accentColor
                  : secTextColor,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 24,
            color: isActive ? accentColor : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);

    final date = _selectedTabIndex == 0
        ? _todayDate
        : (_selectedTabIndex == 1 ? _tomorrowDate : _todayDate);
    final hijri = HijriConverter.getHijriDate(date);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('prayer_schedule') == 'prayer_schedule'
                  ? 'ISLAMIC DATE'
                  : tr('prayer_schedule'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: accentColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hijri.toFormattedStringArabic(),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              EasyLocalization.of(context) != null
                  ? tr('gregorian').toUpperCase()
                  : 'GREGORIAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: secTextColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              HijriConverter.formatGregorianShort(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: secTextColor,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrayerCardsForList(List<ps.PrayerTime> prayersList, {bool isToday = true}) {
    return Column(
      children: prayersList.map((prayer) {
        final iconData = _iconForPrayer(prayer.name);
        final now = DateTime.now();
        final isSunrise = prayer.name.toLowerCase() == 'sunrise';
        // Only show active status for today's prayers — not tomorrow or future days.
        // Robust active detection: match by name case-insensitively and allow
        // a wide tolerance (up to 24 hours) to handle active prayers that
        // belong to the previous day (e.g., Isha after midnight).
        final isActive = isToday
            ? (_activePrayer != null
                ? (prayer.name.toLowerCase() == _activePrayer!.name.toLowerCase() &&
                    (prayer.time.isAtSameMomentAs(_activePrayer!.time) ||
                        (prayer.time.difference(_activePrayer!.time).inSeconds).abs() <= 86400))
                : prayer.isActive(now))
            : false;

        // Debug: print per-prayer active evaluation
        debugPrint('[PrayerTimes] buildPrayerCard: name=${prayer.name} time=${prayer.time.toIso8601String()} isActive=$isActive activeCache=${_activePrayer?.name ?? 'null'}@${_activePrayer?.time.toIso8601String() ?? 'null'}');

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPrayerCardFromModel(
            prayer,
            iconData,
            isActive,
            isSunrise,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildDayView(ps.DailyPrayerTimes? day, {bool isToday = true}) {
    if (day == null) return const SizedBox.shrink();

    final sunnah = day.prayers.where((p) => p.isSunnah).toList();
    final regular = day.prayers.where((p) => !p.isSunnah).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_settings?.showSunnahTimes == true && sunnah.isNotEmpty) ...[
          SunnahCompact(sunnahList: sunnah, activePrayer: isToday ? _activePrayer : null),
          const SizedBox(height: 12),
        ],
        _buildPrayerCardsForList(regular, isToday: isToday),
      ],
    );
  }

  Widget _buildWeekView() {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final textColor = AppTheme.getTextColor(settings, context);

    return Column(
      children: _weekPrayers.map((day) {
        final dateStr = HijriConverter.formatGregorianShort(day.date);
        final now = DateTime.now();
        final dayIsToday = day.date.year == now.year &&
            day.date.month == now.month &&
            day.date.day == now.day;
        final sunnah = day.prayers.where((p) => p.isSunnah).toList();
        final regular = day.prayers.where((p) => !p.isSunnah).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              dateStr,
              style: TextStyle(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            if (_settings?.showSunnahTimes == true && sunnah.isNotEmpty) ...[
              SunnahCompact(sunnahList: sunnah, activePrayer: dayIsToday ? _activePrayer : null),
              const SizedBox(height: 8),
            ],
            _buildPrayerCardsForList(regular, isToday: dayIsToday),
            const SizedBox(height: 18),
          ],
        );
      }).toList(),
    );
  }

  Widget _buildPrayerCardFromModel(
    ps.PrayerTime prayer,
    IconData iconData,
    bool isActive,
    bool isSunrise,
  ) {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final cardColor = AppTheme.getCardColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);
    final isLight = AppTheme.isLight(settings, context);

    // For sunnah times we slightly reduce opacity and add a tiny badge
    final isSunnah = prayer.isSunnah;

    // Get localized prayer name
    final nameKey = prayer.name.toLowerCase();
    final localized = (EasyLocalization.of(context) != null && tr(nameKey) != nameKey)
        ? tr(nameKey)
        : prayer.name;

    final time = prayer.timeString;

    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isActive
            ? accentColor.withValues(alpha: 0.12)
            : (isSunnah || isSunrise
                ? cardColor.withValues(alpha: 0.6)
                : cardColor),
        border: Border.all(
          color: isActive
              ? accentColor
              : borderColor,
          width: isActive ? 2 : 1,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isActive
                  ? accentColor
                  : accentColor.withValues(alpha: 0.1),
            ),
            child: Icon(
              iconData,
              color: isActive
                  ? (isLight ? Colors.white : const Color(0xFF050505))
                  : accentColor,
              size: 20,
            ),
          ),

          const SizedBox(width: 20),

          // Prayer name and subtitle
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  localized,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: textColor,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _localizedSubtitle(prayer.subtitle),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: isActive
                        ? accentColor
                        : secTextColor,
                  ),
                ),
              ],
            ),
          ),

          // Time and inline ACTIVE label (for better visibility)
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time,
                style: TextStyle(
                  fontSize: isActive ? 22 : 18,
                  fontWeight: FontWeight.w700,
                  color: isSunnah
                      ? secTextColor
                      : (isActive
                            ? accentColor
                            : textColor),
                  letterSpacing: -0.5,
                ),
              ),
              if (isActive)
                const SizedBox(height: 4),
              if (isActive)
                Text(
                  tr('status_active').toUpperCase(),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w900,
                    color: accentColor,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    // Active badge
    if (isActive) {
      card = Stack(
        children: [
          card,
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: accentColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tr('status_active').toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: isLight ? Colors.white : const Color(0xFF050505),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return card;
  }

  Widget _buildQiblaCard() {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final cardColor = AppTheme.getCardColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);
    final isLight = AppTheme.isLight(settings, context);

    final qiblaDeg = _qiblaDeg ?? 0.0;
    final qiblaDir = _getQiblaDirection(qiblaDeg);

    List<Color> gradientColors;
    if (isLight) {
      gradientColors = [cardColor, const Color(0xFFEEEEEE)];
    } else if (settings.compassTheme == 'cyber') {
      gradientColors = [cardColor, const Color(0xFF050B11)];
    } else {
      gradientColors = [cardColor, const Color(0xFF080808)];
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: gradientColors,
        ),
        border: Border.all(color: accentColor.withValues(alpha: 0.25)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  EasyLocalization.of(context) != null
                      ? tr('facing_qibla').toUpperCase()
                      : 'FACING QIBLA',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${qiblaDeg.toStringAsFixed(0)}°',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: textColor,
                        ),
                      ),
                      TextSpan(
                        text:
                            ' $qiblaDir from $_locationLabel',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: secTextColor,
                        ),
                      ),
                    ],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 48,
            height: 48,
            child: Material(
              color: accentColor,
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () {
                  Navigator.of(context).pop();
                },
                borderRadius: BorderRadius.circular(24),
                child: Icon(
                  Icons.explore,
                  color: isLight ? Colors.white : const Color(0xFF050505),
                  size: 24,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    SettingsService.instance.notifier.removeListener(_onSettingsChanged);
    _countdownTimer?.cancel();
    super.dispose();
  }

  /// Update previous and next prayer references using PrayerService
  Future<void> _updatePrevNext() async {
    if (_latitude == null || _longitude == null || _settings == null) return;
    if (_refreshingPrevNext) return;
    _refreshingPrevNext = true;
    try {
      final map = await ps.PrayerService.getPrevAndNextPrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        settings: _settings!,
      );

      final prev = map['previous'];
      final next = map['next'];

      final now = DateTime.now();
      // Consider the previous prayer active if the current time is >= prev.time
      // and (next is null or current time < next.time). This also handles
      // edge cases around midnight or missing next entries.
      final active = (prev != null &&
          (now.isAtSameMomentAs(prev.time) || now.isAfter(prev.time)) &&
          (next == null || now.isBefore(next.time)))
          ? prev
          : null;

      // Debug logging to help diagnose missing ACTIVE badge issues.
      // Will log current time, prev/next prayer names and times, and computed active.
      debugPrint('[PrayerTimes] now=${now.toIso8601String()}');
      debugPrint('[PrayerTimes] prev=${prev?.name ?? 'null'}@${prev?.time.toIso8601String() ?? 'null'}');
      debugPrint('[PrayerTimes] next=${next?.name ?? 'null'}@${next?.time.toIso8601String() ?? 'null'}');
      debugPrint('[PrayerTimes] computedActive=${active?.name ?? 'null'}');

      setState(() {
        _nextPrayer = next;
        _activePrayer = active;
        _timeToNext = next != null ? next.time.difference(now) : Duration.zero;
        _progressToNext = (prev != null && next != null)
            ? ps.PrayerService.progressBetween(prev.time, next.time, now)
            : 0.0;
      });
    } finally {
      _refreshingPrevNext = false;
    }
  }

  void _startCountdownUpdater() {
    _countdownTimer?.cancel();
    // Update every second; actual heavy recomputation only when next is reached
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      final now = DateTime.now();

      if (_nextPrayer == null) return;

      // If we've reached or passed the next prayer, refresh prev/next
      if (now.isAfter(_nextPrayer!.time) ||
          now.isAtSameMomentAs(_nextPrayer!.time)) {
        await _updatePrevNext();
        return;
      }

      // Otherwise update remaining duration and progress
      setState(() {
        _timeToNext = _nextPrayer!.time.difference(now);
        // For progress we need previous; if not available just compute using last known active
        if (_activePrayer != null) {
          _progressToNext = ps.PrayerService.progressBetween(
            _activePrayer!.time,
            _nextPrayer!.time,
            now,
          );
        } else {
          // fallback: progress from now to next is 0..1 based on some heuristic
          _progressToNext = 0.0;
        }
      });
    });
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  Widget _buildCountdownBanner() {
    if (_nextPrayer == null) return const SizedBox.shrink();

    final settings = _settings ?? SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);

    final nameKey = _nextPrayer!.name.toLowerCase();
    final localized = (tr(nameKey) == nameKey)
        ? _nextPrayer!.name
        : tr(nameKey);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: accentColor.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Icon(
                _iconForPrayer(_nextPrayer!.name),
                color: accentColor,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr(
                        'time_to_prayer_fmt',
                        namedArgs: {
                          'dur': _formatDuration(_timeToNext),
                          'prayer': localized,
                        },
                      ),
                      style: TextStyle(
                        color: textColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _progressToNext,
                      backgroundColor: accentColor.withValues(alpha: 0.08),
                      valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _nextPrayer!.timeString,
                style: TextStyle(
                  color: secTextColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  String _formatDateKey(DateTime dt) {
    return "${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}";
  }

  Future<void> _loadPrayerTrackerData() async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDateKey(DateTime.now());
    
    final completedToday = prefs.getStringList('prayer_tracker_$todayKey') ?? [];
    
    final Map<String, List<String>> history = {};
    for (int i = 1; i <= 7; i++) {
      final prevDate = DateTime.now().subtract(Duration(days: i));
      final prevKey = _formatDateKey(prevDate);
      final list = prefs.getStringList('prayer_tracker_$prevKey') ?? [];
      history[prevKey] = list;
    }
    
    if (mounted) {
      setState(() {
        _completedPrayersToday = completedToday;
        _weeklyPrayerHistory = history;
      });
    }
  }

  Future<void> _togglePrayer(String prayerName) async {
    final prefs = await SharedPreferences.getInstance();
    final todayKey = _formatDateKey(DateTime.now());
    
    final currentList = List<String>.from(_completedPrayersToday);
    if (currentList.contains(prayerName)) {
      currentList.remove(prayerName);
    } else {
      currentList.add(prayerName);
    }
    
    await prefs.setStringList('prayer_tracker_$todayKey', currentList);
    
    setState(() {
      _completedPrayersToday = currentList;
    });
    
    await _loadPrayerTrackerData();
  }

  Widget _buildTrackerView() {
    final prayers = ['fajr', 'dhuhr', 'asr', 'maghrib', 'isha'];
    final prayerDisplayNames = {
      'fajr': 'Subuh',
      'dhuhr': 'Dzuhur',
      'asr': 'Ashar',
      'maghrib': 'Maghrib',
      'isha': 'Isya',
    };
    
    final settings = SettingsService.instance.notifier.value;
    final cardColor = AppTheme.getCardColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Catatan Sholat Hari Ini',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: prayers.length,
            separatorBuilder: (context, index) => Divider(color: borderColor, height: 1),
            itemBuilder: (context, index) {
              final pKey = prayers[index];
              final displayName = prayerDisplayNames[pKey]!;
              final isCompleted = _completedPrayersToday.contains(pKey);
              
              return ListTile(
                leading: Icon(
                  isCompleted ? Icons.check_circle : Icons.radio_button_off,
                  color: isCompleted ? accentColor : secTextColor,
                  size: 26,
                ),
                title: Text(
                  displayName,
                  style: TextStyle(
                    color: isCompleted ? textColor : textColor.withOpacity(0.7),
                    fontWeight: isCompleted ? FontWeight.bold : FontWeight.normal,
                    fontSize: 16,
                  ),
                ),
                trailing: isCompleted 
                  ? Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Selesai',
                        style: TextStyle(color: accentColor, fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    )
                  : null,
                onTap: () => _togglePrayer(pKey),
              );
            },
          ),
        ),
        
        const SizedBox(height: 24),
        
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: Text(
            'Riwayat 7 Hari Terakhir',
            style: TextStyle(
              color: textColor,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
          ),
          child: Column(
            children: List.generate(7, (index) {
              final prevDate = DateTime.now().subtract(Duration(days: index + 1));
              final dateKey = _formatDateKey(prevDate);
              final completed = _weeklyPrayerHistory[dateKey] ?? [];
              final count = completed.length;
              final formattedDate = DateFormat('EEEE, dd MMM', context.locale.toString()).format(prevDate);
              
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      formattedDate,
                      style: TextStyle(color: textColor, fontSize: 14),
                    ),
                    Row(
                      children: [
                        Text(
                          '$count/5',
                          style: TextStyle(
                            color: count == 5 ? accentColor : secTextColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Row(
                          children: prayers.map((pKey) {
                            final pDone = completed.contains(pKey);
                            return Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: pDone ? accentColor : secTextColor.withOpacity(0.2),
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
    );
  }
}
