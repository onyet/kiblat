import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/location_service.dart';
import '../widgets/exit_helper.dart';
import 'home_topbar.dart';
import 'home_compass_widget.dart';
import 'home_compass_controller.dart';
import 'home_location_controller.dart';
import 'home_dialogs.dart';
import 'home_prayer_sheet.dart';
import 'ar_qibla_screen.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/services/home_widget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:kiblat/screens/main_shell.dart';
import 'package:kiblat/widgets/ad_countdown_overlay.dart';

class HomeScreen extends StatefulWidget {
  final bool skipPermissionCheck;
  final dynamic locationController;
  final dynamic compassController;

  const HomeScreen({
    super.key,
    this.locationController,
    this.compassController,
    this.skipPermissionCheck = false,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _controller;
  final ValueNotifier<double> _headingNotifier = ValueNotifier(125.0);
  double qiblaDeg = 0.0;
  double distanceKm = 0.0;
  bool _isLocationReady = false;
  bool _isRefreshingLocation = false;

  ps.PrayerTime? _nextPrayer;
  final ValueNotifier<Duration> _timeToNextNotifier = ValueNotifier(
    Duration.zero,
  );
  Timer? _prayerTimer;
  Timer? _promoTimer;

  double? _latitude;
  double? _longitude;

  ps.PrayerTime? _prevPrayer;
  bool _isPrevActive = false;

  final ValueNotifier<bool> _isImminentNotifier = ValueNotifier(false);

  StreamSubscription<double?>? _headingSub;
  StreamSubscription<bool>? _staleSub;
  CompassHeadingController? _compassController;
  String _locationLabel = '...';
  bool _isCompassStale = false;

  ValueNotifier<int>? _tabNotifier;
  bool _isHomeTabActive = true;
  bool _isAppForeground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _controller.forward();

    SettingsService.instance.notifier.addListener(_onSettingsChanged);

    if (!LocationService.hasCompass()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showErrorAlert(
          context,
          title: tr('compass_unavailable_title'),
          message: tr('compass_unavailable_msg'),
        );
      });
    } else {
      _compassController =
          (widget.compassController as CompassHeadingController?) ??
          CompassHeadingController();
      _headingSub = _compassController!.smoothedStream.listen((val) {
        _headingNotifier.value = val;
      });
      _staleSub = _compassController!.staleStream.listen((isStale) {
        if (mounted) setState(() => _isCompassStale = isStale);
      });
    }

    if (widget.skipPermissionCheck) {
      _fetchAndSetLocation();
    } else {
      // Small delay to ensure UI is stable before potentially showing permission dialog
      Future.delayed(const Duration(milliseconds: 500), () async {
        final granted = await LocationService.checkAndRequestPermission();
        if (granted) {
          _fetchAndSetLocation();
        } else {
          // If not granted, still try to show cached data
          _fetchAndSetLocation();
        }
      });
    }

