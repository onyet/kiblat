import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:adhan/adhan.dart';
import 'package:kiblat/utils/timezone_util.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:kiblat/screens/main_shell.dart';
import 'dart:io';
import 'dart:async';

import '../services/location_service.dart';
import 'package:kiblat/services/notification_service.dart';
import 'package:kiblat/services/billing_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kiblat/utils/theme_util.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  static const MethodChannel _platformChannel = MethodChannel(
    'id.onyet.app.kiblat/platform',
  );

  bool _locationActive = false;
  bool _compassAvailable = false;
  bool _testAdMode = false;
  bool _notificationPermissionGranted = false;
  bool _isInterstitialAdReady = false;
  Timer? _adCheckTimer;

  // Prayer settings
  PrayerSettings? _prayerSettings;
  Madhab? _selectedMadhab;
  CalculationMethod? _selectedMethod;
  HighLatitudeRule? _selectedHighLatitudeRule;
  late final TextEditingController _adjustmentController;
  String? _selectedTimezoneId;
  bool _loadingPrayerSettings = true;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim;

  @override
  void initState() {
    super.initState();
    _refreshStatus();

    BillingService.instance.isPendingPurchase.addListener(_onBillingChanged);
    BillingService.instance.productsNotifier.addListener(_onBillingChanged);
    BillingService.instance.isStoreAvailable.addListener(_onBillingChanged);
    BillingService.instance.billingError.addListener(_onBillingErrorChanged);
    BillingService.instance.onPurchaseSuccess = _onBillingSuccess;

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.96, end: 1.08).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );
    _opacityAnim = Tween<double>(begin: 0.12, end: 0.32).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeInOut),
    );

    // Only load persisted test-mode in debug builds (QA). Production should not expose or load this.
    if (kDebugMode) {
      _loadTestMode();
    }

    // Initialize timezone database and load prayer settings
    tzdata.initializeTimeZones();
    _adjustmentController = TextEditingController();
    _loadPrayerSettings();

    // Periodically check if interstitial ad is ready for voluntary watch
    _refreshAdStatus();
    _adCheckTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _refreshAdStatus();
    });
  }

  void _refreshAdStatus() {
    final ready =
        AdService.instance.isInterstitialAdReady &&
        !AdService.instance.isShowingInterstitial;
    if (ready != _isInterstitialAdReady && mounted) {
      setState(() {
        _isInterstitialAdReady = ready;
      });
    }
  }

  Future<void> _refreshStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    final hasPermission =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    final compass = LocationService.hasCompass();

    // Check notification permission
    bool notifEnabled = false;
    try {
      notifEnabled = await NotificationService.instance
          .areNotificationsEnabled();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _locationActive = serviceEnabled && hasPermission;
      _compassAvailable = compass;
      _notificationPermissionGranted = notifEnabled;
    });
  }

  void _openAppSettings() async {
    await LocationService.openAppSettings();
    await Future.delayed(const Duration(milliseconds: 400));
    _refreshStatus();
  }

  Future<void> _requestPermission() async {
    final granted = await LocationService.checkAndRequestPermission();
    if (!mounted) return;
    setState(() {
      _locationActive = granted;
    });
  }

  void _showInfoDialog(String title, String message) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: Text(tr('ok')),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _adCheckTimer?.cancel();
    _animController.dispose();
    _adjustmentController.dispose();
    BillingService.instance.isPendingPurchase.removeListener(_onBillingChanged);
    BillingService.instance.productsNotifier.removeListener(_onBillingChanged);
    BillingService.instance.isStoreAvailable.removeListener(_onBillingChanged);
    BillingService.instance.billingError.removeListener(_onBillingErrorChanged);
    if (BillingService.instance.onPurchaseSuccess == _onBillingSuccess) {
      BillingService.instance.onPurchaseSuccess = null;
    }
    super.dispose();
  }

  void _onBillingChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  void _onBillingErrorChanged() {
    final error = BillingService.instance.billingError.value;
    if (error != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Billing error: $error'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onBillingSuccess() {
    if (mounted) {
      setState(() {
        _prayerSettings = SettingsService.instance.notifier.value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pembelian Kiblat Pro Sukses! 🎉'),
          backgroundColor: Color(0xFF4CAF50),
        ),
      );
    }
  }

  Future<void> _loadTestMode() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final val = prefs.getBool('ad_test_mode') ?? AdService.testMode;
      if (!mounted) return;
      setState(() {
        _testAdMode = val;
      });
      AdService.setTestMode(val);
      AdService.instance.reloadInterstitialAd();
      AdService.instance.reloadRewardedAd();
    } catch (_) {}
  }

  Future<void> _loadPrayerSettings() async {
    try {
      final settings = await PrayerSettings.load();
      if (!mounted) return;
      setState(() {
        _prayerSettings = settings;
        _selectedMadhab = settings.madhab;
        _selectedMethod = settings.calculationMethod;
        _selectedHighLatitudeRule = settings.highLatitudeRule;
        _selectedTimezoneId = settings.timezoneId ?? 'Device Timezone';
        _adjustmentController.text = settings.adjustmentMinutes.toString();
        _loadingPrayerSettings = false;
      });
    } catch (e) {
      // ignore and continue with defaults
      if (!mounted) return;
      setState(() {
        _prayerSettings = PrayerSettings();
        _selectedMadhab = PrayerSettings().madhab;
        _selectedMethod = PrayerSettings().calculationMethod;
        _selectedHighLatitudeRule = PrayerSettings().highLatitudeRule;
        _selectedTimezoneId = 'Device Timezone';
        _adjustmentController.text = '0';
        _loadingPrayerSettings = false;
      });
    }
  }

  Future<void> _toggleTestMode(bool value) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('ad_test_mode', value);
      AdService.setTestMode(value);
      AdService.instance.reloadInterstitialAd();
      AdService.instance.reloadRewardedAd();
      if (!mounted) return;
      setState(() {
        _testAdMode = value;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(value ? tr('ad_test_mode_on') : tr('ad_test_mode_off')),
        ),
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
    final isLight = AppTheme.isLight(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);

    return Scaffold(
      backgroundColor: AppTheme.getBackgroundColor(settings, context),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: borderColor,
                  ),
                ),
                color: AppTheme.getBackgroundColor(settings, context),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Material(
                      color: isLight ? Colors.black.withOpacity(0.04) : const Color.fromRGBO(255, 255, 255, 0.05),
                      borderRadius: BorderRadius.circular(8),
                      child: InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(8),
                        child: Icon(
                          Icons.chevron_left,
                          color: textColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    tr('settings'),
                    style: TextStyle(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 40),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 18,
                ),
                children: [
                  // Decorative pulsing mosque icon
                  Align(
                    alignment: Alignment.topRight,
                    child: SizedBox(
                      width: 88,
                      height: 88,
                      child: AnimatedBuilder(
                        animation: _animController,
                        builder: (context, child) => Transform.scale(
                          scale: _scaleAnim.value,
                          child: Container(
                            decoration: BoxDecoration(
                              color: accentColor.withOpacity(_opacityAnim.value),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Center(
                              child: Icon(
                                Icons.mosque,
                                color: isLight ? textColor.withOpacity(0.8) : Colors.white70,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Voluntary ad support button - only visible when ad is ready
                  if (_isInterstitialAdReady && !(_prayerSettings?.isProUser ?? false)) ...[
                    _buildWatchAdCard(),
                    const SizedBox(height: 14),
                  ],

                  _buildProCard(),
                  const SizedBox(height: 16),

                  Text(
                    tr('configuration'),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Location Access
                  _buildStatusTile(
                    icon: Icons.location_on,
                    title: tr('location_access'),
                    subtitle: tr('location_access_desc'),
                    trailing: _locationActive
                        ? _statusChip(tr('status_active'), Colors.green)
                        : _actionButton(tr('open_settings'), _openAppSettings),
                    onTap: () async {
                      // Request permission when tapped
                      await _requestPermission();
                      if (!_locationActive) {
                        _showInfoDialog(
                          tr('location_permission_title'),
                          tr('location_permission_msg'),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 8),

                  // Compass Sensor (show availability)
                  _buildStatusTile(
                    icon: Icons.explore,
                    title: tr('compass_sensor'),
                    subtitle: tr('compass_sensor_desc'),
                    trailing: _compassAvailable
                        ? _statusChip(tr('status_available'), Colors.green)
                        : _statusChip(tr('status_unavailable'), Colors.red),
                    onTap: () {
                      if (!_compassAvailable) {
                        _showInfoDialog(
                          tr('compass_unavailable_title'),
                          tr('compass_unavailable_msg'),
                        );
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  Text(
                    tr('general'),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Language selection
                  _buildActionButton(
                    title: tr('language'),
                    subtitle: _localeLabel(
                      EasyLocalization.of(context)!.locale,
                    ),
                    icon: Icons.language,
                    onTap: _showLanguageDialog,
                  ),
                  const SizedBox(height: 8),

                  // Tampilan Awal Aplikasi
                  _buildActionButton(
                    title: 'Tampilan Awal Aplikasi',
                    subtitle: (_prayerSettings?.defaultLaunchScreen == 'prayer_times')
                        ? 'Jadwal Shalat'
                        : 'Kompas Kiblat',
                    icon: Icons.home_outlined,
                    onTap: _showDefaultLaunchScreenDialog,
                  ),
                  const SizedBox(height: 8),

                  // Tema Aplikasi (Pro)
                  _buildActionButton(
                    title: 'Tema Aplikasi',
                    subtitle: _themeDisplay(_prayerSettings?.compassTheme ?? 'classic'),
                    icon: Icons.palette_outlined,
                    onTap: _showThemeSelectionDialog,
                  ),
                  const SizedBox(height: 8),

                  // Mode Tampilan (Pro)
                  _buildActionButton(
                    title: 'Mode Tampilan',
                    subtitle: _displayModeDisplay(_prayerSettings?.displayMode ?? 'dark'),
                    icon: Icons.brightness_6_outlined,
                    onTap: _showDisplayModeSelectionDialog,
                  ),
                  const SizedBox(height: 8),

                  // Test Ad Mode toggle (QA) - only visible in debug builds
                  if (kDebugMode) ...[
                    _buildStatusTile(
                      icon: Icons.ad_units,
                      title: tr('ad_test_mode'),
                      subtitle: tr('ad_test_mode_desc'),
                      trailing: Switch(
                        value: _testAdMode,
                        activeThumbColor: accentColor,
                        onChanged: _toggleTestMode,
                      ),
                      onTap: () => _toggleTestMode(!_testAdMode),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Prayer Schedule configuration
                  Text(
                    tr('prayer_schedule') == 'prayer_schedule'
                        ? 'Prayer Schedule'
                        : tr('prayer_schedule'),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_loadingPrayerSettings)
                    const Center(
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else ...[
                    _buildActionButton(
                      title: tr('madhab') == 'madhab' ? 'Madhab' : tr('madhab'),
                      subtitle: _selectedMadhab != null
                          ? PrayerSettings.madhubDisplay(_selectedMadhab!)
                          : '',
                      icon: Icons.account_tree_outlined,
                      onTap: _showMadhabDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('calculation_method') == 'calculation_method'
                          ? 'Calculation Method'
                          : tr('calculation_method'),
                      subtitle: _selectedMethod != null
                          ? PrayerSettings.calculationMethodDisplay(
                              _selectedMethod!,
                            )
                          : '',
                      icon: Icons.calculate,
                      onTap: _showCalculationMethodDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('high_latitude_rule') == 'high_latitude_rule'
                          ? 'High Latitude Rule'
                          : tr('high_latitude_rule'),
                      subtitle: _selectedHighLatitudeRule != null
                          ? PrayerSettings.highLatitudeRuleDisplay(
                              _selectedHighLatitudeRule!,
                            )
                          : '',
                      icon: Icons.public,
                      onTap: _showHighLatitudeDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('adjustment_minutes') == 'adjustment_minutes'
                          ? 'Adjustment Minutes'
                          : tr('adjustment_minutes'),
                      subtitle: '${_adjustmentController.text} min',
                      icon: Icons.timer,
                      onTap: _showAdjustmentDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('timezone') == 'timezone'
                          ? 'Timezone'
                          : tr('timezone'),
                      subtitle: _selectedTimezoneId == null
                          ? tr('device_timezone')
                          : TimezoneUtil.getDisplayName(_selectedTimezoneId),
                      icon: Icons.schedule,
                      onTap: _showTimezoneDialog,
                    ),
                    const SizedBox(height: 8),

                    // Time format (24h / 12h)
                    _buildStatusTile(
                      icon: Icons.access_time,
                      title: tr('time_format') == 'time_format'
                          ? 'Time Format'
                          : tr('time_format'),
                      subtitle: (_prayerSettings?.use24Hour ?? true)
                          ? (tr('time_format_24') == 'time_format_24'
                                ? '24-hour'
                                : tr('time_format_24'))
                          : (tr('time_format_12') == 'time_format_12'
                                ? '12-hour (AM/PM)'
                                : tr('time_format_12')),
                      trailing: Switch(
                        value: _prayerSettings?.use24Hour ?? true,
                        activeThumbColor: accentColor,
                        onChanged: (v) => _toggleTimeFormat(v),
                      ),
                      onTap: () => _toggleTimeFormat(
                        !(_prayerSettings?.use24Hour ?? true),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Prayer notifications with permission status
                    _buildStatusTile(
                      icon: Icons.notifications,
                      title:
                          tr('prayer_notifications') == 'prayer_notifications'
                          ? 'Prayer notifications'
                          : tr('prayer_notifications'),
                      subtitle: !_notificationPermissionGranted
                          ? (tr('notification_permission_off') ==
                                    'notification_permission_off'
                                ? 'Notification permission is OFF. Tap to enable.'
                                : tr('notification_permission_off'))
                          : (tr('prayer_notifications_desc') ==
                                    'prayer_notifications_desc'
                                ? 'Enable local notifications for prayer times'
                                : tr('prayer_notifications_desc')),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!_notificationPermissionGranted)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              margin: const EdgeInsets.only(right: 8),
                              decoration: BoxDecoration(
                                color: Colors.red.withAlpha(30),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'OFF',
                                style: const TextStyle(
                                  color: Colors.redAccent,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          Switch(
                            value:
                                _notificationPermissionGranted &&
                                (_prayerSettings?.enablePrayerNotifications ??
                                    true),
                            activeThumbColor: accentColor,
                            onChanged: (v) async {
                              if (!_notificationPermissionGranted) {
                                // Request permission first
                                final granted = await NotificationService
                                    .instance
                                    .requestPermissions();
                                if (!mounted) return;
                                setState(() {
                                  _notificationPermissionGranted = granted;
                                });
                                if (!granted) {
                                  _showInfoDialog(
                                    tr('notification_permission_title') ==
                                            'notification_permission_title'
                                        ? 'Notification Permission'
                                        : tr('notification_permission_title'),
                                    tr('notification_permission_msg_denied') ==
                                            'notification_permission_msg_denied'
                                        ? 'Please enable notification permission in your device settings to receive prayer time notifications.'
                                        : tr(
                                            'notification_permission_msg_denied',
                                          ),
                                  );
                                  return;
                                }
                              }
                              setState(() {
                                _prayerSettings =
                                    _prayerSettings?.copyWith(
                                      enablePrayerNotifications: v,
                                    ) ??
                                    PrayerSettings(
                                      enablePrayerNotifications: v,
                                    );
                              });
                              await _persistPrayerSettings();
                              if (!mounted) return;
                              if (_prayerSettings?.enablePrayerNotifications ??
                                  true) {
                                await NotificationService.instance
                                    .schedulePrayerNotificationsForCurrentLocation(
                                      _prayerSettings!,
                                    );
                              } else {
                                await NotificationService.instance
                                    .cancelAllPrayerNotifications();
                              }
                            },
                          ),
                        ],
                      ),
                      onTap: () async {
                        if (!_notificationPermissionGranted) {
                          final granted = await NotificationService.instance
                              .requestPermissions();
                          if (!mounted) return;
                          setState(() {
                            _notificationPermissionGranted = granted;
                          });
                          if (!granted) {
                            _showInfoDialog(
                              tr('notification_permission_title') ==
                                      'notification_permission_title'
                                  ? 'Notification Permission'
                                  : tr('notification_permission_title'),
                              tr('notification_permission_msg_denied') ==
                                      'notification_permission_msg_denied'
                                  ? 'Please enable notification permission in your device settings.'
                                  : tr('notification_permission_msg_denied'),
                            );
                          }
                          return;
                        }
                        final newVal =
                            !(_prayerSettings?.enablePrayerNotifications ??
                                true);
                        setState(() {
                          _prayerSettings =
                              _prayerSettings?.copyWith(
                                enablePrayerNotifications: newVal,
                              ) ??
                              PrayerSettings(enablePrayerNotifications: newVal);
                        });
                        await _persistPrayerSettings();
                        if (!mounted) return;
                        if (_prayerSettings?.enablePrayerNotifications ??
                            true) {
                          await NotificationService.instance
                              .schedulePrayerNotificationsForCurrentLocation(
                                _prayerSettings!,
                              );
                        } else {
                          await NotificationService.instance
                              .cancelAllPrayerNotifications();
                        }
                      },
                    ),
                    const SizedBox(height: 8),

                    // Custom adzan ringtone
                    _buildActionButton(
                      title: tr('custom_ringtone') == 'custom_ringtone'
                          ? 'Custom Adzan Ringtone'
                          : tr('custom_ringtone'),
                      subtitle:
                          _prayerSettings?.customRingtoneName ??
                          (tr('default_ringtone') == 'default_ringtone'
                              ? 'Default'
                              : tr('default_ringtone')),
                      icon: Icons.music_note,
                      onTap: _showCustomRingtoneDialog,
                    ),
                    const SizedBox(height: 12),

                    // Sunnah times toggle
                    _buildStatusTile(
                      icon: Icons.star,
                      title: tr('sunnah_times') == 'sunnah_times'
                          ? 'Sunnah times'
                          : tr('sunnah_times'),
                      subtitle: tr('sunnah_times_desc') == 'sunnah_times_desc'
                          ? 'Show Dhuha and Tahajjud times'
                          : tr('sunnah_times_desc'),
                      trailing: Switch(
                        value: _prayerSettings?.showSunnahTimes ?? true,
                        activeThumbColor: accentColor,
                        onChanged: _toggleShowSunnahTimes,
                      ),
                      onTap: () => _toggleShowSunnahTimes(
                        !(_prayerSettings?.showSunnahTimes ?? true),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Per-sunnah toggles
                    _buildStatusTile(
                      icon: Icons.brightness_5,
                      title: tr('dhuha') == 'dhuha' ? 'Dhuha' : tr('dhuha'),
                      subtitle: tr('show_dhuha_desc') == 'show_dhuha_desc'
                          ? 'Show Dhuha time'
                          : tr('show_dhuha_desc'),
                      trailing: Switch(
                        value: _prayerSettings?.showDhuha ?? true,
                        activeThumbColor: accentColor,
                        onChanged: (v) {
                          setState(
                            () => _prayerSettings =
                                _prayerSettings?.copyWith(showDhuha: v) ??
                                PrayerSettings(showDhuha: v),
                          );
                          _persistPrayerSettings();
                        },
                      ),
                      onTap: () {
                        setState(
                          () => _prayerSettings =
                              _prayerSettings?.copyWith(
                                showDhuha:
                                    !(_prayerSettings?.showDhuha ?? true),
                              ) ??
                              PrayerSettings(showDhuha: true),
                        );
                        _persistPrayerSettings();
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildStatusTile(
                      icon: Icons.nightlight_round,
                      title: tr('tahajjud') == 'tahajjud'
                          ? 'Tahajjud'
                          : tr('tahajjud'),
                      subtitle: tr('show_tahajjud_desc') == 'show_tahajjud_desc'
                          ? 'Show Tahajjud time'
                          : tr('show_tahajjud_desc'),
                      trailing: Switch(
                        value: _prayerSettings?.showTahajjud ?? true,
                        activeThumbColor: accentColor,
                        onChanged: (v) {
                          setState(
                            () => _prayerSettings =
                                _prayerSettings?.copyWith(showTahajjud: v) ??
                                PrayerSettings(showTahajjud: v),
                          );
                          _persistPrayerSettings();
                        },
                      ),
                      onTap: () {
                        setState(
                          () => _prayerSettings =
                              _prayerSettings?.copyWith(
                                showTahajjud:
                                    !(_prayerSettings?.showTahajjud ?? true),
                              ) ??
                              PrayerSettings(showTahajjud: true),
                        );
                        _persistPrayerSettings();
                      },
                    ),
                    const SizedBox(height: 12),
                  ],

                  Text(
                    tr('others') == 'others' ? 'LAINNYA' : tr('others'),
                    style: TextStyle(
                      color: accentColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  _buildActionButton(
                    title: tr('about_qibla_compass'),
                    subtitle: tr('version'),
                    icon: Icons.info,
                    onTap: () => _showInfoDialog(
                      tr('about_qibla_compass'),
                      tr('about_qibla_desc'),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: tr('contact_us'),
                    subtitle: tr('contact_us_desc'),
                    icon: Icons.mail,
                    onTap: _showContactDialog,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: tr('privacy_policy'),
                    subtitle: tr('privacy_policy'),
                    icon: Icons.verified_user,
                    onTap: _showPrivacyPolicyDialog,
                  ),

                  const SizedBox(height: 18),
                  // Open source note + GitHub button
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('open_source'),
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: tr('view_on_github'),
                          icon: Icon(
                            Icons.code,
                            color: accentColor,
                          ),
                          onPressed: () => _openUrl(
                            Uri.parse('https://github.com/onyet/kiblat'),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
    final cardColor = AppTheme.getCardColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: accentColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: secTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _buildWatchAdCard() {
    final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);

    return InkWell(
      onTap: _handleWatchAd,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [accentColor.withOpacity(0.2), accentColor.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accentColor.withOpacity(0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accentColor.withOpacity(0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.play_circle_outline,
                color: accentColor,
                size: 26,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('watch_ad_support') == 'watch_ad_support'
                        ? 'Support Developer'
                        : tr('watch_ad_support'),
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr('watch_ad_support_desc') == 'watch_ad_support_desc'
                        ? 'Watch a short ad to help keep this app free'
                        : tr('watch_ad_support_desc'),
                    style: TextStyle(color: secTextColor, fontSize: 11),
                  ),
                ],
              ),
            ),
            Icon(Icons.favorite, color: accentColor, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWatchAd() async {
    final messenger = ScaffoldMessenger.of(context);

    if (!AdService.instance.isInterstitialAdReady) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('ad_not_ready') == 'ad_not_ready'
                ? 'Ad is not ready yet. Please try again later.'
                : tr('ad_not_ready'),
          ),
        ),
      );
      return;
    }

    final shown = await AdService.instance.showInterstitialAd(
      timeout: const Duration(seconds: 7),
    );

    if (!mounted) return;

    _refreshAdStatus();

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          shown
              ? (tr('watch_ad_thanks') == 'watch_ad_thanks'
                    ? 'Thank you for your support! ❤️'
                    : tr('watch_ad_thanks'))
              : (tr('ad_not_completed') == 'ad_not_completed'
                    ? 'Ad could not be shown. Thanks anyway!'
                    : tr('ad_not_completed')),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) {
    final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);
    return TextButton(
      onPressed: onTap,
      child: Text(
        label,
        style: TextStyle(
          color: accentColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _statusChip(String label, Color bg) {
    final bgColor = bg.withAlpha((0.12 * 255).round());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: bg == Colors.green ? Colors.greenAccent : Colors.redAccent,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required String title,
    required String subtitle,
    required IconData icon,
    VoidCallback? onTap,
  }) {
    final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
    final isLight = AppTheme.isLight(settings, context);
    final cardColor = AppTheme.getCardColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final borderColor = AppTheme.getBorderColor(settings, context);

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: borderColor),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isLight ? Colors.black.withOpacity(0.04) : const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: secTextColor),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(color: secTextColor, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: secTextColor.withOpacity(0.4)),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final locales = EasyLocalization.of(context)!.supportedLocales;
    final current = EasyLocalization.of(context)!.locale;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr('choose_language') == 'choose_language'
              ? tr('language')
              : tr('choose_language'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: locales
                .map(
                  (loc) => ListTile(
                    title: Text(_localeLabel(loc)),
                    trailing: loc == current
                        ? const Icon(Icons.check, color: Color(0xFFF4C025))
                        : null,
                    onTap: () async {
                      final el = EasyLocalization.of(context);
                      // close dialog first to avoid using dialog context after awaiting
                      Navigator.of(ctx, rootNavigator: true).pop();
                      await el!.setLocale(loc);
                      if (!mounted) return;
                      setState(() {});
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _openUrl(Uri url) async {
    final messenger = ScaffoldMessenger.of(context);
    final errMsg = tr('could_not_open');
    try {
      final opened = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (!opened) {
        messenger.showSnackBar(SnackBar(content: Text(errMsg)));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(errMsg)));
    }
  }

  String _localeLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'in':
        return 'Bahasa Indonesia';
      case 'en':
        return 'English';
      case 'ar':
        return 'العربية';
      case 'ja':
        return '日本語';
      case 'pt':
        return 'Português';
      case 'ru':
        return 'Русский';
      case 'zh':
        return '中文';
      case 'de':
        return 'Deutsch';
      default:
        return locale.languageCode.toUpperCase();
    }
  }

  Future<void> _showMadhabDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('madhab') == 'madhab' ? 'Madhab' : tr('madhab')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: Madhab.values
                .map(
                  (m) => ListTile(
                    title: Text(PrayerSettings.madhubDisplay(m)),
                    trailing: _selectedMadhab == m
                        ? const Icon(Icons.check, color: Color(0xFFF4C025))
                        : null,
                    onTap: () {
                      Navigator.of(ctx, rootNavigator: true).pop();
                      setState(() {
                        _selectedMadhab = m;
                      });
                      _persistPrayerSettings();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showCalculationMethodDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr('calculation_method') == 'calculation_method'
              ? 'Calculation Method'
              : tr('calculation_method'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: CalculationMethod.values
                .map(
                  (m) => ListTile(
                    title: Text(PrayerSettings.calculationMethodDisplay(m)),
                    trailing: _selectedMethod == m
                        ? const Icon(Icons.check, color: Color(0xFFF4C025))
                        : null,
                    onTap: () {
                      Navigator.of(ctx, rootNavigator: true).pop();
                      setState(() {
                        _selectedMethod = m;
                      });
                      _persistPrayerSettings();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showHighLatitudeDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr('high_latitude_rule') == 'high_latitude_rule'
              ? 'High Latitude Rule'
              : tr('high_latitude_rule'),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: HighLatitudeRule.values
                .map(
                  (m) => ListTile(
                    title: Text(PrayerSettings.highLatitudeRuleDisplay(m)),
                    trailing: _selectedHighLatitudeRule == m
                        ? const Icon(Icons.check, color: Color(0xFFF4C025))
                        : null,
                    onTap: () {
                      Navigator.of(ctx, rootNavigator: true).pop();
                      setState(() {
                        _selectedHighLatitudeRule = m;
                      });
                      _persistPrayerSettings();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _showAdjustmentDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr('adjustment_minutes') == 'adjustment_minutes'
              ? 'Adjustment Minutes'
              : tr('adjustment_minutes'),
        ),
        content: TextField(
          controller: _adjustmentController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'e.g. 0, 2, -1'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: Text(tr('dismiss')),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(_adjustmentController.text) ?? 0;
              setState(() {
                _adjustmentController.text = val.toString();
              });
              Navigator.of(ctx, rootNavigator: true).pop();
              _persistPrayerSettings();
            },
            child: Text(tr('apply')),
          ),
        ],
      ),
    );
  }

  Future<void> _showTimezoneDialog() async {
    final timezones = TimezoneUtil.popularTimezones;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('timezone') == 'timezone' ? 'Timezone' : tr('timezone')),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: timezones
                .map(
                  (tzId) => ListTile(
                    title: Text(
                      tzId == 'Device Timezone' ? tr('device_timezone') : tzId,
                    ),
                    subtitle: tzId == 'Device Timezone'
                        ? Text(TimezoneUtil.getOffsetString(null))
                        : Text(TimezoneUtil.getOffsetString(tzId)),
                    trailing: _selectedTimezoneId == tzId
                        ? const Icon(Icons.check, color: Color(0xFFF4C025))
                        : null,
                    onTap: () {
                      setState(() {
                        _selectedTimezoneId = tzId == 'Device Timezone'
                            ? null
                            : tzId;
                      });
                      Navigator.of(ctx, rootNavigator: true).pop();
                      _persistPrayerSettings();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  /// Persist current selection-based prayer settings to storage and update UI.
  Future<void> _persistPrayerSettings({bool showToast = true}) async {
    final adjustment = int.tryParse(_adjustmentController.text) ?? 0;
    final newSettings = PrayerSettings(
      madhab: _selectedMadhab ?? PrayerSettings().madhab,
      calculationMethod: _selectedMethod ?? PrayerSettings().calculationMethod,
      highLatitudeRule:
          _selectedHighLatitudeRule ?? PrayerSettings().highLatitudeRule,
      adjustmentMinutes: adjustment,
      showSunnahTimes: _prayerSettings?.showSunnahTimes ?? true,
      showDhuha: _prayerSettings?.showDhuha ?? true,
      showTahajjud: _prayerSettings?.showTahajjud ?? true,
      timezoneId: _selectedTimezoneId == 'Device Timezone'
          ? null
          : _selectedTimezoneId,
      enablePrayerNotifications:
          _prayerSettings?.enablePrayerNotifications ?? true,
      customRingtonePath: _prayerSettings?.customRingtonePath,
      customRingtoneName: _prayerSettings?.customRingtoneName,
      isProUser: _prayerSettings?.isProUser ?? false,
      defaultLaunchScreen: _prayerSettings?.defaultLaunchScreen ?? 'compass',
      compassTheme: _prayerSettings?.compassTheme ?? 'classic',
    );

    try {
      // Ensure we carry over the time format preference when saving
      final withFormat = newSettings.copyWith(
        use24Hour: _prayerSettings?.use24Hour ?? newSettings.use24Hour,
      );

      // Persist and notify via SettingsService so other screens can react immediately
      await SettingsService.instance.update(withFormat);

      if (!mounted) return;
      setState(() {
        _prayerSettings = withFormat;
      });

      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(tr('settings_saved')),
            duration: const Duration(milliseconds: 900),
          ),
        );
      }
    } catch (_) {
      // Silently ignore storage errors for now
    }
  }

  void _toggleShowSunnahTimes(bool value) {
    if (!mounted) return;
    setState(() {
      _prayerSettings =
          _prayerSettings?.copyWith(showSunnahTimes: value) ??
          PrayerSettings(showSunnahTimes: value);
    });
    _persistPrayerSettings();
  }

  void _toggleTimeFormat(bool use24) {
    if (!mounted) return;
    setState(() {
      _prayerSettings =
          _prayerSettings?.copyWith(use24Hour: use24) ??
          PrayerSettings(use24Hour: use24);
    });
    _persistPrayerSettings();
  }

  // Contact & Privacy dialogs

  /// Show custom ringtone options dialog
  Future<void> _showCustomRingtoneDialog() async {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          tr('custom_ringtone') == 'custom_ringtone'
              ? 'Custom Adzan Ringtone'
              : tr('custom_ringtone'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star, color: Color(0xFFF4C025)),
              title: const Text('Muadzin Premium (Pro)'),
              subtitle: const Text('Pilih suara Adzan terbaik di dunia'),
              onTap: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                _showPremiumAdzanDialog();
              },
            ),
            const Divider(),
            if (_prayerSettings?.customRingtoneName != null) ...[
              ListTile(
                leading: const Icon(Icons.music_note, color: Color(0xFFF4C025)),
                title: Text(
                  tr('current_ringtone') == 'current_ringtone'
                      ? 'Current'
                      : tr('current_ringtone'),
                ),
                subtitle: Text(_prayerSettings!.customRingtoneName!),
              ),
              const Divider(),
            ],
            ListTile(
              leading: const Icon(Icons.notifications_active, color: Color(0xFFF4C025)),
              title: const Text('Uji Notifikasi'),
              subtitle: const Text('Tes pemutaran suara notifikasi Adzan saat ini'),
              onTap: () {
                Navigator.of(ctx, rootNavigator: true).pop();
                if (_prayerSettings != null) {
                  NotificationService.instance.triggerTestNotification(_prayerSettings!);
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Color(0xFFF4C025)),
              title: Text(
                tr('upload_custom_ringtone') == 'upload_custom_ringtone'
                    ? 'Upload Custom Adzan'
                    : tr('upload_custom_ringtone'),
              ),
              subtitle: Text(
                tr('watch_ad_to_unlock') == 'watch_ad_to_unlock'
                    ? 'Watch a short ad to unlock'
                    : tr('watch_ad_to_unlock'),
              ),
              onTap: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await _handleCustomRingtoneUpload();
              },
            ),
            if (_prayerSettings?.customRingtonePath != null)
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.redAccent),
                title: Text(
                  tr('reset_to_default') == 'reset_to_default'
                      ? 'Reset to Default'
                      : tr('reset_to_default'),
                ),
                onTap: () async {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  await _resetRingtone();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: Text(tr('dismiss')),
          ),
        ],
      ),
    );
  }

  /// Handle custom ringtone upload: show rewarded ad, then pick file
  Future<void> _handleCustomRingtoneUpload() async {
    final messenger = ScaffoldMessenger.of(context);
    final adService = AdService.instance;
    final isPro = _prayerSettings?.isProUser ?? false;

    if (AdService.bypassRewardedGate || isPro) {
      await _pickAndSaveRingtone();
      return;
    }

    // Show loading indicator
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          tr('loading_ad') == 'loading_ad' ? 'Loading ad...' : tr('loading_ad'),
        ),
        duration: const Duration(seconds: 2),
      ),
    );

    // Show rewarded ad first. Test ads can still load asynchronously, so wait a
    // little instead of failing immediately.
    final ready = await adService.waitForRewardedAdReady();
    if (!ready) {
      if (!mounted) return;
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('ad_not_ready') == 'ad_not_ready'
                ? 'Ad is not ready yet. Please try again later.'
                : tr('ad_not_ready'),
          ),
        ),
      );
      return;
    }

    messenger.hideCurrentSnackBar();

    // Show the rewarded ad
    final earned = await adService.showRewardedAd();
    if (!earned) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('ad_not_completed') == 'ad_not_completed'
                ? 'Please watch the full ad to unlock custom ringtone.'
                : tr('ad_not_completed'),
          ),
        ),
      );
      return;
    }

    // User earned the reward — now pick the audio file
    if (!mounted) return;
    await _pickAndSaveRingtone();
  }

  /// Pick an audio file and save it as custom ringtone
  Future<void> _pickAndSaveRingtone() async {
    final messenger = ScaffoldMessenger.of(context);

    try {
      if (Platform.isAndroid) {
        final result = await _platformChannel.invokeMapMethod<String, String>(
          'pickNotificationSound',
        );

        if (result == null) return;

        final uri = result['uri'];
        if (uri == null || uri.isEmpty) return;

        final fileName = result['name'] ?? 'Custom adzan';

        if (!mounted) return;
        setState(() {
          _prayerSettings =
              _prayerSettings?.copyWith(
                customRingtonePath: uri,
                customRingtoneName: fileName,
              ) ??
              PrayerSettings(
                customRingtonePath: uri,
                customRingtoneName: fileName,
              );
        });
        await _persistPrayerSettings(showToast: false);

        if (_prayerSettings?.enablePrayerNotifications ?? false) {
          await NotificationService.instance
              .schedulePrayerNotificationsForCurrentLocation(_prayerSettings!);
        }

        messenger.showSnackBar(
          SnackBar(
            content: Text(
              tr('ringtone_set_success') == 'ringtone_set_success'
                  ? 'Custom adzan ringtone set: $fileName'
                  : tr('ringtone_set_success'),
            ),
          ),
        );
        return;
      }

      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
      );

      if (result == null || result.files.isEmpty) return;

      final file = result.files.first;
      if (file.path == null) return;

      // Copy the file to app's storage directory
      final appDir = await getApplicationSupportDirectory();
      final destDir = Directory('${appDir.path}/ringtones');
      if (!await destDir.exists()) {
        await destDir.create(recursive: true);
      }

      final ext = file.extension ?? 'mp3';
      final destPath = '${destDir.path}/custom_adzan.$ext';
      final sourceFile = File(file.path!);
      await sourceFile.copy(destPath);

      final fileName = file.name;

      if (!mounted) return;
      setState(() {
        _prayerSettings =
            _prayerSettings?.copyWith(
              customRingtonePath: destPath,
              customRingtoneName: fileName,
            ) ??
            PrayerSettings(
              customRingtonePath: destPath,
              customRingtoneName: fileName,
            );
      });
      await _persistPrayerSettings(showToast: false);

      // Reschedule notifications with new sound
      if (_prayerSettings?.enablePrayerNotifications ?? false) {
        await NotificationService.instance
            .schedulePrayerNotificationsForCurrentLocation(_prayerSettings!);
      }

      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('ringtone_set_success') == 'ringtone_set_success'
                ? 'Custom adzan ringtone set: $fileName'
                : tr('ringtone_set_success'),
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            tr('ringtone_set_failed') == 'ringtone_set_failed'
                ? 'Failed to set custom ringtone'
                : tr('ringtone_set_failed'),
          ),
        ),
      );
    }
  }

  /// Reset ringtone back to default
  Future<void> _resetRingtone() async {
    if (!mounted) return;
    setState(() {
      _prayerSettings =
          _prayerSettings?.copyWith(clearCustomRingtone: true) ??
          PrayerSettings();
    });
    await _persistPrayerSettings(showToast: false);

    // Reschedule notifications with default sound
    if (_prayerSettings?.enablePrayerNotifications ?? false) {
      await NotificationService.instance
          .schedulePrayerNotificationsForCurrentLocation(_prayerSettings!);
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          tr('ringtone_reset_success') == 'ringtone_reset_success'
              ? 'Ringtone reset to default'
              : tr('ringtone_reset_success'),
        ),
      ),
    );
  }

  Future<void> _showPrivacyPolicyDialog() async {
    final url = Uri.parse('https://onyet.github.io/privacy-police.html');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('privacy_policy')),
        content: Text(url.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: Text(tr('dismiss')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx, rootNavigator: true).pop();
              await _openUrl(url);
            },
            child: Text(tr('open')),
          )
        ],
      ),
    );
  }

  Future<void> _showContactDialog() async {
    const whatsapp = 'https://wa.me/6282221874400';
    const email = 'mailto:onyetcorp@gmail.com';
    const phone = 'tel:+6282221874400';

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('contact_us')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.chat, color: Color(0xFF25D366)),
              title: Text(tr('contact_whatsapp')),
              subtitle: const Text('+62 822-2187-4400'),
              onTap: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await _openUrl(Uri.parse(whatsapp));
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(tr('contact_email')),
              subtitle: const Text('onyetcorp@gmail.com'),
              onTap: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await _openUrl(Uri.parse(email));
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(tr('contact_phone')),
              subtitle: const Text('+62 822-2187-4400'),
              onTap: () async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await _openUrl(Uri.parse(phone));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
            child: Text(tr('dismiss')),
          ),
        ],
      ),
    );
  }

  Widget _buildProCard() {
    final isPro = _prayerSettings?.isProUser ?? false;
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPro
              ? [const Color(0xFF0F1E12), const Color(0xFF071009)]
              : [const Color(0xFF1F1B0F), const Color(0xFF100E08)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isPro ? const Color(0xFF4CAF50).withOpacity(0.5) : const Color(0xFFD4AF37).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isPro ? Colors.green.withOpacity(0.1) : const Color(0xFFD4AF37).withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isPro ? Icons.verified : Icons.stars,
                color: isPro ? const Color(0xFF4CAF50) : const Color(0xFFD4AF37),
                size: 24,
              ),
              const SizedBox(width: 8),
              Text(
                isPro ? 'Kiblat Pro Aktif' : 'Tingkatkan ke Kiblat Pro',
                style: TextStyle(
                  color: isPro ? const Color(0xFF4CAF50) : const Color(0xFFD4AF37),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CAF50).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'PRIVAT & OFFLINE',
                    style: TextStyle(
                      color: Color(0xFF4CAF50),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isPro
                ? 'Terima kasih atas dukungan Anda! Aplikasi ini berjalan bebas dari iklan, tanpa telemetri/pelacakan apa pun, dan semua fitur terbuka penuh 100% offline.'
                : 'Nikmati pencarian kiblat yang lebih khusyuk: bebas iklan total (privasi tinggi), tanpa telemetri, buka suara Adzan premium, dan tema kompas eksklusif.',
            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 12),
          if (!isPro) ...[
            if (BillingService.instance.isPendingPurchase.value)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    color: Color(0xFFD4AF37),
                    strokeWidth: 2.5,
                  ),
                ),
              )
            else ...[
              SizedBox(
                width: double.infinity,
                height: 40,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFD4AF37),
                    foregroundColor: Colors.black,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: BillingService.instance.isStoreAvailable.value
                      ? () => BillingService.instance.buyPro()
                      : null,
                  child: Text(
                    BillingService.instance.isStoreAvailable.value
                        ? 'Beli Kiblat Pro ${BillingService.instance.productsNotifier.value.isNotEmpty ? "(${BillingService.instance.productsNotifier.value.first.price})" : ""}'
                        : 'Beli Pro (Store Tidak Tersedia)',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              if (kDebugMode) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: const BorderSide(color: Colors.white24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: BillingService.instance.isStoreAvailable.value
                            ? () => BillingService.instance.restorePurchases()
                            : null,
                        child: const Text(
                          'Pulihkan Pembelian',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white54,
                          side: const BorderSide(color: Colors.white10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: EdgeInsets.zero,
                        ),
                        onPressed: () => _toggleProStatus(true),
                        child: const Text(
                          'Simulasi Gratis',
                          style: TextStyle(fontSize: 11),
                        ),
                      ),
                    ),
                  ],
                ),
              ] else ...[
                SizedBox(
                  width: double.infinity,
                  height: 38,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white70,
                      side: const BorderSide(color: Colors.white24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: BillingService.instance.isStoreAvailable.value
                        ? () => BillingService.instance.restorePurchases()
                        : null,
                    child: const Text(
                      'Pulihkan Pembelian',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ],
          ] else ...[
            if (kDebugMode) ...[
              SizedBox(
                width: double.infinity,
                height: 38,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    foregroundColor: Colors.white70,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Colors.white24),
                    ),
                  ),
                  onPressed: () => _toggleProStatus(false),
                  child: const Text(
                    'Nonaktifkan Pro (Simulasi)',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Future<void> _toggleProStatus(bool isPro) async {
    var updated = _prayerSettings?.copyWith(isProUser: isPro) ?? PrayerSettings(isProUser: isPro);
    if (!isPro) {
      updated = updated.copyWith(compassTheme: 'classic');
    }
    await SettingsService.instance.update(updated);

    if (isPro) {
      AdService.instance.dispose();
    } else {
      await AdService.initialize();
    }

    if (!mounted) return;
    setState(() {
      _prayerSettings = updated;
    });
  }

  void _showDefaultLaunchScreenDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
        final cardColor = AppTheme.getCardColor(settings, context);
        final textColor = AppTheme.getTextColor(settings, context);
        final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Pilih Tampilan Awal Aplikasi',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(
                  EasyLocalization.of(context) != null ? tr('launch_compass_title') : 'Kompas Kiblat (Fokus Utama)',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  EasyLocalization.of(context) != null ? tr('launch_compass_desc') : 'Membuka kompas pencari arah kiblat secara langsung',
                  style: TextStyle(color: secTextColor, fontSize: 12),
                ),
                value: 'compass',
                groupValue: _prayerSettings?.defaultLaunchScreen ?? 'compass',
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    final updated = _prayerSettings?.copyWith(defaultLaunchScreen: val) ?? PrayerSettings(defaultLaunchScreen: val);
                    await SettingsService.instance.update(updated);
                    setState(() => _prayerSettings = updated);
                    // Immediately switch to Kompas tab
                    MainShell.switchTab(0);
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  EasyLocalization.of(context) != null ? tr('launch_prayer_title') : 'Jadwal Shalat Lengkap',
                  style: TextStyle(color: textColor),
                ),
                subtitle: Text(
                  EasyLocalization.of(context) != null ? tr('launch_prayer_desc') : 'Membuka jadwal shalat lengkap saat aplikasi pertama dibuka',
                  style: TextStyle(color: secTextColor, fontSize: 12),
                ),
                value: 'prayer_times',
                groupValue: _prayerSettings?.defaultLaunchScreen ?? 'compass',
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    final updated = _prayerSettings?.copyWith(defaultLaunchScreen: val) ?? PrayerSettings(defaultLaunchScreen: val);
                    await SettingsService.instance.update(updated);
                    setState(() => _prayerSettings = updated);
                    // Immediately switch to Jadwal tab
                    MainShell.switchTab(1);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('dismiss'), style: TextStyle(color: secTextColor)),
            ),
          ],
        );
      },
    );
  }

  void _showPremiumAdzanDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final isPro = _prayerSettings?.isProUser ?? false;
        return _PremiumAdzanDialog(
          isPro: isPro,
          selectedRingtonePath: _prayerSettings?.customRingtonePath,
          onSelect: (name, asset) {
            _setPremiumAdzan(name, asset);
          },
          onShowProPrompt: (feature, description) {
            _showProPromptDialog(feature: feature, description: description);
          },
        );
      },
    );
  }

  void _showProPromptDialog({required String feature, required String description}) {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
        final cardColor = AppTheme.getCardColor(settings, context);
        final textColor = AppTheme.getTextColor(settings, context);
        final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);
        final borderColor = AppTheme.getBorderColor(settings, context);

        return AlertDialog(
          backgroundColor: cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accentColor, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.stars, color: accentColor, size: 28),
              const SizedBox(width: 10),
              Text(
                'Tingkatkan ke Kiblat Pro',
                style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Fitur ini memerlukan Kiblat Pro:',
                  style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Text(
                  '• $feature',
                  style: TextStyle(color: accentColor, fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Text(
                  description,
                  style: TextStyle(color: secTextColor, fontSize: 13, height: 1.4),
                ),
                const SizedBox(height: 16),
                Divider(color: borderColor),
                const SizedBox(height: 10),
                Text(
                  'Keunggulan Privasi & Fitur Pro:',
                  style: TextStyle(color: textColor.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13),
                ),
                const SizedBox(height: 8),
                Text('✅ Bebas Iklan Total (Meningkatkan Privasi dari Ad Networks)', style: TextStyle(color: secTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                Text('✅ Tanpa Telemetri (Data Penggunaan 100% Privat/Offline)', style: TextStyle(color: secTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                Text('✅ Akses Suara Adzan Premium Offline Tanpa Iklan', style: TextStyle(color: secTextColor, fontSize: 12)),
                const SizedBox(height: 4),
                Text('✅ Buka 3 Tema Estetik Kompas Kiblat', style: TextStyle(color: secTextColor, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(),
              child: Text('Batal', style: TextStyle(color: secTextColor)),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFBF953F), Color(0xFFFCF6BA), Color(0xFFBF953F)],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                onPressed: () async {
                  Navigator.of(ctx, rootNavigator: true).pop();
                  if (kDebugMode) {
                    await _toggleProStatus(true);
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Selamat! Anda sekarang menggunakan Kiblat Pro (Simulasi) 🎉'),
                          backgroundColor: Color(0xFFD4AF37),
                        ),
                      );
                    }
                  } else {
                    if (BillingService.instance.isStoreAvailable.value) {
                      await BillingService.instance.buyPro();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Pembelian dalam aplikasi saat ini tidak tersedia.'),
                        ),
                      );
                    }
                  }
                },
                child: Text(
                  kDebugMode ? 'Aktifkan Pro (Gratis)' : 'Beli Kiblat Pro',
                  style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _setPremiumAdzan(String name, String assetBaseName) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      String path;
      if (Platform.isAndroid) {
        path = 'android.resource://id.onyet.app.kiblat/raw/$assetBaseName';
      } else if (Platform.isIOS) {
        final libDir = await getLibraryDirectory();
        final soundsDir = Directory('${libDir.path}/Sounds');
        if (!await soundsDir.exists()) {
          await soundsDir.create(recursive: true);
        }
        final destPath = '${soundsDir.path}/$assetBaseName.mp3';
        final file = File(destPath);
        if (!await file.exists()) {
          final byteData = await rootBundle.load('assets/audio/$assetBaseName.mp3');
          await file.writeAsBytes(byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
        }
        path = '$assetBaseName.mp3';
      } else {
        path = 'assets/audio/$assetBaseName.mp3';
      }

      final updated = _prayerSettings?.copyWith(
        customRingtonePath: path,
        customRingtoneName: name,
      ) ?? PrayerSettings(
        customRingtonePath: path,
        customRingtoneName: name,
      );

      await SettingsService.instance.update(updated);

      if (mounted) {
        setState(() {
          _prayerSettings = updated;
        });
      }

      await NotificationService.instance.schedulePrayerNotificationsForCurrentLocation(updated);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Berhasil menyetel $name sebagai suara notifikasi adzan'),
          backgroundColor: const Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Gagal menyetel adzan premium: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _themeDisplay(String theme) {
    switch (theme) {
      case 'gold':
        return 'Gold Arabesque (Pro)';
      case 'dark':
        return 'Minimalist Dark (Pro)';
      case 'cyber':
        return 'Cyber Qibla (Pro)';
      case 'classic':
      default:
        return 'Classic (Free)';
    }
  }

  void _showThemeSelectionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
        final isPro = settings.isProUser;
        final currentTheme = settings.compassTheme;
        final cardColor = AppTheme.getCardColor(settings, context);
        final textColor = AppTheme.getTextColor(settings, context);
        final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Pilih Tema Aplikasi',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('Classic (Free)', style: TextStyle(color: textColor)),
                subtitle: Text('Tema klasik warna kuning keemasan khas', style: TextStyle(color: secTextColor, fontSize: 12)),
                value: 'classic',
                groupValue: currentTheme,
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    final updated = _prayerSettings?.copyWith(compassTheme: val) ?? PrayerSettings(compassTheme: val);
                    await SettingsService.instance.update(updated);
                    setState(() {
                      _prayerSettings = updated;
                    });
                  }
                },
              ),
              RadioListTile<String>(
                title: Text('Gold Arabesque (Pro)', style: TextStyle(color: textColor)),
                subtitle: Text('Desain arabesque premium berwarna emas murni', style: TextStyle(color: secTextColor, fontSize: 12)),
                value: 'gold',
                groupValue: currentTheme,
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    if (!isPro) {
                      _showProPromptDialog(
                        feature: 'Tema Gold Arabesque',
                        description: 'Tingkatkan ke Pro untuk menggunakan tema kompas premium eksklusif Gold Arabesque.',
                      );
                    } else {
                      final updated = _prayerSettings?.copyWith(compassTheme: val) ?? PrayerSettings(compassTheme: val);
                      await SettingsService.instance.update(updated);
                      setState(() {
                        _prayerSettings = updated;
                      });
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: Text('Minimalist Dark (Pro)', style: TextStyle(color: textColor)),
                subtitle: Text('Desain gelap minimalis dan bersih untuk malam hari', style: TextStyle(color: secTextColor, fontSize: 12)),
                value: 'dark',
                groupValue: currentTheme,
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    if (!isPro) {
                      _showProPromptDialog(
                        feature: 'Tema Minimalist Dark',
                        description: 'Tingkatkan ke Pro untuk menggunakan tema kompas premium eksklusif Minimalist Dark.',
                      );
                    } else {
                      final updated = _prayerSettings?.copyWith(compassTheme: val) ?? PrayerSettings(compassTheme: val);
                      await SettingsService.instance.update(updated);
                      setState(() {
                        _prayerSettings = updated;
                      });
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: Text('Cyber Qibla (Pro)', style: TextStyle(color: textColor)),
                subtitle: Text('Gaya futuristik dengan aksen cyan dan neon', style: TextStyle(color: secTextColor, fontSize: 12)),
                value: 'cyber',
                groupValue: currentTheme,
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    if (!isPro) {
                      _showProPromptDialog(
                        feature: 'Tema Cyber Qibla',
                        description: 'Tingkatkan ke Pro untuk menggunakan tema kompas premium eksklusif Cyber Qibla.',
                      );
                    } else {
                      final updated = _prayerSettings?.copyWith(compassTheme: val) ?? PrayerSettings(compassTheme: val);
                      await SettingsService.instance.update(updated);
                      setState(() {
                        _prayerSettings = updated;
                      });
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('dismiss'), style: TextStyle(color: secTextColor)),
            ),
          ],
        );
      },
    );
  }

  String _displayModeDisplay(String mode) {
    switch (mode) {
      case 'light':
        return 'Terang (Pro)';
      case 'system':
        return 'Ikuti Sistem (Pro)';
      case 'dark':
      default:
        return 'Gelap (Free)';
    }
  }

  void _showDisplayModeSelectionDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) {
        final settings = _prayerSettings ?? SettingsService.instance.notifier.value;
        final isPro = settings.isProUser;
        final currentMode = settings.displayMode;
        final cardColor = AppTheme.getCardColor(settings, context);
        final textColor = AppTheme.getTextColor(settings, context);
        final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);

        return AlertDialog(
          backgroundColor: cardColor,
          title: Text(
            'Pilih Mode Tampilan',
            style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text('Gelap (Free)', style: TextStyle(color: textColor)),
                subtitle: Text('Gaya gelap hemat daya baterai', style: TextStyle(color: secTextColor, fontSize: 12)),
                value: 'dark',
                groupValue: currentMode,
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    final updated = _prayerSettings?.copyWith(displayMode: val) ?? PrayerSettings(displayMode: val);
                    await SettingsService.instance.update(updated);
                    setState(() {
                      _prayerSettings = updated;
                    });
                  }
                },
              ),
              RadioListTile<String>(
                title: Text('Terang (Pro)', style: TextStyle(color: textColor)),
                subtitle: Text('Gaya terang dengan latar belakang bersih', style: TextStyle(color: secTextColor, fontSize: 12)),
                value: 'light',
                groupValue: currentMode,
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    if (!isPro) {
                      _showProPromptDialog(
                        feature: 'Mode Tampilan Terang',
                        description: 'Tingkatkan ke Pro untuk mengaktifkan Mode Tampilan Terang.',
                      );
                    } else {
                      final updated = _prayerSettings?.copyWith(displayMode: val) ?? PrayerSettings(displayMode: val);
                      await SettingsService.instance.update(updated);
                      setState(() {
                        _prayerSettings = updated;
                      });
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: Text('Ikuti Sistem (Pro)', style: TextStyle(color: textColor)),
                subtitle: Text('Mode tampilan mengikuti pengaturan sistem perangkat Anda', style: TextStyle(color: secTextColor, fontSize: 12)),
                value: 'system',
                groupValue: currentMode,
                activeColor: accentColor,
                onChanged: (val) async {
                  Navigator.of(ctx).pop();
                  if (val != null) {
                    if (!isPro) {
                      _showProPromptDialog(
                        feature: 'Mode Tampilan Ikuti Sistem',
                        description: 'Tingkatkan ke Pro agar mode tampilan otomatis mengikuti sistem perangkat.',
                      );
                    } else {
                      final updated = _prayerSettings?.copyWith(displayMode: val) ?? PrayerSettings(displayMode: val);
                      await SettingsService.instance.update(updated);
                      setState(() {
                        _prayerSettings = updated;
                      });
                    }
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(tr('dismiss'), style: TextStyle(color: secTextColor)),
            ),
          ],
        );
      },
    );
  }
}

