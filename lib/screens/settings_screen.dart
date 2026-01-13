import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:adhan/adhan.dart';
import 'package:kiblat/utils/timezone_util.dart';
import 'package:timezone/data/latest.dart' as tzdata;

import '../services/location_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen>
    with SingleTickerProviderStateMixin {
  bool _locationActive = false;
  bool _compassAvailable = false;
  bool _testAdMode = false;

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
  }

  Future<void> _refreshStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    final hasPermission =
        perm == LocationPermission.always ||
        perm == LocationPermission.whileInUse;
    final compass = LocationService.hasCompass();

    if (!mounted) return;
    setState(() {
      _locationActive = serviceEnabled && hasPermission;
      _compassAvailable = compass;
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
    _animController.dispose();
    _adjustmentController.dispose();
    super.dispose();
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
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar
            Container(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: const Color.fromRGBO(255, 255, 255, 0.05))),
                color: const Color(0xFF050505),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
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
                  Text(
                    tr('settings'),
                    style: const TextStyle(
                      color: Colors.white,
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
                              color: Color.fromRGBO(
                                244,
                                192,
                                37,
                                _opacityAnim.value,
                              ),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Center(
                              child: Icon(
                                Icons.mosque,
                                color: Colors.white70,
                                size: 36,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Text(
                    tr('configuration'),
                    style: const TextStyle(
                      color: Color(0xFFF4C025),
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
                    style: const TextStyle(
                      color: Color(0xFFF4C025),
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

                  // Test Ad Mode toggle (QA) - only visible in debug builds
                  if (kDebugMode) ...[
                    _buildStatusTile(
                      icon: Icons.ad_units,
                      title: tr('ad_test_mode'),
                      subtitle: tr('ad_test_mode_desc'),
                      trailing: Switch(
                        value: _testAdMode,
                        activeThumbColor: Color(0xFFF4C025),
                        onChanged: _toggleTestMode,
                      ),
                      onTap: () => _toggleTestMode(!_testAdMode),
                    ),
                    const SizedBox(height: 8),
                  ],

                  // Prayer Schedule configuration
                  Text(
                    tr('prayer_schedule') == 'prayer_schedule' ? 'Prayer Schedule' : tr('prayer_schedule'),
                    style: const TextStyle(
                      color: Color(0xFFF4C025),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (_loadingPrayerSettings)
                    const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator()))
                  else ...[
                    _buildActionButton(
                      title: tr('madhab') == 'madhab' ? 'Madhab' : tr('madhab'),
                      subtitle: _selectedMadhab != null ? PrayerSettings.madhubDisplay(_selectedMadhab!) : '',
                      icon: Icons.account_tree_outlined,
                      onTap: _showMadhabDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('calculation_method') == 'calculation_method' ? 'Calculation Method' : tr('calculation_method'),
                      subtitle: _selectedMethod != null ? PrayerSettings.calculationMethodDisplay(_selectedMethod!) : '',
                      icon: Icons.calculate,
                      onTap: _showCalculationMethodDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('high_latitude_rule') == 'high_latitude_rule' ? 'High Latitude Rule' : tr('high_latitude_rule'),
                      subtitle: _selectedHighLatitudeRule != null ? PrayerSettings.highLatitudeRuleDisplay(_selectedHighLatitudeRule!) : '',
                      icon: Icons.public,
                      onTap: _showHighLatitudeDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('adjustment_minutes') == 'adjustment_minutes' ? 'Adjustment Minutes' : tr('adjustment_minutes'),
                      subtitle: '${_adjustmentController.text} min',
                      icon: Icons.timer,
                      onTap: _showAdjustmentDialog,
                    ),
                    const SizedBox(height: 8),

                    _buildActionButton(
                      title: tr('timezone') == 'timezone' ? 'Timezone' : tr('timezone'),
                      subtitle: _selectedTimezoneId == null ? 'Device Timezone' : TimezoneUtil.getDisplayName(_selectedTimezoneId),
                      icon: Icons.schedule,
                      onTap: _showTimezoneDialog,
                    ),
                    const SizedBox(height: 12),

                    // Sunnah times toggle
                    _buildStatusTile(
                      icon: Icons.star,
                      title: tr('sunnah_times') == 'sunnah_times' ? 'Sunnah times' : tr('sunnah_times'),
                      subtitle: tr('sunnah_times_desc') == 'sunnah_times_desc' ? 'Show Dhuha and Tahajjud times' : tr('sunnah_times_desc'),
                      trailing: Switch(
                        value: _prayerSettings?.showSunnahTimes ?? true,
                        activeThumbColor: const Color(0xFFF4C025),
                        onChanged: _toggleShowSunnahTimes,
                      ),
                      onTap: () => _toggleShowSunnahTimes(!(_prayerSettings?.showSunnahTimes ?? true)),
                    ),
                    const SizedBox(height: 8),

                    // Per-sunnah toggles
                    _buildStatusTile(
                      icon: Icons.brightness_5,
                      title: tr('dhuha') == 'dhuha' ? 'Dhuha' : tr('dhuha'),
                      subtitle: tr('show_dhuha_desc') == 'show_dhuha_desc' ? 'Show Dhuha time' : tr('show_dhuha_desc'),
                      trailing: Switch(
                        value: _prayerSettings?.showDhuha ?? true,
                        activeThumbColor: const Color(0xFFF4C025),
                        onChanged: (v) {
                          setState(() => _prayerSettings = _prayerSettings?.copyWith(showDhuha: v) ?? PrayerSettings(showDhuha: v));
                          _persistPrayerSettings();
                        },
                      ),
                      onTap: () {
                        setState(() => _prayerSettings = _prayerSettings?.copyWith(showDhuha: !(_prayerSettings?.showDhuha ?? true)) ?? PrayerSettings(showDhuha: true));
                        _persistPrayerSettings();
                      },
                    ),
                    const SizedBox(height: 8),

                    _buildStatusTile(
                      icon: Icons.nightlight_round,
                      title: tr('tahajjud') == 'tahajjud' ? 'Tahajjud' : tr('tahajjud'),
                      subtitle: tr('show_tahajjud_desc') == 'show_tahajjud_desc' ? 'Show Tahajjud time' : tr('show_tahajjud_desc'),
                      trailing: Switch(
                        value: _prayerSettings?.showTahajjud ?? true,
                        activeThumbColor: const Color(0xFFF4C025),
                        onChanged: (v) {
                          setState(() => _prayerSettings = _prayerSettings?.copyWith(showTahajjud: v) ?? PrayerSettings(showTahajjud: v));
                          _persistPrayerSettings();
                        },
                      ),
                      onTap: () {
                        setState(() => _prayerSettings = _prayerSettings?.copyWith(showTahajjud: !(_prayerSettings?.showTahajjud ?? true)) ?? PrayerSettings(showTahajjud: true));
                        _persistPrayerSettings();
                      },
                    ),
                    const SizedBox(height: 12),


                  ],

Text(
                    tr('others') == 'others' ? 'LAINNYA' : tr('others'),
                    style: const TextStyle(
                      color: Color(0xFFF4C025),
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
                          icon: const Icon(
                            Icons.code,
                            color: Color(0xFFF4C025),
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x14F4C025),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: const Color(0xFFF4C025)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
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

  Widget _actionButton(String label, VoidCallback onTap) => TextButton(
    onPressed: onTap,
    child: Text(
      label,
      style: const TextStyle(
        color: Color(0xFFF4C025),
        fontWeight: FontWeight.w600,
      ),
    ),
  );

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
        style: const TextStyle(
          color: Colors.greenAccent,
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
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0x1AFFFFFF),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x0DFFFFFF)),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: const Color(0x0DFFFFFF),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: Colors.white70),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white60, fontSize: 12),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.white30),
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
                    trailing: _selectedMadhab == m ? const Icon(Icons.check, color: Color(0xFFF4C025)) : null,
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
        title: Text(tr('calculation_method') == 'calculation_method' ? 'Calculation Method' : tr('calculation_method')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: CalculationMethod.values
                .map(
                  (m) => ListTile(
                    title: Text(PrayerSettings.calculationMethodDisplay(m)),
                    trailing: _selectedMethod == m ? const Icon(Icons.check, color: Color(0xFFF4C025)) : null,
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
        title: Text(tr('high_latitude_rule') == 'high_latitude_rule' ? 'High Latitude Rule' : tr('high_latitude_rule')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: HighLatitudeRule.values
                .map(
                  (m) => ListTile(
                    title: Text(PrayerSettings.highLatitudeRuleDisplay(m)),
                    trailing: _selectedHighLatitudeRule == m ? const Icon(Icons.check, color: Color(0xFFF4C025)) : null,
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
        title: Text(tr('adjustment_minutes') == 'adjustment_minutes' ? 'Adjustment Minutes' : tr('adjustment_minutes')),
        content: TextField(
          controller: _adjustmentController,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(hintText: 'e.g. 0, 2, -1'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(tr('dismiss'))),
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
                .map((tzId) => ListTile(
                      title: Text(tzId == 'Device Timezone' ? 'Device Timezone' : tzId),
                      subtitle: tzId == 'Device Timezone' ? Text(TimezoneUtil.getOffsetString(null)) : Text(TimezoneUtil.getOffsetString(tzId)),
                      trailing: _selectedTimezoneId == tzId ? const Icon(Icons.check, color: Color(0xFFF4C025)) : null,
                      onTap: () {
                        setState(() {
                          _selectedTimezoneId = tzId == 'Device Timezone' ? null : tzId;
                        });
                        Navigator.of(ctx, rootNavigator: true).pop();
                        _persistPrayerSettings();
                      },
                    ))
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
      highLatitudeRule: _selectedHighLatitudeRule ?? PrayerSettings().highLatitudeRule,
      adjustmentMinutes: adjustment,
      showSunnahTimes: _prayerSettings?.showSunnahTimes ?? true,
      showDhuha: _prayerSettings?.showDhuha ?? true,
      showTahajjud: _prayerSettings?.showTahajjud ?? true,
      timezoneId: _selectedTimezoneId == 'Device Timezone' ? null : _selectedTimezoneId,
    );

    try {
      await newSettings.save();
      if (!mounted) return;
      setState(() {
        _prayerSettings = newSettings;
      });
      if (showToast) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('settings_saved')),
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
      _prayerSettings = _prayerSettings?.copyWith(showSunnahTimes: value) ?? PrayerSettings(showSunnahTimes: value);
    });
    _persistPrayerSettings();
  }

  // Contact & Privacy dialogs
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
          ),
        ],
      ),
    );
  }
}
