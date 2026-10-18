import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
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
import 'package:permission_handler/permission_handler.dart';
import 'dart:io';
import 'dart:async';

import '../services/location_service.dart';
import 'package:kiblat/services/notification_service.dart';
import 'package:kiblat/services/billing_service.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:kiblat/services/ad_service.dart';
import 'package:kiblat/models/location_profile.dart';
import 'package:kiblat/services/location_profile_service.dart';
import 'package:kiblat/services/calc_preset_service.dart';

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
  bool _cameraActive = false;
  bool _compassAvailable = false;
  bool _notificationPermissionGranted = false;
  bool _isInterstitialAdReady = false;
  Timer? _adCheckTimer;

  PrayerSettings? _prayerSettings;
  Madhab? _selectedMadhab;
  CalculationMethod? _selectedMethod;
  HighLatitudeRule? _selectedHighLatitudeRule;
  late final TextEditingController _adjustmentController;
  String? _selectedTimezoneId;
  bool _loadingPrayerSettings = true;

  @override
  void initState() {
    super.initState();
    _refreshStatus();

    BillingService.instance.isPendingPurchase.addListener(_onBillingChanged);
    BillingService.instance.productsNotifier.addListener(_onBillingChanged);
    BillingService.instance.isStoreAvailable.addListener(_onBillingChanged);
    BillingService.instance.billingError.addListener(_onBillingErrorChanged);
    BillingService.instance.onPurchaseSuccess = _onBillingSuccess;

    tzdata.initializeTimeZones();
    _adjustmentController = TextEditingController();
    _loadPrayerSettings();

    _refreshAdStatus();
    _adCheckTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _refreshAdStatus(),
    );
  }

  void _refreshAdStatus() {
    final ready =
        AdService.instance.isInterstitialAdReady &&
        !AdService.instance.isShowingInterstitial;
    if (ready != _isInterstitialAdReady && mounted)
      setState(() => _isInterstitialAdReady = ready);
  }

  Future<void> _refreshStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    final hasPermission =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;

    // Check Camera permission
    final cameraPerm = await Permission.camera.status;
    final hasCameraPermission = cameraPerm.isGranted;

    final compass = LocationService.hasCompass();
    bool notifEnabled = false;
    try {
      notifEnabled = await NotificationService.instance
          .areNotificationsEnabled();
    } catch (_) {}

    if (!mounted) return;
    setState(() {
      _locationActive = serviceEnabled && hasPermission;
      _cameraActive = hasCameraPermission;
      _compassAvailable = compass;
      _notificationPermissionGranted = notifEnabled;
    });
  }

  void _openAppSettings() async {
    await openAppSettings();
    await Future.delayed(const Duration(milliseconds: 400));
    if (mounted) _refreshStatus();
  }

  Future<void> _requestLocationPermission() async {
    final granted = await LocationService.checkAndRequestPermission();
    if (mounted) setState(() => _locationActive = granted);
  }

  Future<void> _requestCameraPermission() async {
    final status = await Permission.camera.request();
    if (mounted) setState(() => _cameraActive = status.isGranted);
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
    _adjustmentController.dispose();
    BillingService.instance.isPendingPurchase.removeListener(_onBillingChanged);
    BillingService.instance.productsNotifier.removeListener(_onBillingChanged);
    BillingService.instance.isStoreAvailable.removeListener(_onBillingChanged);
    BillingService.instance.billingError.removeListener(_onBillingErrorChanged);
    if (BillingService.instance.onPurchaseSuccess == _onBillingSuccess)
      BillingService.instance.onPurchaseSuccess = null;
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
          content: Text(tr('billing_error', namedArgs: {'error': error})),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _onBillingSuccess() {
    if (mounted) {
      setState(() => _prayerSettings = SettingsService.instance.notifier.value);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('billing_success')),
          backgroundColor: const Color(0xFF4CAF50),
        ),
      );
    }
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
      if (!mounted) return;
      setState(() {
        _prayerSettings = PrayerSettings();
        _selectedMadhab = _prayerSettings!.madhab;
        _selectedMethod = _prayerSettings!.calculationMethod;
        _selectedHighLatitudeRule = _prayerSettings!.highLatitudeRule;
        _selectedTimezoneId = 'Device Timezone';
        _adjustmentController.text = '0';
        _loadingPrayerSettings = false;
      });
    }
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
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: borderColor)),
                color: AppTheme.getBackgroundColor(settings, context),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  SizedBox(
                    width: 40,
                    height: 40,
                    child: Material(
                      color: isLight
                          ? Colors.black.withValues(alpha: 0.04)
                          : const Color.fromRGBO(255, 255, 255, 0.05),
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
                  const SizedBox(height: 6),
                  if (_isInterstitialAdReady && !settings.isProUser) ...[
                    _buildWatchAdCard(),
                    const SizedBox(height: 14),
                  ],
                  _buildProCard(),
                  const SizedBox(height: 16),

                  _sectionHeader(tr('configuration')),
                  _buildStatusTile(
                    icon: Icons.location_on,
                    title: tr('location_access'),
                    subtitle: tr('location_access_desc'),
                    trailing: _locationActive
                        ? _statusChip(tr('status_active'), Colors.green)
                        : _actionButton(tr('open_settings'), _openAppSettings),
                    onTap: () async {
                      await _requestLocationPermission();
                      if (!_locationActive)
                        _showInfoDialog(
                          tr('location_permission_title'),
                          tr('location_permission_msg'),
                        );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildStatusTile(
                    icon: Icons.camera_alt,
                    title: tr('camera_access'),
                    subtitle: tr('camera_access_desc'),
                    trailing: _cameraActive
                        ? _statusChip(tr('status_active'), Colors.green)
                        : _actionButton(tr('open_settings'), _openAppSettings),
                    onTap: () async {
                      await _requestCameraPermission();
                      if (!_cameraActive)
                        _showInfoDialog(
                          tr('camera_permission_title'),
                          tr('camera_permission_msg'),
                        );
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildStatusTile(
                    icon: Icons.explore,
                    title: tr('compass_sensor'),
                    subtitle: tr('compass_sensor_desc'),
                    trailing: _compassAvailable
                        ? _statusChip(tr('status_available'), Colors.green)
                        : _statusChip(tr('status_unavailable'), Colors.red),
                    onTap: () {
                      if (!_compassAvailable)
                        _showInfoDialog(
                          tr('compass_unavailable_title'),
                          tr('compass_unavailable_msg'),
                        );
                    },
                  ),
                  const SizedBox(height: 18),

                  _sectionHeader(tr('notifications')),
                  _buildNotificationGroup(settings, accentColor),
                  const SizedBox(height: 18),

                  _sectionHeader(tr('general')),
                  _buildActionButton(
                    title: tr('language'),
                    subtitle: _localeLabel(
                      EasyLocalization.of(context)!.locale,
                    ),
                    icon: Icons.language,
                    onTap: _showLanguageDialog,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: tr('select_launch_screen_title'),
                    subtitle: (settings.defaultLaunchScreen == 'prayer_times')
                        ? tr('prayer_schedule')
                        : tr('compass'),
                    icon: Icons.home_outlined,
                    onTap: _showDefaultLaunchScreenDialog,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: tr('app_theme'),
                    subtitle: _themeDisplay(settings.compassTheme),
                    icon: Icons.palette_outlined,
                    onTap: _showThemeSelectionDialog,
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: tr('display_mode'),
                    subtitle: _displayModeDisplay(settings.displayMode),
                    icon: Icons.brightness_6_outlined,
                    onTap: _showDisplayModeSelectionDialog,
                  ),
                  const SizedBox(height: 8),

                  _sectionHeader(tr('pro_travel_tools')),
                  _buildActionButton(
                    title: tr('location_profiles'),
                    subtitle: tr('location_profiles_desc'),
                    icon: Icons.place_outlined,
                    onTap: () {
                      if (!settings.isProUser) {
                        _showProPromptDialog(
                          feature: tr('location_profiles'),
                          description: tr('pro_location_profiles_desc'),
                        );
                      } else {
                        _showLocationProfilesDialog();
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: tr('calc_presets'),
                    subtitle: tr('calc_presets_desc'),
                    icon: Icons.bookmark_outline,
                    onTap: () {
                      if (!settings.isProUser) {
                        _showProPromptDialog(
                          feature: tr('calc_presets'),
                          description: tr('pro_calc_presets_desc'),
                        );
                      } else {
                        _showCalcPresetsDialog();
                      }
                    },
                  ),
                  const SizedBox(height: 18),

                  _sectionHeader(tr('prayer_schedule')),
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
                      title: tr('madhab'),
                      subtitle: PrayerSettings.madhubDisplay(
                        _selectedMadhab ?? Madhab.shafi,
                      ),
                      icon: Icons.account_tree_outlined,
                      onTap: _showMadhabDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      title: tr('calculation_method'),
                      subtitle: PrayerSettings.calculationMethodDisplay(
                        _selectedMethod ??
                            CalculationMethod.muslim_world_league,
                      ),
                      icon: Icons.calculate,
                      onTap: _showCalculationMethodDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      title: tr('high_latitude_rule'),
                      subtitle: PrayerSettings.highLatitudeRuleDisplay(
                        _selectedHighLatitudeRule ??
                            HighLatitudeRule.middle_of_the_night,
                      ),
                      icon: Icons.public,
                      onTap: _showHighLatitudeDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      title: tr('adjustment_minutes'),
                      subtitle: '${_adjustmentController.text} min',
                      icon: Icons.timer,
                      onTap: _showAdjustmentDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildActionButton(
                      title: tr('timezone'),
                      subtitle: _selectedTimezoneId == null
                          ? tr('device_timezone')
                          : TimezoneUtil.getDisplayName(_selectedTimezoneId),
                      icon: Icons.schedule,
                      onTap: _showTimezoneDialog,
                    ),
                    const SizedBox(height: 8),
                    _buildStatusTile(
                      icon: Icons.access_time,
                      title: tr('time_format'),
                      subtitle: (settings.use24Hour)
                          ? tr('time_format_24')
                          : tr('time_format_12'),
                      trailing: Switch(
                        value: settings.use24Hour,
                        activeThumbColor: accentColor,
                        onChanged: _toggleTimeFormat,
                      ),
                      onTap: () => _toggleTimeFormat(!settings.use24Hour),
                    ),
                    const SizedBox(height: 12),
                    _buildStatusTile(
                      icon: Icons.star,
                      title: tr('sunnah_times'),
                      subtitle: tr('sunnah_times_desc'),
                      trailing: Switch(
                        value: settings.showSunnahTimes,
                        activeThumbColor: accentColor,
                        onChanged: _toggleShowSunnahTimes,
                      ),
                      onTap: () =>
                          _toggleShowSunnahTimes(!settings.showSunnahTimes),
                    ),
                    if (settings.showSunnahTimes) ...[
                      const SizedBox(height: 8),
                      _buildStatusTile(
                        icon: Icons.brightness_5,
                        title: tr('dhuha'),
                        subtitle: tr('show_dhuha_desc'),
                        trailing: Switch(
                          value: settings.showDhuha,
                          activeThumbColor: accentColor,
                          onChanged: (v) {
                            _updatePrayerSettings(
                              settings.copyWith(showDhuha: v),
                            );
                          },
                        ),
                        onTap: () => _updatePrayerSettings(
                          settings.copyWith(showDhuha: !settings.showDhuha),
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildStatusTile(
                        icon: Icons.nightlight_round,
                        title: tr('tahajjud'),
                        subtitle: tr('show_tahajjud_desc'),
                        trailing: Switch(
                          value: settings.showTahajjud,
                          activeThumbColor: accentColor,
                          onChanged: (v) {
                            _updatePrayerSettings(
                              settings.copyWith(showTahajjud: v),
                            );
                          },
                        ),
                        onTap: () => _updatePrayerSettings(
                          settings.copyWith(
                            showTahajjud: !settings.showTahajjud,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                  ],

                  _sectionHeader(tr('others')),
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
                    onTap: () => _showContactDialog(),
                  ),
                  const SizedBox(height: 8),
                  _buildActionButton(
                    title: tr('privacy_policy'),
                    subtitle: tr('privacy_policy'),
                    icon: Icons.verified_user,
                    onTap: () => _showPrivacyPolicyDialog(),
                  ),

                  const SizedBox(height: 18),
                  Center(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          tr('open_source'),
                          style: TextStyle(
                            color: isLight ? Colors.black54 : Colors.white60,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          tooltip: tr('view_on_github'),
                          icon: Icon(
                            Icons.code,
                            color: isLight ? Colors.black54 : accentColor,
                          ),
                          onPressed: () => _openUrl(
                            Uri.parse('https://github.com/onyet/kiblat'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      "v2.1.1+9",
                      style: TextStyle(
                        color: isLight ? Colors.black26 : Colors.white24,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String title) => Padding(
    padding: const EdgeInsets.only(top: 10, bottom: 10),
    child: Text(
      title.toUpperCase(),
      style: TextStyle(
        color: AppTheme.getAccentColor(SettingsService.instance.notifier.value),
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.2,
      ),
    ),
  );

  Widget _buildNotificationGroup(PrayerSettings settings, Color accentColor) {
    return Column(
      children: [
        _buildStatusTile(
          icon: Icons.notifications_active,
          title: tr('prayer_notifications'),
          subtitle: !_notificationPermissionGranted
              ? tr('notification_permission_off')
              : tr('prayer_notifications_desc'),
          trailing: Switch(
            value:
                _notificationPermissionGranted &&
                settings.enablePrayerNotifications,
            activeThumbColor: accentColor,
            onChanged: (v) async {
              if (!_notificationPermissionGranted) {
                final granted = await NotificationService.instance
                    .requestPermissions();
                if (mounted)
                  setState(() => _notificationPermissionGranted = granted);
                if (!granted) return;
              }
              _updatePrayerSettings(
                settings.copyWith(enablePrayerNotifications: v),
              );
            },
          ),
          onTap: () async {
            if (!_notificationPermissionGranted) {
              final granted = await NotificationService.instance
                  .requestPermissions();
              if (mounted)
                setState(() => _notificationPermissionGranted = granted);
              return;
            }
            _updatePrayerSettings(
              settings.copyWith(
                enablePrayerNotifications: !settings.enablePrayerNotifications,
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        _buildActionButton(
          title: tr('custom_ringtone'),
          subtitle: settings.customRingtoneName ?? tr('default_ringtone'),
          icon: Icons.music_note,
          onTap: () => _showCustomRingtoneDialog(),
        ),
        const SizedBox(height: 8),
        // Advanced Reminder (Pro)
        _buildStatusTile(
          icon: Icons.alarm_add,
          title: tr('advanced_reminder'),
          subtitle: settings.enableAdvancedReminders
              ? tr(
                  'reminder_offset_desc',
                  namedArgs: {
                    'min': settings.reminderOffset.abs().toString(),
                    'type': settings.reminderOffset < 0
                        ? tr('before')
                        : tr('after'),
                  },
                )
              : tr('advanced_reminder_desc'),
          trailing: Switch(
            value: settings.enableAdvancedReminders,
            activeThumbColor: accentColor,
            onChanged: (v) {
              if (!settings.isProUser) {
                _showProPromptDialog(
                  feature: tr('advanced_reminder'),
                  description: tr('pro_reminder_desc'),
                );
              } else {
                _updatePrayerSettings(
                  settings.copyWith(enableAdvancedReminders: v),
                );
              }
            },
          ),
          onTap: () {
            if (!settings.isProUser) {
              _showProPromptDialog(
                feature: tr('advanced_reminder'),
                description: tr('pro_reminder_desc'),
              );
            } else if (settings.enableAdvancedReminders) {
              _showReminderOffsetDialog(settings);
            }
          },
        ),
      ],
    );
  }

  void _showReminderOffsetDialog(PrayerSettings settings) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('select_reminder_time')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SwitchListTile(
                title: Text(tr('per_prayer_reminders')),
                subtitle: Text(tr('per_prayer_reminders_desc')),
                value: settings.usePerPrayerReminders,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  _updatePrayerSettings(
                    settings.copyWith(usePerPrayerReminders: v),
                  );
                  if (v) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) {
                        _showPerPrayerReminderDialog(
                          SettingsService.instance.notifier.value,
                        );
                      }
                    });
                  }
                },
              ),
              const Divider(),
              if (!settings.usePerPrayerReminders) ...[
                _offsetOption(settings, -15, "15 ${tr('minutes')} ${tr('before')}"),
                _offsetOption(settings, -10, "10 ${tr('minutes')} ${tr('before')}"),
                _offsetOption(settings, -5, "5 ${tr('minutes')} ${tr('before')}"),
                _offsetOption(settings, 5, "5 ${tr('minutes')} ${tr('after')}"),
                _offsetOption(settings, 10, "10 ${tr('minutes')} ${tr('after')}"),
              ] else
                ListTile(
                  title: Text(tr('edit_per_prayer_offsets')),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    Navigator.pop(ctx);
                    _showPerPrayerReminderDialog(settings);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPerPrayerReminderDialog(PrayerSettings settings) {
    final offsets = Map<String, int>.from(settings.reminderOffsetsByPrayer);
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          return AlertDialog(
            title: Text(tr('per_prayer_reminders')),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView(
                shrinkWrap: true,
                children: PrayerSettings.reminderPrayerNames.map((name) {
                  final val = offsets[name] ?? settings.reminderOffset;
                  return ListTile(
                    title: Text(tr(name.toLowerCase())),
                    subtitle: Text(
                      '${val.abs()} ${tr('minutes')} ${val < 0 ? tr('before') : tr('after')}',
                    ),
                    trailing: DropdownButton<int>(
                      value: [-15, -10, -5, 5, 10].contains(val) ? val : -10,
                      items: [
                        DropdownMenuItem(value: -15, child: Text('15 ${tr('before')}')),
                        DropdownMenuItem(value: -10, child: Text('10 ${tr('before')}')),
                        DropdownMenuItem(value: -5, child: Text('5 ${tr('before')}')),
                        DropdownMenuItem(value: 5, child: Text('5 ${tr('after')}')),
                        DropdownMenuItem(value: 10, child: Text('10 ${tr('after')}')),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        setLocal(() => offsets[name] = v);
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('cancel')),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _updatePrayerSettings(
                    settings.copyWith(
                      usePerPrayerReminders: true,
                      reminderOffsetsByPrayer: offsets,
                    ),
                  );
                },
                child: Text(tr('save')),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _offsetOption(PrayerSettings settings, int val, String label) =>
      ListTile(
        title: Text(label),
        trailing: settings.reminderOffset == val
            ? const Icon(Icons.check, color: Color(0xFFD4AF37))
            : null,
        onTap: () {
          Navigator.pop(context);
          _updatePrayerSettings(
            settings.copyWith(
              reminderOffset: val,
              usePerPrayerReminders: false,
            ),
          );
        },
      );

  Future<void> _updatePrayerSettings(PrayerSettings ns) async {
    await SettingsService.instance.update(ns);
    if (mounted) setState(() => _prayerSettings = ns);
  }

  Future<void> _showLocationProfilesDialog() async {
    final svc = LocationProfileService.instance;
    await svc.load();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final profiles = svc.profilesNotifier.value;
          final followGps = svc.followGpsNotifier.value;
          final activeId = svc.activeProfileIdNotifier.value;
          return AlertDialog(
            title: Text(tr('location_profiles')),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SwitchListTile(
                    title: Text(tr('follow_gps')),
                    value: followGps,
                    onChanged: (v) async {
                      await svc.setFollowGps(v);
                      setLocal(() {});
                    },
                  ),
                  ...profiles.map(
                    (p) => ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        '${p.latitude.toStringAsFixed(3)}, ${p.longitude.toStringAsFixed(3)}',
                      ),
                      selected: activeId == p.id && !followGps,
                      onTap: () async {
                        await svc.setActiveProfile(p.id);
                        setLocal(() {});
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await svc.removeProfile(p.id);
                          setLocal(() {});
                        },
                      ),
                    ),
                  ),
                  if (profiles.length < LocationProfileService.maxProfiles)
                    TextButton.icon(
                      onPressed: () async {
                        final loc = await LocationService.getLastLocation(
                          allowExpired: true,
                        );
                        if (loc == null) return;
                        final nameCtrl = TextEditingController(
                          text: loc['label'] as String? ?? 'Saved',
                        );
                        if (!ctx.mounted) return;
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (c2) => AlertDialog(
                            title: Text(tr('save_current_location')),
                            content: TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                labelText: tr('profile_name'),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c2, false),
                                child: Text(tr('cancel')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c2, true),
                                child: Text(tr('save')),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) {
                          await svc.addProfile(
                            LocationProfile(
                              id: DateTime.now().millisecondsSinceEpoch
                                  .toString(),
                              name: nameCtrl.text.trim().isEmpty
                                  ? 'Saved'
                                  : nameCtrl.text.trim(),
                              latitude: loc['lat'] as double,
                              longitude: loc['lon'] as double,
                            ),
                          );
                          setLocal(() {});
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(tr('add_location_profile')),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('close')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _showCalcPresetsDialog() async {
    final svc = CalcPresetService.instance;
    await svc.load();
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final presets = svc.presetsNotifier.value;
          return AlertDialog(
            title: Text(tr('calc_presets')),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...presets.map(
                    (p) => ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        PrayerSettings.calculationMethodDisplay(
                          p.calculationMethod,
                        ),
                      ),
                      onTap: () async {
                        await svc.applyPreset(p);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(tr('preset_applied'))),
                          );
                        }
                      },
                      trailing: IconButton(
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          await svc.removePreset(p.id);
                          setLocal(() {});
                        },
                      ),
                    ),
                  ),
                  if (presets.length < CalcPresetService.maxPresets)
                    TextButton.icon(
                      onPressed: () async {
                        final nameCtrl = TextEditingController();
                        final ok = await showDialog<bool>(
                          context: ctx,
                          builder: (c2) => AlertDialog(
                            title: Text(tr('save_calc_preset')),
                            content: TextField(
                              controller: nameCtrl,
                              decoration: InputDecoration(
                                labelText: tr('preset_name'),
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(c2, false),
                                child: Text(tr('cancel')),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(c2, true),
                                child: Text(tr('save')),
                              ),
                            ],
                          ),
                        );
                        if (ok == true && nameCtrl.text.trim().isNotEmpty) {
                          await svc.addPreset(
                            svc.fromCurrentSettings(
                              DateTime.now().millisecondsSinceEpoch.toString(),
                              nameCtrl.text.trim(),
                            ),
                          );
                          setLocal(() {});
                        }
                      },
                      icon: const Icon(Icons.add),
                      label: Text(tr('add_calc_preset')),
                    ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(tr('close')),
              ),
            ],
          );
        },
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
    final s = SettingsService.instance.notifier.value;
    final isLight = AppTheme.isLight(s, context);
    return Material(
      color: AppTheme.getCardColor(s, context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : AppTheme.getBorderColor(s, context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.getAccentColor(s).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: AppTheme.getAccentColor(s)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.getTextColor(s, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.getSecondaryTextColor(s, context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWatchAdCard() {
    final s = SettingsService.instance.notifier.value;
    final accent = AppTheme.getAccentColor(s, context);
    return InkWell(
      onTap: _handleWatchAd,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              accent.withValues(alpha: 0.2),
              accent.withValues(alpha: 0.05),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.play_circle_outline, color: accent, size: 26),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('watch_ad_support'),
                    style: TextStyle(
                      color: AppTheme.getTextColor(s, context),
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    tr('watch_ad_support_desc'),
                    style: TextStyle(
                      color: AppTheme.getSecondaryTextColor(s, context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.favorite, color: accent, size: 20),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWatchAd() async {
    if (!AdService.instance.isInterstitialAdReady) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('ad_not_ready'))));
      return;
    }
    final shown = await AdService.instance.showInterstitialAd();
    if (mounted) {
      _refreshAdStatus();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(shown ? tr('watch_ad_thanks') : tr('ad_not_completed')),
        ),
      );
    }
  }

  Widget _actionButton(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    child: Text(
      label,
      style: TextStyle(
        color: AppTheme.getAccentColor(SettingsService.instance.notifier.value),
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _statusChip(String label, Color statusColor) {
    final s = SettingsService.instance.notifier.value;
    final accent = AppTheme.getAccentColor(s);
    final bool isSuccess = statusColor == Colors.green;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: (isSuccess ? accent : Colors.redAccent).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: isSuccess ? accent : Colors.redAccent,
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
    final s = SettingsService.instance.notifier.value;
    final isLight = AppTheme.isLight(s, context);
    return Material(
      color: AppTheme.getCardColor(s, context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isLight
                  ? Colors.black.withValues(alpha: 0.08)
                  : AppTheme.getBorderColor(s, context),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: isLight
                      ? Colors.black.withValues(alpha: 0.04)
                      : const Color(0x0DFFFFFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.getSecondaryTextColor(s, context),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: AppTheme.getTextColor(s, context),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: AppTheme.getSecondaryTextColor(s, context),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: AppTheme.getSecondaryTextColor(
                  s,
                  context,
                ).withValues(alpha: 0.4),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final locales = EasyLocalization.of(context)!.supportedLocales;
    final current = EasyLocalization.of(context)!.locale;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('choose_language')),
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
                      Navigator.pop(ctx);
                      await EasyLocalization.of(context)!.setLocale(loc);
                      if (mounted) setState(() {});
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
    try {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    } catch (_) {}
  }

  String _localeLabel(Locale locale) {
    switch (locale.languageCode) {
      case 'in':
      case 'id':
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

  Future<void> _persistPrayerSettingsEx({bool showToast = true}) async {
    final current = SettingsService.instance.notifier.value;
    final adjustment = int.tryParse(_adjustmentController.text) ?? 0;
    final ns = current.copyWith(
      madhab: _selectedMadhab,
      calculationMethod: _selectedMethod,
      highLatitudeRule: _selectedHighLatitudeRule,
      adjustmentMinutes: adjustment,
      timezoneId: _selectedTimezoneId == 'Device Timezone'
          ? null
          : _selectedTimezoneId,
      clearTimezone: _selectedTimezoneId == 'Device Timezone',
    );
    await _updatePrayerSettings(ns);
    if (showToast && mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('settings_saved')),
          duration: const Duration(milliseconds: 900),
        ),
      );
  }

  void _showMadhabDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('madhab')),
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
                      Navigator.pop(ctx);
                      setState(() => _selectedMadhab = m);
                      _persistPrayerSettingsEx();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showCalculationMethodDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('calculation_method')),
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
                      Navigator.pop(ctx);
                      setState(() => _selectedMethod = m);
                      _persistPrayerSettingsEx();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showHighLatitudeDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('high_latitude_rule')),
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
                      Navigator.pop(ctx);
                      setState(() => _selectedHighLatitudeRule = m);
                      _persistPrayerSettingsEx();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _showAdjustmentDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('adjustment_minutes')),
        content: TextField(
          controller: _adjustmentController,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(hintText: 'e.g. 0, 2, -1'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('dismiss')),
          ),
          TextButton(
            onPressed: () {
              final val = int.tryParse(_adjustmentController.text) ?? 0;
              setState(() => _adjustmentController.text = val.toString());
              Navigator.pop(ctx);
              _persistPrayerSettingsEx();
            },
            child: Text(tr('apply')),
          ),
        ],
      ),
    );
  }

  void _showTimezoneDialog() {
    final timezones = TimezoneUtil.popularTimezones;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('timezone')),
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
                    subtitle: Text(
                      TimezoneUtil.getOffsetString(
                        tzId == 'Device Timezone' ? null : tzId,
                      ),
                    ),
                    trailing:
                        _selectedTimezoneId ==
                            (tzId == 'Device Timezone' ? null : tzId)
                        ? const Icon(Icons.check, color: Color(0xFFF4C025))
                        : null,
                    onTap: () {
                      setState(
                        () => _selectedTimezoneId = tzId == 'Device Timezone'
                            ? null
                            : tzId,
                      );
                      Navigator.pop(ctx);
                      _persistPrayerSettingsEx();
                    },
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  void _toggleShowSunnahTimes(bool value) => _updatePrayerSettings(
    SettingsService.instance.notifier.value.copyWith(showSunnahTimes: value),
  );
  void _toggleTimeFormat(bool use24) => _updatePrayerSettings(
    SettingsService.instance.notifier.value.copyWith(use24Hour: use24),
  );

  void _showCustomRingtoneDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('custom_ringtone')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.star, color: Color(0xFFF4C025)),
              title: Text(tr('muadzin_premium')),
              subtitle: Text(tr('muadzin_premium_desc')),
              onTap: () {
                Navigator.pop(ctx);
                _showPremiumAdzanDialog();
              },
            ),
            const Divider(),
            if (SettingsService.instance.notifier.value.customRingtoneName !=
                null)
              ListTile(
                leading: const Icon(Icons.music_note, color: Color(0xFFF4C025)),
                title: Text(tr('current_ringtone')),
                subtitle: Text(
                  SettingsService.instance.notifier.value.customRingtoneName!,
                ),
              ),
            ListTile(
              leading: const Icon(
                Icons.notifications_active,
                color: Color(0xFFF4C025),
              ),
              title: Text(tr('test_notification')),
              subtitle: Text(tr('test_notification_desc')),
              onTap: () {
                Navigator.pop(ctx);
                NotificationService.instance.triggerTestNotification(
                  SettingsService.instance.notifier.value,
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.upload_file, color: Color(0xFFF4C025)),
              title: Text(tr('upload_custom_ringtone')),
              subtitle: Text(tr('pro_feature_privat')),
              onTap: () async {
                Navigator.pop(ctx);
                await _handleCustomRingtoneUpload();
              },
            ),
            if (SettingsService.instance.notifier.value.customRingtonePath !=
                null)
              ListTile(
                leading: const Icon(Icons.restore, color: Colors.redAccent),
                title: Text(tr('reset_to_default')),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _resetRingtone();
                },
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('dismiss')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCustomRingtoneUpload() async {
    if (SettingsService.instance.notifier.value.isProUser) {
      await _pickAndSaveRingtone();
    } else {
      _showProPromptDialog(
        feature: tr('custom_ringtone'),
        description: tr('pro_desc'),
      );
    }
  }

  Future<void> _pickAndSaveRingtone() async {
    try {
      if (Platform.isAndroid) {
        final result = await _platformChannel.invokeMapMethod<String, String>(
          'pickNotificationSound',
        );
        if (result == null) return;
        final uri = result['uri'];
        if (uri == null || uri.isEmpty) return;
        final fileName = result['name'] ?? 'Custom adzan';
        final ns = SettingsService.instance.notifier.value.copyWith(
          customRingtonePath: uri,
          customRingtoneName: fileName,
        );
        await _updatePrayerSettings(ns);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('ringtone_set_success'))));
        return;
      }
      final file = await FilePicker.pickFile(
        type: FileType.audio,
      );
      if (file == null || file.path == null) return;
      final appDir = await getApplicationSupportDirectory();
      final destDir = Directory('${appDir.path}/ringtones');
      if (!await destDir.exists()) await destDir.create(recursive: true);
      final destPath =
          '${destDir.path}/custom_adzan.${file.extension ?? 'mp3'}';
      await File(file.path!).copy(destPath);
      final ns = SettingsService.instance.notifier.value.copyWith(
        customRingtonePath: destPath,
        customRingtoneName: file.name,
      );
      await _updatePrayerSettings(ns);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('ringtone_set_success'))));
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('ringtone_set_failed'))));
    }
  }

  Future<void> _resetRingtone() async {
    await _updatePrayerSettings(
      SettingsService.instance.notifier.value.copyWith(
        clearCustomRingtone: true,
      ),
    );
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('ringtone_reset_success'))));
  }

  void _showPrivacyPolicyDialog() async {
    final url = Uri.parse('https://onyet.github.io/privacy-police.html');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('privacy_policy')),
        content: Text(url.toString()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('dismiss')),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _openUrl(url);
            },
            child: Text(tr('open')),
          ),
        ],
      ),
    );
  }

  void _showContactDialog() async {
    showDialog(
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
                Navigator.pop(ctx);
                await _openUrl(Uri.parse('https://wa.me/6282221874400'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.email),
              title: Text(tr('contact_email')),
              subtitle: const Text('onyetcorp@gmail.com'),
              onTap: () async {
                Navigator.pop(ctx);
                await _openUrl(Uri.parse('mailto:onyetcorp@gmail.com'));
              },
            ),
            ListTile(
              leading: const Icon(Icons.phone),
              title: Text(tr('contact_phone')),
              subtitle: const Text('+62 822-2187-4400'),
              onTap: () async {
                Navigator.pop(ctx);
                await _openUrl(Uri.parse('tel:+6282221874400'));
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(tr('dismiss')),
          ),
        ],
      ),
    );
  }

  Widget _buildProCard() {
    final s = SettingsService.instance.notifier.value;
    final isPro = s.isProUser;
    final isLight = AppTheme.isLight(s, context);
    final top = isPro
        ? (isLight ? const Color(0xFFE8F5E9) : const Color(0xFF0F1E12))
        : (isLight ? const Color(0xFFFFFDE7) : const Color(0xFF1F1B0F));
    final bot = isPro
        ? (isLight ? const Color(0xFFC8E6C9) : const Color(0xFF071009))
        : (isLight ? const Color(0xFFFFF9C4) : const Color(0xFF100E08));
    final border = isPro
        ? const Color(0xFF4CAF50).withValues(alpha: 0.5)
        : const Color(0xFFD4AF37).withValues(alpha: 0.5);
    final text = isPro
        ? (isLight ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50))
        : (isLight ? const Color(0xFFB58A0D) : const Color(0xFFD4AF37));

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [top, bot],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: (isPro ? Colors.green : const Color(0xFFD4AF37)).withValues(
              alpha: 0.1,
            ),
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
              Icon(isPro ? Icons.verified : Icons.stars, color: text, size: 24),
              const SizedBox(width: 8),
              Text(
                isPro ? tr('pro_active') : tr('upgrade_pro'),
                style: TextStyle(
                  color: text,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              const Spacer(),
              if (isPro)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isLight ? Colors.green : const Color(0xFF4CAF50))
                        .withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    tr('pro_feature_privat'),
                    style: TextStyle(
                      color: isLight
                          ? const Color(0xFF1B5E20)
                          : const Color(0xFF4CAF50),
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ),
            ],
          ),
          Text(
            isPro ? tr('pro_active_desc') : tr('pro_desc_detailed'),
            style: TextStyle(
              color: isLight ? Colors.black87 : Colors.white70,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          if (!isPro) ...[
            if (BillingService.instance.isPendingPurchase.value)
              const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
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
                        ? tr(
                            'buy_pro_fmt',
                            namedArgs: {
                              'price':
                                  BillingService
                                      .instance
                                      .productsNotifier
                                      .value
                                      .isNotEmpty
                                  ? "(${BillingService.instance.productsNotifier.value.first.price})"
                                  : "",
                            },
                          )
                        : tr('buy_pro_unavailable'),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                height: 38,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: isLight ? Colors.black54 : Colors.white70,
                    side: BorderSide(
                      color: isLight ? Colors.black12 : Colors.white24,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: BillingService.instance.isStoreAvailable.value
                      ? () => BillingService.instance.restorePurchases()
                      : null,
                  child: Text(
                    tr('restore_purchase'),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  void _showProPromptDialog({
    required String feature,
    required String description,
  }) {
    showDialog(
      context: context,
      builder: (ctx) {
        final s = SettingsService.instance.notifier.value;
        final accent = AppTheme.getAccentColor(s, context);
        return AlertDialog(
          backgroundColor: AppTheme.getCardColor(s, context),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: BorderSide(color: accent, width: 1.5),
          ),
          title: Row(
            children: [
              Icon(Icons.stars, color: accent, size: 28),
              const SizedBox(width: 10),
              Text(
                tr('pro_prompt_title'),
                style: TextStyle(
                  color: AppTheme.getTextColor(s, context),
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                tr('pro_prompt_feature_req'),
                style: TextStyle(
                  color: AppTheme.getTextColor(
                    s,
                    context,
                  ).withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '• $feature',
                style: TextStyle(
                  color: accent,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                description,
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(s, context),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: AppTheme.getBorderColor(s, context)),
              const SizedBox(height: 10),
              Text(
                tr('pro_prompt_privacy_title'),
                style: TextStyle(
                  color: AppTheme.getTextColor(
                    s,
                    context,
                  ).withValues(alpha: 0.8),
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '✅ ${tr('pro_prompt_benefit_ads')}',
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(s, context),
                  fontSize: 12,
                ),
              ),
              Text(
                '✅ ${tr('pro_prompt_benefit_telemetry')}',
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(s, context),
                  fontSize: 12,
                ),
              ),
              Text(
                '✅ ${tr('pro_prompt_benefit_adzan')}',
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(s, context),
                  fontSize: 12,
                ),
              ),
              Text(
                '✅ ${tr('pro_prompt_benefit_themes')}',
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(s, context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                tr('cancel'),
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(s, context),
                ),
              ),
            ),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFBF953F),
                    Color(0xFFFCF6BA),
                    Color(0xFFBF953F),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () async {
                  Navigator.pop(ctx);
                  if (BillingService.instance.isStoreAvailable.value)
                    await BillingService.instance.buyPro();
                },
                child: Text(
                  tr('buy_kiblat_pro'),
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showDefaultLaunchScreenDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final s = SettingsService.instance.notifier.value;
        final accent = AppTheme.getAccentColor(s, context);
        return AlertDialog(
          backgroundColor: AppTheme.getCardColor(s, context),
          title: Text(
            tr('select_launch_screen_title'),
            style: TextStyle(
              color: AppTheme.getTextColor(s, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(
                  tr('launch_compass_title'),
                  style: TextStyle(color: AppTheme.getTextColor(s, context)),
                ),
                subtitle: Text(
                  tr('launch_compass_desc'),
                  style: TextStyle(
                    color: AppTheme.getSecondaryTextColor(s, context),
                    fontSize: 12,
                  ),
                ),
                value: 'compass',
                groupValue: s.defaultLaunchScreen,
                activeColor: accent,
                onChanged: (val) {
                  Navigator.pop(ctx);
                  if (val != null) {
                    _updatePrayerSettings(s.copyWith(defaultLaunchScreen: val));
                    MainShell.switchTab(0);
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  tr('launch_prayer_title'),
                  style: TextStyle(color: AppTheme.getTextColor(s, context)),
                ),
                subtitle: Text(
                  tr('launch_prayer_desc'),
                  style: TextStyle(
                    color: AppTheme.getSecondaryTextColor(s, context),
                    fontSize: 12,
                  ),
                ),
                value: 'prayer_times',
                groupValue: s.defaultLaunchScreen,
                activeColor: accent,
                onChanged: (val) {
                  Navigator.pop(ctx);
                  if (val != null) {
                    _updatePrayerSettings(s.copyWith(defaultLaunchScreen: val));
                    MainShell.switchTab(1);
                  }
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                tr('dismiss'),
                style: TextStyle(
                  color: AppTheme.getSecondaryTextColor(s, context),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showPremiumAdzanDialog() {
    showDialog(
      context: context,
      builder: (ctx) => _PremiumAdzanDialog(
        isPro: SettingsService.instance.notifier.value.isProUser,
        selectedRingtonePath:
            SettingsService.instance.notifier.value.customRingtonePath,
        onSelect: (name, asset) => _setPremiumAdzan(name, asset),
        onShowProPrompt: (f, d) =>
            _showProPromptDialog(feature: f, description: d),
      ),
    );
  }

  Future<void> _setPremiumAdzan(String name, String asset) async {
    try {
      String path = Platform.isAndroid
          ? 'android.resource://id.onyet.app.kiblat/raw/$asset'
          : (Platform.isIOS ? '$asset.mp3' : 'assets/audio/$asset.mp3');
      if (Platform.isIOS) {
        final dest = Directory('${(await getLibraryDirectory()).path}/Sounds');
        if (!await dest.exists()) await dest.create(recursive: true);
        final file = File('${dest.path}/$asset.mp3');
        if (!await file.exists())
          await file.writeAsBytes(
            (await rootBundle.load(
              'assets/audio/$asset.mp3',
            )).buffer.asUint8List(),
          );
      }
      await _updatePrayerSettings(
        SettingsService.instance.notifier.value.copyWith(
          customRingtonePath: path,
          customRingtoneName: name,
        ),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('adzan_set_success', namedArgs: {'name': name})),
          backgroundColor: const Color(0xFFD4AF37),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            tr('adzan_set_failed', namedArgs: {'error': e.toString()}),
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String _themeDisplay(String theme) {
    switch (theme) {
      case 'classic':
        return 'Green Lantern (Free)';
      case 'gold':
        return 'Gold Arabasta (Free)';
      case 'dark':
        return 'Minimalist Dark (Pro)';
      case 'cyber':
        return 'Cyber Qibla (Pro)';
      case 'dynamic':
        return tr('theme_dynamic_time');
      default:
        return 'Green Lantern (Free)';
    }
  }

  void _showThemeSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final s = SettingsService.instance.notifier.value;
        return AlertDialog(
          backgroundColor: AppTheme.getCardColor(s, context),
          title: Text(
            tr('app_theme'),
            style: TextStyle(
              color: AppTheme.getTextColor(s, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _themeOption(
                  ctx,
                  s,
                  'classic',
                  'Green Lantern (Free)',
                  'Tema klasik warna hijau khas yang menyejukkan',
                  true,
                ),
                _themeOption(
                  ctx,
                  s,
                  'gold',
                  'Gold Arabasta (Free)',
                  'Desain default berwarna emas yang elegan dan bersih',
                  true,
                ),
                _themeOption(
                  ctx,
                  s,
                  'dynamic',
                  tr('theme_dynamic_time'),
                  tr('theme_dynamic_time_desc'),
                  s.isProUser,
                ),
                _themeOption(
                  ctx,
                  s,
                  'dark',
                  'Minimalist Dark (Pro)',
                  'Desain gelap minimalis dan bersih untuk malam hari',
                  s.isProUser,
                ),
                _themeOption(
                  ctx,
                  s,
                  'cyber',
                  'Cyber Qibla (Pro)',
                  'Gaya futuristik dengan aksen cyan dan neon',
                  s.isProUser,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _themeOption(
    BuildContext ctx,
    PrayerSettings s,
    String val,
    String title,
    String desc,
    bool isUnlocked,
  ) => RadioListTile<String>(
    title: Text(
      title,
      style: TextStyle(color: AppTheme.getTextColor(s, context)),
    ),
    subtitle: Text(
      desc,
      style: TextStyle(
        color: AppTheme.getSecondaryTextColor(s, context),
        fontSize: 12,
      ),
    ),
    value: val,
    groupValue: s.compassTheme,
    activeColor: AppTheme.getAccentColor(s, context),
    onChanged: (v) {
      Navigator.pop(ctx);
      if (!isUnlocked) {
        _showProPromptDialog(feature: title, description: tr('pro_theme_desc'));
      } else if (v != null)
        _updatePrayerSettings(s.copyWith(compassTheme: v));
    },
  );

  String _displayModeDisplay(String mode) {
    switch (mode) {
      case 'dark':
        return tr('display_dark');
      case 'system':
        return tr('display_system');
      default:
        return tr('display_light');
    }
  }

  void _showDisplayModeSelectionDialog() {
    showDialog(
      context: context,
      builder: (ctx) {
        final s = SettingsService.instance.notifier.value;
        final accent = AppTheme.getAccentColor(s, context);
        final isPro = s.isProUser;
        return AlertDialog(
          backgroundColor: AppTheme.getCardColor(s, context),
          title: Text(
            tr('display_mode'),
            style: TextStyle(
              color: AppTheme.getTextColor(s, context),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              RadioListTile<String>(
                title: Text(
                  tr('display_light'),
                  style: TextStyle(color: AppTheme.getTextColor(s, context)),
                ),
                subtitle: Text(
                  tr('display_light_desc'),
                  style: TextStyle(
                    color: AppTheme.getSecondaryTextColor(s, context),
                    fontSize: 12,
                  ),
                ),
                value: 'light',
                groupValue: s.displayMode,
                activeColor: accent,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  if (v != null)
                    _updatePrayerSettings(s.copyWith(displayMode: v));
                },
              ),
              RadioListTile<String>(
                title: Text(
                  tr('display_dark'),
                  style: TextStyle(color: AppTheme.getTextColor(s, context)),
                ),
                subtitle: Text(
                  tr('display_dark_desc'),
                  style: TextStyle(
                    color: AppTheme.getSecondaryTextColor(s, context),
                    fontSize: 12,
                  ),
                ),
                value: 'dark',
                groupValue: s.displayMode,
                activeColor: accent,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  if (v != null) {
                    if (!isPro) {
                      _showProPromptDialog(
                        feature: tr('display_dark'),
                        description: tr('pro_display_mode_desc_detailed'),
                      );
                    } else {
                      _updatePrayerSettings(s.copyWith(displayMode: v));
                    }
                  }
                },
              ),
              RadioListTile<String>(
                title: Text(
                  tr('display_system'),
                  style: TextStyle(color: AppTheme.getTextColor(s, context)),
                ),
                subtitle: Text(
                  tr('display_system_desc'),
                  style: TextStyle(
                    color: AppTheme.getSecondaryTextColor(s, context),
                    fontSize: 12,
                  ),
                ),
                value: 'system',
                groupValue: s.displayMode,
                activeColor: accent,
                onChanged: (v) {
                  Navigator.pop(ctx);
                  if (v != null) {
                    if (!isPro) {
                      _showProPromptDialog(
                        feature: tr('display_system'),
                        description: tr('pro_system_sync_desc'),
                      );
                    } else {
                      _updatePrayerSettings(s.copyWith(displayMode: v));
                    }
                  }
                },
              ),
            ],
          ),
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
  final List<Map<String, String>> _adzans = [
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
    _playerStateSubscription = _audioPlayer.onPlayerStateChanged.listen((
      state,
    ) {
      if (mounted)
        setState(() {
          _playerState = state;
          if (state == PlayerState.completed || state == PlayerState.stopped)
            _playingAsset = null;
        });
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

  @override
  Widget build(BuildContext context) {
    final s = SettingsService.instance.notifier.value;
    return AlertDialog(
      backgroundColor: AppTheme.getCardColor(s, context),
      title: Text(
        tr('muadzin_premium'),
        style: TextStyle(
          color: AppTheme.getTextColor(s, context),
          fontWeight: FontWeight.bold,
        ),
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _adzans.length,
          itemBuilder: (context, index) {
            final adzan = _adzans[index];
            final asset = adzan['asset']!;
            final name = adzan['name']!;
            final isPlaying =
                _playingAsset == asset && _playerState == PlayerState.playing;
            final isSelected =
                widget.selectedRingtonePath?.contains(asset) ?? false;
            return ListTile(
              leading: Icon(
                isSelected ? Icons.check_circle : Icons.music_note,
                color: isSelected
                    ? AppTheme.getAccentColor(s, context)
                    : AppTheme.getSecondaryTextColor(
                        s,
                        context,
                      ).withValues(alpha: 0.6),
              ),
              title: Text(
                name,
                style: TextStyle(
                  color: isSelected
                      ? AppTheme.getAccentColor(s, context)
                      : AppTheme.getTextColor(s, context),
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
              trailing: IconButton(
                icon: Icon(
                  isPlaying ? Icons.stop_circle : Icons.play_circle_fill,
                  color: isPlaying
                      ? Colors.redAccent
                      : AppTheme.getAccentColor(s, context),
                  size: 28,
                ),
                onPressed: () => _playPause(asset),
              ),
              onTap: () {
                if (!widget.isPro) {
                  Navigator.pop(context);
                  widget.onShowProPrompt(
                    tr('muadzin_premium'),
                    tr('muadzin_premium_desc'),
                  );
                } else {
                  Navigator.pop(context);
                  widget.onSelect(name, asset);
                }
              },
            );
          },
        ),
      ),
    );
  }
}