class _PremiumAdzanDialog extends StatefulWidget {
  final bool isPro;
  final String? selectedRingtonePath;
  final Function(String name, String asset) onSelect;
  final Function(String feature, String description) onShowProPrompt;

  const _PremiumAdzanDialog({
    required this.isPro,
    required this.selectedRingtonePath,
    required this.onSelect,
    required this.onShowProPrompt,
  });

  @override
  State<_PremiumAdzanDialog> createState() => _PremiumAdzanDialogState();
}

class _PremiumAdzanDialogState extends State<_PremiumAdzanDialog> {
  late final AudioPlayer _audioPlayer;
  String? _playingAsset;
  PlayerState _playerState = PlayerState.stopped;
  StreamSubscription? _playerStateSubscription;

  final List<Map<String, String>> _adzans = const [
    {'name': 'Adzan Makkah (Masjidil Haram)', 'asset': 'adzan_makkah'},
    {'name': 'Adzan Madinah (Masjid Nabawi)', 'asset': 'adzan_madinah'},
    {'name': 'Adzan Al-Aqsa (Yerusalem)', 'asset': 'adzan_al_aqsa'},
    {'name': 'Adzan Mesir (Bayati Style)', 'asset': 'adzan_mesir'},
    {'name': 'Adzan Yusuf Islam', 'asset': 'adzan_yusuf_islam'},
  ];

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _playerState = state;
          if (state == PlayerState.completed || state == PlayerState.stopped) {
            _playingAsset = null;
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _playerStateSubscription?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playPause(String assetName) async {
    try {
      if (_playingAsset == assetName && _playerState == PlayerState.playing) {
        await _audioPlayer.stop();
        setState(() {
          _playingAsset = null;
          _playerState = PlayerState.stopped;
        });
      } else {
        await _audioPlayer.stop();
        setState(() {
          _playingAsset = assetName;
          _playerState = PlayerState.playing;
        });
        await _audioPlayer.play(AssetSource('audio/$assetName.mp3'));
      }
    } catch (e) {
      debugPrint("Error playing preview: $e");
    }
  }

  bool _isCurrentlySelected(String assetName) {
    if (widget.selectedRingtonePath == null) return false;
    return widget.selectedRingtonePath!.contains(assetName);
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final cardColor = AppTheme.getCardColor(settings, context);
    final textColor = AppTheme.getTextColor(settings, context);
    final secTextColor = AppTheme.getSecondaryTextColor(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);

    return AlertDialog(
      backgroundColor: cardColor,
      title: Text(
        'Muadzin Premium (Pro)',
        style: TextStyle(color: textColor, fontWeight: FontWeight.bold),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _adzans.length,
          itemBuilder: (context, index) {
            final adzan = _adzans[index];
            final assetName = adzan['asset']!;
            final name = adzan['name']!;
            final isPlayingThis = _playingAsset == assetName && _playerState == PlayerState.playing;
            final isSelected = _isCurrentlySelected(assetName);

            return ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.music_note,
                color: isSelected ? accentColor : secTextColor.withOpacity(0.6),
              ),
              title: Text(
                name,
                style: TextStyle(
                  color: isSelected ? accentColor : textColor,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  isPlayingThis ? Icons.stop_circle : Icons.play_circle_fill,
                  color: isPlayingThis ? Colors.redAccent : accentColor,
                  size: 28,
                ),
                onPressed: () => _playPause(assetName),
              ),
              onTap: () {
                if (!widget.isPro) {
                  Navigator.of(context).pop();
                  widget.onShowProPrompt(
                    'Dukungan Muadzin Premium',
                    'Tingkatkan ke Pro untuk menyetel suara Adzan termerdu dari berbagai belahan dunia secara offline.',
                  );
                } else {
                  Navigator.of(context).pop();
                  widget.onSelect(name, assetName);
                }
              },
            );
          },
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(tr('dismiss'), style: TextStyle(color: secTextColor)),
        ),
      ],
    );
  }
}
