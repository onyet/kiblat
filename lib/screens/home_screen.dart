import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import '../services/location_service.dart';
import '../widgets/exit_helper.dart';
import '../services/telemetry_service.dart';
import 'home_topbar.dart';
import 'home_compass_widget.dart';
import 'home_compass_controller.dart';
import 'home_location_controller.dart';
import 'home_dialogs.dart';
import 'home_prayer_sheet.dart';
import 'package:kiblat/services/prayer_service.dart' as ps;
import 'package:kiblat/models/prayer_settings_model.dart';

class HomeScreen extends StatefulWidget {
  final bool skipPermissionCheck; // useful for tests
  final dynamic locationController; // accepts HomeLocationController or similar for injection
  final dynamic compassController; // optional injection for tests (CompassHeadingController)

  const HomeScreen({super.key, this.locationController, this.compassController, this.skipPermissionCheck = false});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // Example heading in degrees. Will be updated by device compass.
  double headingDeg = 125.0;
  double qiblaDeg = 0.0; // absolute bearing to Kaaba
  double distanceKm = 0.0;
  bool _isLocationReady =
      false; // true when qibla bearing and distance are calculated

  // Next prayer info
  ps.PrayerTime? _nextPrayer;
  Duration _timeToNext = Duration.zero;
  Timer? _prayerTimer;

  double? _latitude;
  double? _longitude;

  StreamSubscription<double?>? _headingSub;
  CompassHeadingController? _compassController;
  String _locationLabel = 'London, UK';

  String _formatDuration(Duration d) {
    if (d.isNegative) return '00:00:00';
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }



  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    // small pop animation
    _controller.forward();

