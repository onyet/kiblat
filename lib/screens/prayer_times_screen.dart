import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'dart:async';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/services/location_service.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/hijri_converter.dart';
import 'package:kiblat/widgets/sunnah_compact.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:kiblat/screens/home_topbar.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:kiblat/services/ad_service.dart';
import 'package:kiblat/widgets/ad_countdown_overlay.dart';
import 'package:kiblat/screens/main_shell.dart';
import 'package:kiblat/services/location_profile_service.dart';
import 'package:kiblat/services/ics_export_service.dart';

class PrayerTimesScreen extends StatefulWidget {
  const PrayerTimesScreen({super.key});

  @override
  State<PrayerTimesScreen> createState() => _PrayerTimesScreenState();
}

class _PrayerTimesScreenState extends State<PrayerTimesScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  int _selectedTabIndex = 0; // 0: Today, 1: This Week

  // Live data
  bool _loading = true;
  String _error = '';

  double? _latitude;
  double? _longitude;
  double? _qiblaDeg;
  String _locationLabel = '';

  ps.DailyPrayerTimes? _todayPrayers;
  List<ps.DailyPrayerTimes> _weekPrayers = [];

  PrayerSettings? _settings;

  // Active prayer / countdown state
  Timer? _countdownTimer;
  ps.PrayerTime? _activePrayer;
  ps.PrayerTime? _nextPrayer;
  final ValueNotifier<Duration> _timeToNextNotifier = ValueNotifier(
    Duration.zero,
  );
  final ValueNotifier<double> _progressToNextNotifier = ValueNotifier(0.0);
  bool _refreshingPrevNext = false;

  BannerAd? _bannerAd;
  bool _bannerLoaded = false;

  ValueNotifier<int>? _shellTabNotifier;
  bool _isPrayerTabActive = false;
  bool _isAppForeground = true;

  DateTime get _todayDate => ps.PrayerService.nowForSettings(
    _settings ?? SettingsService.instance.notifier.value,
  );

  String _getQiblaDirection(double degrees) {
    final dirs = [
      'dir_n',
      'dir_ne',
      'dir_e',
      'dir_se',
      'dir_s',
      'dir_sw',
      'dir_w',
      'dir_nw',
    ];
    final index = ((degrees + 22.5) ~/ 45) % 8;
    return tr(dirs[index]);
  }

  String _localizedSubtitle(String raw) {
    final key = raw.toLowerCase();
    if (EasyLocalization.of(context) != null && tr(key) != key) return tr(key);
    final s = key.replaceAll('_', ' ');
    return s[0].toUpperCase() + s.substring(1);
  }

  Future<void> _exportIcs(PrayerSettings settings) async {
    if (_latitude == null || _longitude == null) return;
    try {
      await IcsExportService.instance.exportAndShare(
        latitude: _latitude!,
        longitude: _longitude!,
        settings: settings,
        days: 60,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('export_ics_failed')}: $e')),
      );
    }
  }

  Future<void> _loadAll() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = '';
    });

    try {
      final settingsNow = SettingsService.instance.notifier.value;
      final useProfile = settingsNow.isProUser &&
          !LocationProfileService.instance.followGpsNotifier.value;
      if (useProfile) {
        final override =
            await LocationProfileService.instance.overrideCoordinates();
        if (override != null) {
          _latitude = override.lat;
          _longitude = override.lon;
          _locationLabel = override.label;
        }
      }

      if (_latitude == null || _longitude == null) {
        dynamic pos;
        try {
          pos = await LocationService.getCurrentPosition().timeout(
            const Duration(seconds: 12),
          );
        } catch (e) {
          debugPrint(
            'PrayerTimes: GPS fetch failed or timed out, trying cached: $e',
          );
          final cached = await LocationService.getLastLocation();
          if (cached != null) {
            _latitude = cached['lat'];
            _longitude = cached['lon'];
          }
        }

        if (pos != null) {
          _latitude = (pos as dynamic).latitude;
          _longitude = (pos as dynamic).longitude;
        }
      }

      if (_latitude == null || _longitude == null) {
        final cached = await LocationService.getLastLocation(allowExpired: true);
        if (cached != null) {
          _latitude = cached['lat'];
          _longitude = cached['lon'];
        } else {
          throw Exception('Location not available. Please enable GPS.');
        }
      }

      // Use cached geocode if available to speed up UI, with timeout
      try {
        final cachedLoc = await LocationService.getLastLocation();
        if (cachedLoc != null &&
            cachedLoc['lat'] == _latitude &&
            cachedLoc['lon'] == _longitude) {
          _locationLabel = cachedLoc['label'];
        } else {
          _locationLabel = await LocationService.reverseGeocodeWithCache(
            _latitude!,
            _longitude!,
          ).timeout(const Duration(seconds: 5));
        }
      } catch (e) {
        debugPrint('PrayerTimes: Geocode timeout or error: $e');
        _locationLabel =
            '${_latitude!.toStringAsFixed(2)}, ${_longitude!.toStringAsFixed(2)}';
      }

      _qiblaDeg = LocationService.qiblaBearing(_latitude!, _longitude!);

      _settings = await PrayerSettings.load();

      _todayPrayers = await ps.PrayerService.calculatePrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        date: DateTime(_todayDate.year, _todayDate.month, _todayDate.day),
        settings: _settings!,
      ).timeout(const Duration(seconds: 3));

      _weekPrayers = [];
      for (var i = 0; i < 7; i++) {
        final d = _todayDate.add(Duration(days: i));
        final dt = await ps.PrayerService.calculatePrayerTimes(
          latitude: _latitude!,
          longitude: _longitude!,
          date: DateTime(d.year, d.month, d.day),
          settings: _settings!,
        ).timeout(const Duration(seconds: 2));
        _weekPrayers.add(dt);
      }

      await _updatePrevNext();
      _startCountdownUpdater();
    } catch (e) {
      debugPrint('PrayerTimes: Error in _loadAll: $e');
      if (mounted) {
        setState(() {
          _error = tr('location_unavailable_msg');
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
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
    WidgetsBinding.instance.addObserver(this);
    _loadAll();
    _loadBannerAd();
    SettingsService.instance.notifier.addListener(_onSettingsChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final tabNotifier = MainShell.activeTabOf(context);
    if (_shellTabNotifier != tabNotifier) {
      _shellTabNotifier?.removeListener(_onShellTabChanged);
      _shellTabNotifier = tabNotifier;
      _shellTabNotifier?.addListener(_onShellTabChanged);
      _onShellTabChanged();
    }
  }

  void _onShellTabChanged() {
    // PrayerTimesScreen is at index 1 in MainShell
    _isPrayerTabActive = _shellTabNotifier?.value == 1;
    _syncCountdownTimer();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    _syncCountdownTimer();
  }

  bool get _shouldRunCountdown => _isPrayerTabActive && _isAppForeground;

  void _syncCountdownTimer() {
    if (_shouldRunCountdown) {
      _ensureCountdownTimer();
    } else {
      _countdownTimer?.cancel();
      _countdownTimer = null;
    }
  }

  void _ensureCountdownTimer() {
    if (!_shouldRunCountdown || _nextPrayer == null) return;
    if (_countdownTimer != null) return;
    // Refresh once when becoming visible again (tab/app resume).
    final now = ps.PrayerService.nowForSettings(
      _settings ?? SettingsService.instance.notifier.value,
    );
    if (_nextPrayer != null && !now.isAfter(_nextPrayer!.time)) {
      _timeToNextNotifier.value = _nextPrayer!.time.difference(now);
    }
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted || !_shouldRunCountdown) return;
      final now = ps.PrayerService.nowForSettings(
        _settings ?? SettingsService.instance.notifier.value,
      );
      if (_nextPrayer == null) return;
      if (now.isAfter(_nextPrayer!.time)) {
        await _updatePrevNext();
        return;
      }
      _timeToNextNotifier.value = _nextPrayer!.time.difference(now);
      if (_activePrayer != null) {
        _progressToNextNotifier.value = ps.PrayerService.progressBetween(
          _activePrayer!.time,
          _nextPrayer!.time,
          now,
        );
      }
    });
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

    final adUnitId = AdService.prayerTimesBannerUnitId;
    debugPrint('[PrayerTimes] Loading BannerAd with Unit ID: $adUnitId');
    _bannerAd = BannerAd(
      adUnitId: adUnitId,
      request: const AdRequest(),
      size: AdSize.banner,
      listener: BannerAdListener(
        onAdLoaded: (ad) {
          debugPrint('[PrayerTimes] Banner loaded successfully');
          if (mounted) setState(() => _bannerLoaded = true);
        },
        onAdFailedToLoad: (ad, err) {
          debugPrint('[PrayerTimes] Banner failed: $err');
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

    // Update local settings state so build uses current values
    if (mounted) {
      setState(() {
        _settings = settings;
      });
    }

    if (settings.isProUser) {
      if (_bannerAd != null) {
        setState(() => _disposeBannerAd());
      }
    } else {
      _loadBannerAd();
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, settings, _) {
        final bgColor = AppTheme.getBackgroundColor(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);

        return AdCountdownOverlay(
          screenName: 'prayer_times',
          child: Scaffold(
            backgroundColor: bgColor,
            body: SafeArea(
              child: Column(
                children: [
                  HomeTopBar(
                    locationLabel: _locationLabel.isNotEmpty
                        ? _locationLabel
                        : '...',
                    onSettingsTap: () =>
                        Navigator.of(context).pushNamed('/settings'),
                  ),
                  _buildTabs(),
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async => _loadAll(),
                      color: accentColor,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                        children: [
                          _buildDateHeader(),
                          if (settings.isProUser &&
                              _latitude != null &&
                              _longitude != null) ...[
                            const SizedBox(height: 8),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: () => _exportIcs(settings),
                                icon: Icon(Icons.calendar_month, color: accentColor, size: 18),
                                label: Text(
                                  tr('export_ics'),
                                  style: TextStyle(color: accentColor),
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: 12),
                          if (_loading)
                            _buildLoadingIndicator(accentColor, settings)
                          else if (_error.isNotEmpty)
                            _buildErrorMessage()
                          else ...[
                            if (_selectedTabIndex == 0) _buildCountdownBanner(),
                            const SizedBox(height: 12),
                            AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: _selectedTabIndex == 0
                                  ? _buildDayView(_todayPrayers, isToday: true)
                                  : _buildWeekView(),
                            ),
                            const SizedBox(height: 24),
                            _buildQiblaCard(),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (!settings.isProUser && _bannerAd != null)
                    Container(
                      alignment: Alignment.center,
                      width: _bannerAd!.size.width.toDouble(),
                      height: _bannerAd!.size.height.toDouble(),
                      color: bgColor,
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

  Widget _buildLoadingIndicator(Color accentColor, PrayerSettings settings) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 60),
          CircularProgressIndicator(color: accentColor),
          const SizedBox(height: 16),
          Text(
            tr('calculating'),
            style: TextStyle(
              color: AppTheme.getSecondaryTextColor(settings, context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorMessage() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Text(
          _error,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.redAccent),
        ),
      ),
    );
  }

  Widget _buildTabs() {
    final settings = SettingsService.instance.notifier.value;
    final borderColor = AppTheme.getBorderColor(settings, context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: borderColor, width: 0.5)),
      ),
      child: Row(
        children: [
          _buildTabButton('today', 0),
          const SizedBox(width: 24),
          _buildTabButton('this_week', 1),
        ],
      ),
    );
  }

  Widget _buildTabButton(String labelKey, int index) {
    final settings = SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final isActive = _selectedTabIndex == index;

    return InkWell(
      onTap: () => setState(() => _selectedTabIndex = index),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              tr(labelKey).toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                letterSpacing: 1.1,
                color: isActive ? accentColor : secTextColor,
              ),
            ),
          ),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            height: 3,
            width: 40,
            decoration: BoxDecoration(
              color: isActive ? accentColor : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateHeader() {
    final settings = SettingsService.instance.notifier.value;
    final cardColor = AppTheme.getCardColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);
    final date = _todayDate;
    final hijri = HijriConverter.getHijriDate(date);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  hijri.toFormattedStringArabic(),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  HijriConverter.formatGregorianShort(date),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: secTextColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.calendar_month_outlined,
            color: secTextColor.withValues(alpha: 0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildDayView(ps.DailyPrayerTimes? day, {bool isToday = true}) {
    if (day == null) return const SizedBox.shrink();

    // Ensure we use the latest settings for child widgets
    final currentSettings =
        _settings ?? SettingsService.instance.notifier.value;

    final sunnah = day.prayers.where((p) => p.isSunnah).toList();
    final regular = day.prayers.where((p) => !p.isSunnah).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (currentSettings.showSunnahTimes == true && sunnah.isNotEmpty) ...[
          SunnahCompact(
            sunnahList: sunnah,
            activePrayer: isToday ? _activePrayer : null,
          ),
          const SizedBox(height: 12),
        ],
        ...regular.map((p) => _buildPrayerCard(p, isToday)),
      ],
    );
  }

  Widget _buildWeekView() {
    return Column(
      children: _weekPrayers.map((day) {
        final dateStr = HijriConverter.formatGregorianShort(day.date);
        final dayName = DateFormat(
          'EEEE',
          context.locale.toString(),
        ).format(day.date);
        final settings = _settings ?? SettingsService.instance.notifier.value;
        final accentColor = AppTheme.getAccentColor(settings, context);

        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 16,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    "$dayName, $dateStr",
                    style: TextStyle(
                      color: AppTheme.getTextColor(settings, context),
                      fontWeight: FontWeight.w800,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _buildDayView(day, isToday: day.date.day == _todayDate.day),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPrayerCard(ps.PrayerTime prayer, bool isToday) {
    final settings = _settings ?? SettingsService.instance.notifier.value;
    final isActive = isToday && _activePrayer?.name == prayer.name;
    final accentColor = AppTheme.getAccentColor(settings, context);
    final cardColor = AppTheme.getCardColor(settings, context);
    final isLight = AppTheme.isLight(settings, context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isActive ? accentColor.withValues(alpha: 0.12) : cardColor,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: () {}, // For splash effect
          borderRadius: BorderRadius.circular(16),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isActive
                    ? accentColor
                    : (isLight
                          ? Colors.black.withValues(alpha: 0.1)
                          : AppTheme.getBorderColor(settings, context)),
                width: isActive ? 1.5 : 1,
              ),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: isActive
                      ? accentColor
                      : accentColor.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  _iconForPrayer(prayer.name),
                  color: isActive ? Colors.white : accentColor,
                  size: 20,
                ),
              ),
              title: Text(
                tr(prayer.name.toLowerCase()),
                style: TextStyle(
                  color: AppTheme.getTextColor(settings, context),
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                ),
              ),
              subtitle: Text(
                _localizedSubtitle(prayer.subtitle),
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(settings, context),
                  fontSize: 11,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    prayer.timeString,
                    style: TextStyle(
                      color: isActive
                          ? accentColor
                          : AppTheme.getTextColor(settings, context),
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                      letterSpacing: -0.5,
                    ),
                  ),
                  if (isActive)
                    Text(
                      tr('status_active').toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 9,
                        letterSpacing: 0.5,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQiblaCard() {
    final settings = SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final cardColor = AppTheme.getCardColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.explore, color: accentColor),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('facing_qibla').toUpperCase(),
                  style: TextStyle(
                    color: accentColor,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  "${_qiblaDeg?.toStringAsFixed(0)}° ${_getQiblaDirection(_qiblaDeg ?? 0)} ${tr('from')} $_locationLabel",
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _shellTabNotifier?.removeListener(_onShellTabChanged);
    SettingsService.instance.notifier.removeListener(_onSettingsChanged);
    _countdownTimer?.cancel();
    _timeToNextNotifier.dispose();
    _progressToNextNotifier.dispose();
    _bannerAd?.dispose();
    super.dispose();
  }

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
      final now = ps.PrayerService.nowForSettings(_settings!);
      final active =
          (prev != null &&
              (now.isAtSameMomentAs(prev.time) || now.isAfter(prev.time)) &&
              (next == null || now.isBefore(next.time)))
          ? prev
          : null;

      if (mounted) {
        setState(() {
          _nextPrayer = next;
          _activePrayer = active;
        });
        _timeToNextNotifier.value = next != null
            ? next.time.difference(now)
            : Duration.zero;
        _progressToNextNotifier.value = (prev != null && next != null)
            ? ps.PrayerService.progressBetween(prev.time, next.time, now)
            : 0.0;
      }
    } finally {
      _refreshingPrevNext = false;
    }
  }

  void _startCountdownUpdater() {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _syncCountdownTimer();
  }

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);

    if (h > 0) {
      return tr(
        'duration_h_m',
        namedArgs: {'h': h.toString(), 'm': m.toString()},
      );
    }
    if (m > 0) {
      return tr(
        'duration_m_s',
        namedArgs: {'m': m.toString(), 's': s.toString()},
      );
    }
    return tr('duration_s', namedArgs: {'s': s.toString()});
  }

  Widget _buildCountdownBanner() {
    if (_nextPrayer == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Duration>(
      valueListenable: _timeToNextNotifier,
      builder: (context, timeToNext, _) {
        return ValueListenableBuilder<double>(
          valueListenable: _progressToNextNotifier,
          builder: (context, progressToNext, _) {
            final settings =
                _settings ?? SettingsService.instance.notifier.value;
            final accentColor = AppTheme.getAccentColor(settings, context);
            final textColor = AppTheme.getTextColor(settings, context);

            return Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    accentColor.withValues(alpha: 0.15),
                    accentColor.withValues(alpha: 0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: accentColor.withValues(alpha: 0.2)),
              ),
              child: Row(
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 48,
                        height: 48,
                        child: CircularProgressIndicator(
                          value: progressToNext,
                          strokeWidth: 4,
                          backgroundColor: accentColor.withValues(alpha: 0.1),
                          valueColor: AlwaysStoppedAnimation<Color>(
                            accentColor,
                          ),
                        ),
                      ),
                      Icon(
                        _iconForPrayer(_nextPrayer!.name),
                        color: accentColor,
                        size: 20,
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr(
                            'time_to_prayer_fmt',
                            namedArgs: {
                              'dur': _formatDuration(timeToNext),
                              'prayer': tr(_nextPrayer!.name.toLowerCase()),
                            },
                          ),
                          style: TextStyle(
                            color: textColor,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "${tr('next_prayer')}: ${_nextPrayer!.timeString}",
                          style: TextStyle(
                            color: AppTheme.getSecondaryTextColor(
                              settings,
                              context,
                            ),
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