    // Show Pro promo after 10 seconds (deferred for better UX)
    _promoTimer = Timer(const Duration(seconds: 10), _checkAndShowPromoDialog);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen to tab changes to pause/resume sensors (Battery Optimization)
    final newTabNotifier = MainShell.activeTabOf(context);
    if (_tabNotifier != newTabNotifier) {
      _tabNotifier?.removeListener(_handleTabChange);
      _tabNotifier = newTabNotifier;
      _tabNotifier?.addListener(_handleTabChange);
      _handleTabChange(); // initial check
    }
  }

  void _handleTabChange() {
    if (_tabNotifier == null) return;
    // HomeScreen is at index 0
    _isHomeTabActive = _tabNotifier!.value == 0;
    _syncSensorsAndTimers();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isAppForeground = state == AppLifecycleState.resumed;
    _syncSensorsAndTimers();
  }

  bool get _shouldRunLiveWork => _isHomeTabActive && _isAppForeground;

  void _syncSensorsAndTimers() {
    if (_compassController != null) {
      if (_shouldRunLiveWork) {
        _compassController!.resume();
      } else {
        _compassController!.pause();
      }
    }
    if (_shouldRunLiveWork) {
      _ensurePrayerTimer();
    } else {
      _prayerTimer?.cancel();
      _prayerTimer = null;
    }
  }

  void _ensurePrayerTimer() {
    if (!_shouldRunLiveWork || _nextPrayer == null) return;
    if (_prayerTimer != null) return;
    _updateTimeToNextNotifier();
    _prayerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      _updateTimeToNextNotifier();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _prayerTimer?.cancel();
    _promoTimer?.cancel();
    _headingSub?.cancel();
    _staleSub?.cancel();
    _tabNotifier?.removeListener(_handleTabChange);
    _compassController?.dispose();
    _headingNotifier.dispose();
    SettingsService.instance.notifier.removeListener(_onSettingsChanged);
    _timeToNextNotifier.dispose();
    _isImminentNotifier.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchAndSetLocation({bool forceRefresh = false}) async {
    if (forceRefresh) {
      if (mounted) setState(() => _isRefreshingLocation = true);
    }

    // 1. Try to load cached data first to give user something immediate
    if (!_isLocationReady || forceRefresh) {
      final cached = await LocationService.getLastLocation();
      if (cached != null && mounted && !_isLocationReady) {
        setState(() {
          _locationLabel = cached['label'];
          _latitude = cached['lat'];
          _longitude = cached['lon'];
          qiblaDeg = LocationService.qiblaBearing(_latitude!, _longitude!);
          distanceKm = LocationService.distanceToKaabaKm(
            _latitude!,
            _longitude!,
          );
          _isLocationReady = true;
        });
        _refreshNextPrayer();
      }
    }

    final controller = widget.locationController ?? HomeLocationController();
    try {
      final res = await (controller as dynamic).fetchLocation();
      if (!mounted) return;

      setState(() {
        _locationLabel = res.label.isEmpty
            ? '${res.lat.toStringAsFixed(3)}, ${res.lon.toStringAsFixed(3)}'
            : res.label;
        qiblaDeg = res.qiblaDeg;
        distanceKm = res.distanceKm;
        _latitude = res.lat;
        _longitude = res.lon;
        _isLocationReady = true;
        _isRefreshingLocation = false;
      });

      _refreshNextPrayer();
      HomeWidgetService.instance.updateQiblaData(
        qiblaDegree: res.qiblaDeg,
        locationName: _locationLabel,
        latitude: res.lat,
        longitude: res.lon,
      );

      if (forceRefresh) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('location_updated')),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      debugPrint('Location fetch failed: $e');
      if (!mounted) return;

      // If we don't have location yet and primary fetch failed, try cached one last time
      if (!_isLocationReady) {
        final cached = await LocationService.getLastLocation();
        if (cached != null) {
          setState(() {
            _locationLabel = cached['label'];
            _latitude = cached['lat'];
            _longitude = cached['lon'];
            qiblaDeg = LocationService.qiblaBearing(_latitude!, _longitude!);
            distanceKm = LocationService.distanceToKaabaKm(
              _latitude!,
              _longitude!,
            );
            _isLocationReady = true;
          });
          _refreshNextPrayer();
        } else {
          setState(() {
            _isLocationReady = false;
            _isRefreshingLocation = false;
          });
        }
      } else {
        setState(() => _isRefreshingLocation = false);
      }
    }
  }

  Future<void> _refreshNextPrayer() async {
    if (!_isLocationReady || _latitude == null || _longitude == null) return;
    try {
      final settings = await PrayerSettings.load();
      final pair = await ps.PrayerService.getPrevAndNextPrayerTimes(
        latitude: _latitude!,
        longitude: _longitude!,
        settings: settings,
      );

      if (!mounted) return;

      setState(() {
        _nextPrayer = pair['next'];
        _prevPrayer = pair['previous'];
        final now = ps.PrayerService.nowForSettings(settings);
        _isPrevActive =
            (_prevPrayer != null &&
            _nextPrayer != null &&
            now.isAfter(_prevPrayer!.time) &&
            now.isBefore(_nextPrayer!.time));
      });

      _updateTimeToNextNotifier();
      _prayerTimer?.cancel();
      _prayerTimer = null;
      _ensurePrayerTimer();
    } catch (_) {}
  }

  void _updateTimeToNextNotifier() {
    if (_nextPrayer == null) return;
    final settings = SettingsService.instance.notifier.value;
    final now = ps.PrayerService.nowForSettings(settings);
    if (now.isAfter(_nextPrayer!.time)) {
      _refreshNextPrayer();
      return;
    }
    final remaining = _nextPrayer!.time.difference(now);
    _timeToNextNotifier.value = remaining;
    _isImminentNotifier.value =
        remaining > Duration.zero && remaining <= const Duration(minutes: 10);
  }

  void _onSettingsChanged() {
    _refreshNextPrayer();
    if (mounted) setState(() {});
  }

  Future<void> _checkAndShowPromoDialog() async {
    if (!mounted) return;
    final settings = SettingsService.instance.notifier.value;
    if (settings.isProUser) return;

    // Only show if location is successfully loaded (better UX: provide value first)
    if (!_isLocationReady) {
      _promoTimer?.cancel();
      _promoTimer = Timer(const Duration(seconds: 5), _checkAndShowPromoDialog);
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getInt('last_pro_promo_time') ?? 0;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (now - lastShown < 24 * 60 * 60 * 1000) return;
    await prefs.setInt('last_pro_promo_time', now);

    if (!mounted) return;
    _showProPromo();
  }

  void _showProPromo() {
    showDialog(
      context: context,
      builder: (ctx) {
        final settings = SettingsService.instance.notifier.value;
        final isLight = AppTheme.isLight(settings, context);
        final accent = AppTheme.getAccentColor(settings, context);
        final card = AppTheme.getCardColor(settings, context);
        final text = AppTheme.getTextColor(settings, context);
        final secText = AppTheme.getSecondaryTextColor(settings, context);

        return AlertDialog(
          backgroundColor: card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: accent, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.stars, color: accent, size: 28),
              const SizedBox(width: 10),
              Text(
                tr('upgrade_pro'),
                style: TextStyle(
                  color: text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('pro_desc'),
                style: TextStyle(color: secText, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 16),
              _promoFeature('✅ ${tr('pro_prompt_benefit_ads')}', secText),
              _promoFeature('✅ ${tr('pro_prompt_benefit_themes')}', secText),
              _promoFeature(
                '✅ ${tr('pro_prompt_benefit_tracker_plus')}',
                secText,
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                tr('dismiss'),
                style: TextStyle(color: secText.withValues(alpha: 0.5)),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: isLight ? Colors.white : Colors.black,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pushNamed(context, '/settings');
              },
              child: Text(
                tr('view_details_pro'),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _promoFeature(String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Text(
      text,
      style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 12),
    ),
  );

  void _handleArTap() async {
    final prefs = await SharedPreferences.getInstance();
    final bool skipWarning = prefs.getBool('skip_ar_warning') ?? false;

    if (!skipWarning) {
      bool dontShowAgain = false;
      // RAM Warning for potentially low-end devices
      final bool? proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            final s = SettingsService.instance.notifier.value;
            final accent = AppTheme.getAccentColor(s, context);

            return AlertDialog(
              title: Text(tr('ar_warning_title')),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tr('ar_warning_msg')),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      SizedBox(
                        width: 24,
                        height: 24,
                        child: Checkbox(
                          value: dontShowAgain,
                          activeColor: accent,
                          onChanged: (val) {
                            setStateDialog(() => dontShowAgain = val ?? false);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setStateDialog(
                            () => dontShowAgain = !dontShowAgain,
                          ),
                          child: Text(
                            tr('dont_show_again'),
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: Text(tr('cancel')),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (dontShowAgain) {
                      prefs.setBool('skip_ar_warning', true);
                    }
                    Navigator.pop(ctx, true);
                  },
                  child: Text(tr('proceed')),
                ),
              ],
            );
          },
        ),
      );

      if (proceed != true) return;
    }

    final status = await Permission.camera.request();
    if (status.isGranted) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ArQiblaScreen(qiblaBearing: qiblaDeg),
        ),
      );
    } else {
      if (!mounted) return;
      showErrorAlert(
        context,
        title: tr('camera_permission_title'),
        message: tr('camera_permission_msg'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    return AdCountdownOverlay(
      screenName: 'home',
      child: PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, result) async {
          if (didPop) return;
          await showExitAndMaybeShowAd(context);
        },
        child: Scaffold(
          backgroundColor: AppTheme.getBackgroundColor(settings, context),
          body: SafeArea(
            child: Column(
              children: [
                HomeTopBar(
                  locationLabel: _locationLabel,
                  showArIcon: true,
                  onArTap: _handleArTap,
                  onRefreshTap: () => _fetchAndSetLocation(forceRefresh: true),
                  isRefreshing: _isRefreshingLocation,
                  onSettingsTap: () =>
                      Navigator.of(context).pushNamed('/settings'),
                ),
                if (_isCompassStale)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.orange.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.sync_problem,
                          color: Colors.orange,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            tr('calibration_hint'),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.orange,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: Center(
                    child: ValueListenableBuilder<double>(
                      valueListenable: _headingNotifier,
                      builder: (context, heading, _) {
                        return HomeCompass(
                          headingDeg: heading,
                          qiblaDeg: qiblaDeg,
                          distanceKm: distanceKm,
                          isLocationReady: _isLocationReady,
                          theme: settings.compassTheme,
                          isLight: AppTheme.isLight(settings, context),
                        );
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                HomePrayerSheet(
                  prayerKey: _nextPrayer?.name.toLowerCase() ?? 'maghrib',
                  prayerTime: _nextPrayer?.timeString ?? '--:--',
                  timeToNextListenable: _timeToNextNotifier,
                  countdownDur: '--:--',
                  activePrayerKey: _prevPrayer?.name.toLowerCase(),
                  isActive: _isPrevActive,
                  isImminentListenable: _isImminentNotifier,
                  onViewFullSchedule: () => MainShell.switchTab(1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