    // Compass availability
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
      // Start compass controller and listen to smoothed heading stream
      _compassController = (widget.compassController as CompassHeadingController?) ?? CompassHeadingController();
      _headingSub = _compassController!.smoothedStream.listen((val) {
        setState(() {
          headingDeg = val;
        });
      });
    }

    // Check and request location permission first (skippable for tests)
    if (widget.skipPermissionCheck) {
      _fetchAndSetLocation();
    } else {
      LocationService.checkAndRequestPermission().then((granted) {
        if (!granted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;
            showErrorAlert(
              context,
              title: tr('location_permission_title'),
              message: tr('location_permission_msg'),
              actions: [
                DialogAction(tr('open_settings'), (ctx) async {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  await LocationService.openAppSettings();
                }),
                DialogAction(
                  tr('dismiss'),
                  (ctx) => Navigator.of(ctx, rootNavigator: true).pop(),
                ),
              ],
            );
          });
          return;
        }

        // Permissions granted - fetch location on a background async method
        _fetchAndSetLocation();
      });
    }
  }

  @override
  void dispose() {
    _prayerTimer?.cancel();
    _headingSub?.cancel();
    _compassController?.dispose();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchAndSetLocation() async {
    final controller = widget.locationController ?? HomeLocationController();
    try {
      final res = await (controller as dynamic).fetchLocation();
      if (!mounted) return;

      if (res.label.isEmpty) {
        setState(() {
          _locationLabel = '${res.lat.toStringAsFixed(3)}, ${res.lon.toStringAsFixed(3)}';
          qiblaDeg = res.qiblaDeg;
          distanceKm = res.distanceKm;
          _latitude = res.lat;
          _longitude = res.lon;
          _isLocationReady = true;
        });

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showGeocodeFailureOptions(Position(
            latitude: res.lat,
            longitude: res.lon,
            timestamp: DateTime.now(),
            accuracy: 1.0,
            altitude: 0.0,
            altitudeAccuracy: 0.0,
            heading: 0.0,
            headingAccuracy: 0.0,
            speed: 0.0,
            speedAccuracy: 0.0,
          ));
        });
        return;
      }

      setState(() {
        _locationLabel = res.label;
        qiblaDeg = res.qiblaDeg;
        distanceKm = res.distanceKm;
        _latitude = res.lat;
        _longitude = res.lon;
        _isLocationReady = true;
      });
      // Refresh next prayer once we have location and settings
      _refreshNextPrayer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLocationReady = false;
      });

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        showErrorAlert(
          context,
          title: tr('location_unavailable_title'),
          message: tr('location_unavailable_msg'),
          actions: [
            DialogAction(tr('open_location_settings'), (ctx) async {
              Navigator.of(ctx, rootNavigator: true).pop();
              await LocationService.openLocationSettings();
            }),
            DialogAction(
              tr('dismiss'),
              (ctx) => Navigator.of(ctx, rootNavigator: true).pop(),
            ),
          ],
        );
      });
    }
  }


  // -- Error dialog helpers replaced by `home_dialogs` module --
  void _showGeocodeFailureOptions(Position pos) async {
    await showGeocodeFailureOptions(context, pos, onUseCached: (label, lat, lon) {
      setState(() {
        _locationLabel = '$label (cached)';
        qiblaDeg = LocationService.qiblaBearing(lat, lon);
        distanceKm = LocationService.distanceToKaabaKm(lat, lon);        _latitude = lat;
        _longitude = lon;        _isLocationReady = true;
      });
      TelemetryService.instance.logEvent('used_cached_location');

      // When user picks cached location, refresh next prayer
      _refreshNextPrayer();
    });
  }

  /// Refresh next prayer info using PrayerService and PrayerSettings
  Future<void> _refreshNextPrayer() async {
    if (!_isLocationReady) return;
    try {
      final settings = await PrayerSettings.load();
      if (_latitude == null || _longitude == null) return;
      final next = await ps.PrayerService.getNextPrayerTime(
        latitude: _latitude!,
        longitude: _longitude!,
        settings: settings,
      );

      if (!mounted) return;

      setState(() {
        _nextPrayer = next;
        _updateTimeToNext();
      });

      // Start periodic updater
      _prayerTimer?.cancel();
      _prayerTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        _updateTimeToNext();
      });
    } catch (e) {
      // ignore errors; we can retry when location/settings change
    }
  }

  void _updateTimeToNext() {
    if (_nextPrayer == null) {
      _timeToNext = Duration.zero;
      return;
    }

    final now = DateTime.now();
    if (now.isAfter(_nextPrayer!.time)) {
      // Next prayer passed, try refresh
      _refreshNextPrayer();
      return;
    }

    setState(() {
      _timeToNext = _nextPrayer!.time.difference(now);
    });
  }



  @override
  Widget build(BuildContext context) {
    // Format distance according to current locale when ready (handled by HomeCompass)
    // `dir` and `formattedDistance` are computed inside `HomeCompass`.

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleAppClose();
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF050505),
        body: SafeArea(
          child: Column(
            children: [
              // Top bar (extracted to HomeTopBar)
              HomeTopBar(
                locationLabel: _locationLabel,
                onSettingsTap: () => Navigator.of(context).pushNamed('/settings'),
              ),

              const SizedBox(height: 12),

              // Compass (extracted to HomeCompass)
              Expanded(
                child: Center(
                  child: HomeCompass(
                    headingDeg: headingDeg,
                    qiblaDeg: qiblaDeg,
                    distanceKm: distanceKm,
                    isLocationReady: _isLocationReady,
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Prayer schedule card
              HomePrayerSheet(
                prayerKey: _nextPrayer?.name.toLowerCase() ?? 'maghrib',
                prayerTime: _nextPrayer?.timeString ?? '--:--',
                countdownDur: _formatDuration(_timeToNext),
                onViewFullSchedule: () {
                  Navigator.of(context).pushNamed(
                    '/prayer_times',
                    arguments: {
                      'locationLabel': _locationLabel,
                      'qiblaDeg': qiblaDeg,
                    },
                  );
                },
              ),

            ],
          ),
        ),
      ),
    );
  }

  /// Handle app close - use centralized helper (confirmation + loading + ad + exit)
  // ignore: use_build_context_synchronously
  Future<void> _handleAppClose() async {
    await showExitAndMaybeShowAd(context);
  }
}

