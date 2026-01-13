import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/services/location_service.dart';
import 'package:kiblat/utils/hijri_converter.dart';
import 'package:kiblat/widgets/sunnah_compact.dart';


class PrayerTimesScreen extends StatefulWidget {
  final String locationLabel;
  final double qiblaDeg;

  const PrayerTimesScreen({
    super.key,
    required this.locationLabel,
    required this.qiblaDeg,
  });

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen> with TickerProviderStateMixin {
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
      _locationLabel = await LocationService.reverseGeocodeWithCache(_latitude!, _longitude!);
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
        date: DateTime(_tomorrowDate.year, _tomorrowDate.month, _tomorrowDate.day),
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
        await LocationService.saveLastLocation(_locationLabel, _latitude!, _longitude!);
      }

      // Update previous/next prayer references and start countdown
      await _updatePrevNext();
      _startCountdownUpdater();

      setState(() {
        _loading = false;
      });
    } catch (e) {
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
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  children: [
                    // Islamic and Gregorian dates
                    _buildDateSection(),

                    const SizedBox(height: 24),

                    // Body content
                    if (_loading)
                      Center(child: Column(
                        children: [
                          const SizedBox(height: 40),
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          const Text('Loading prayer times...', style: TextStyle(color: Colors.white60)),
                        ],
                      ))
                    else if (_error.isNotEmpty)
                      Center(child: Text(_error, style: const TextStyle(color: Colors.redAccent)))
                    else ...[
                      if (_selectedTabIndex != 2) _buildCountdownBanner(),

                      if (_selectedTabIndex == 2)
                        _buildWeekView()
                      else
                        _buildDayView(_selectedTabIndex == 0 ? _todayPrayers : _tomorrowPrayers),

                      const SizedBox(height: 32),

                      // Qibla direction card
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
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
      decoration: BoxDecoration(
        color: const Color(0xFF050505),
        border: Border(bottom: BorderSide(color: const Color.fromRGBO(255, 255, 255, 0.05))),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back button
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: const Color.fromRGBO(255, 255, 255, 0.05),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(),
                    borderRadius: BorderRadius.circular(8),
                    child: const Icon(Icons.chevron_left, color: Colors.white, size: 24),
                  ),
                ),
              ),

              // Location (flexible)
              Expanded(
                child: Column(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.location_on, size: 14, color: Colors.white54),
                        const SizedBox(width: 6),
                        Text(
                          'CURRENT LOCATION',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: const Color.fromRGBO(255, 255, 255, 0.6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      widget.locationLabel,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Settings button (right)
              SizedBox(
                width: 40,
                height: 40,
                child: Material(
                  color: const Color.fromRGBO(255, 255, 255, 0.05),
                  borderRadius: BorderRadius.circular(8),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pushNamed('/settings'),
                    borderRadius: BorderRadius.circular(8),
                    child: const Icon(Icons.settings, color: Colors.white, size: 20),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 12),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: const Color.fromRGBO(255, 255, 255, 0.05))),
      ),
      child: Row(
        children: [
          _buildTabButton('TODAY', 0),
          const SizedBox(width: 32),
          _buildTabButton('TOMORROW', 1),
          const SizedBox(width: 32),
          _buildTabButton('THIS WEEK', 2),
        ],
      ),
    );
  }

  Widget _buildTabButton(String label, int index) {
    final isActive = _selectedTabIndex == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: isActive ? const Color(0xFFD4AF37) : const Color.fromRGBO(255, 255, 255, 0.4),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            height: 2,
            width: 24,
            color: isActive ? const Color(0xFFD4AF37) : Colors.transparent,
          ),
        ],
      ),
    );
  }

  Widget _buildDateSection() {
    final date = _selectedTabIndex == 0 ? _todayDate : ( _selectedTabIndex == 1 ? _tomorrowDate : _todayDate );
    final hijri = HijriConverter.getHijriDate(date);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tr('prayer_schedule') == 'prayer_schedule' ? 'ISLAMIC DATE' : tr('prayer_schedule'),
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: const Color(0xFFD4AF37),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              hijri.toFormattedStringArabic(),
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'GREGORIAN',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
                color: const Color.fromRGBO(255, 255, 255, 0.4),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              HijriConverter.formatGregorianShort(date),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: const Color.fromRGBO(255, 255, 255, 0.6),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPrayerCardsForList(List<ps.PrayerTime> prayersList) {
    return Column(
      children: prayersList.map((prayer) {
        final iconData = _iconForPrayer(prayer.name);
        final now = DateTime.now();
        final isSunrise = prayer.name.toLowerCase() == 'sunrise';
        final isActive = _activePrayer != null
            ? (prayer.name == _activePrayer!.name && prayer.time == _activePrayer!.time)
            : prayer.isActive(now);

        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: _buildPrayerCardFromModel(prayer, iconData, isActive, isSunrise),
        );
      }).toList(),
    );
  }

  Widget _buildDayView(ps.DailyPrayerTimes? day) {
    if (day == null) return const SizedBox.shrink();

    final sunnah = day.prayers.where((p) => p.isSunnah).toList();
    final regular = day.prayers.where((p) => !p.isSunnah).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_settings?.showSunnahTimes == true && sunnah.isNotEmpty) ...[
          SunnahCompact(sunnahList: sunnah, activePrayer: _activePrayer),
          const SizedBox(height: 12),
        ],
        _buildPrayerCardsForList(regular),
      ],
    );
  }

  Widget _buildWeekView() {
    return Column(
      children: _weekPrayers.map((day) {
        final dateStr = HijriConverter.formatGregorianShort(day.date);
        final sunnah = day.prayers.where((p) => p.isSunnah).toList();
        final regular = day.prayers.where((p) => !p.isSunnah).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateStr, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            if (_settings?.showSunnahTimes == true && sunnah.isNotEmpty) ...[
              SunnahCompact(sunnahList: sunnah, activePrayer: _activePrayer),
              const SizedBox(height: 8),
            ],
            _buildPrayerCardsForList(regular),
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
    // For sunnah times we slightly reduce opacity and add a tiny badge
    final isSunnah = prayer.isSunnah;
    final subtitle = prayer.subtitle;

    // Get localized prayer name
    final nameKey = prayer.name.toLowerCase();
    final localized = nameKey == 'sunrise' ? 'Sunrise' : (tr(nameKey) == nameKey ? prayer.name : tr(nameKey));

    final time = prayer.timeString;

    Widget card = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: isActive
            ? const Color.fromRGBO(212, 175, 55, 0.1)
            : isSunnah
                ? const Color.fromRGBO(255, 255, 255, 0.02)
                : (isSunrise ? const Color.fromRGBO(255, 255, 255, 0.02) : const Color.fromRGBO(255, 255, 255, 0.05)),
        border: Border.all(
          color: isActive
              ? const Color(0xFFD4AF37)
              : isSunnah
                  ? const Color.fromRGBO(255, 255, 255, 0.06)
                  : const Color.fromRGBO(255, 255, 255, 0.1),
          width: isActive ? 2 : (isSunnah ? 1 : 1),
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
                  ? const Color(0xFFD4AF37)
                  : const Color.fromRGBO(212, 175, 55, 0.1),
            ),
            child: Icon(
              iconData,
              color: isActive ? const Color(0xFF050505) : const Color(0xFFD4AF37),
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
                    color: isActive ? Colors.white : const Color.fromRGBO(255, 255, 255, 0.9),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                    color: isActive
                        ? const Color.fromRGBO(212, 175, 55, 0.8)
                        : const Color.fromRGBO(255, 255, 255, 0.3),
                  ),
                ),
              ],
            ),
          ),

          // Time
          Text(
            time,
            style: TextStyle(
              fontSize: isActive ? 22 : 18,
              fontWeight: FontWeight.w700,
              color: isSunnah
                  ? const Color.fromRGBO(255, 255, 255, 0.6)
                  : (isActive ? const Color(0xFFD4AF37) : const Color.fromRGBO(255, 255, 255, 0.9)),
              letterSpacing: -0.5,
            ),
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
            right: 8,
            top: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFFD4AF37),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                tr('status_active').toUpperCase(),
                style: TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1.0,
                  color: const Color(0xFF050505),
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
    final qiblaDeg = _qiblaDeg ?? widget.qiblaDeg;
    final qiblaDir = _getQiblaDirection(qiblaDeg);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF0A0A0A),
            const Color(0xFF050505),
          ],
        ),
        border: Border.all(
          color: const Color.fromRGBO(212, 175, 55, 0.2),
        ),
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
                  'FACING QIBLA',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                    color: Color(0xFFD4AF37),
                  ),
                ),
                const SizedBox(height: 8),
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: '${qiblaDeg.toStringAsFixed(0)}°',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      TextSpan(
                        text: ' $qiblaDir from ${_locationLabel.isNotEmpty ? _locationLabel : widget.locationLabel}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: const Color.fromRGBO(255, 255, 255, 0.4),
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
              color: const Color(0xFFD4AF37),
              borderRadius: BorderRadius.circular(24),
              child: InkWell(
                onTap: () {
                  // Navigate to compass/qibla screen
                },
                borderRadius: BorderRadius.circular(24),
                child: const Icon(
                  Icons.explore,
                  color: Color(0xFF050505),
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
      final active = (prev != null && next != null && now.isAfter(prev.time) && now.isBefore(next.time)) ? prev : null;

      setState(() {
        _nextPrayer = next;
        _activePrayer = active;
        _timeToNext = next != null ? next.time.difference(now) : Duration.zero;
        _progressToNext = (prev != null && next != null) ? ps.PrayerService.progressBetween(prev.time, next.time, now) : 0.0;
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
      if (now.isAfter(_nextPrayer!.time) || now.isAtSameMomentAs(_nextPrayer!.time)) {
        await _updatePrevNext();
        return;
      }

      // Otherwise update remaining duration and progress
      setState(() {
        _timeToNext = _nextPrayer!.time.difference(now);
        // For progress we need previous; if not available just compute using last known active
        if (_activePrayer != null) {
          _progressToNext = ps.PrayerService.progressBetween(_activePrayer!.time, _nextPrayer!.time, now);
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

    final nameKey = _nextPrayer!.name.toLowerCase();
    final localized = (tr(nameKey) == nameKey) ? _nextPrayer!.name : tr(nameKey);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: const Color.fromRGBO(212, 175, 55, 0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color.fromRGBO(212, 175, 55, 0.12)),
          ),
          child: Row(
            children: [
              Icon(_iconForPrayer(_nextPrayer!.name), color: const Color(0xFFD4AF37)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('time_to_prayer_fmt', namedArgs: {'dur': _formatDuration(_timeToNext), 'prayer': localized}),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    LinearProgressIndicator(
                      value: _progressToNext,
                      backgroundColor: const Color.fromRGBO(255, 255, 255, 0.04),
                      valueColor: const AlwaysStoppedAnimation(Color(0xFFD4AF37)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(_nextPrayer!.timeString, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w700)),
            ],
          ),
        ),

        const SizedBox(height: 12),
      ],
    );
  }

  }
