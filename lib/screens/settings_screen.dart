import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../services/location_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> with SingleTickerProviderStateMixin {
  bool _locationActive = false;
  bool _compassAvailable = false;

  late final AnimationController _animController;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _opacityAnim; 

  @override
  void initState() {
    super.initState();
    _refreshStatus();

    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
    _scaleAnim = Tween<double>(begin: 0.96, end: 1.08).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
    _opacityAnim = Tween<double>(begin: 0.12, end: 0.32).animate(CurvedAnimation(parent: _animController, curve: Curves.easeInOut));
  }

  Future<void> _refreshStatus() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    final perm = await Geolocator.checkPermission();
    final hasPermission = perm == LocationPermission.always || perm == LocationPermission.whileInUse;
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
    showDialog<void>(context: context, builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(tr('ok')))],
    ));
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
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
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0x1AFFFFFF))),
                color: Color(0xFF121008),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  Text(tr('settings'), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(width: 48),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
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
                              color: Color(0xFFF4C025).withOpacity(_opacityAnim.value),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Center(child: Icon(Icons.mosque, color: Colors.white70, size: 36)),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 6),
                  Text(tr('configuration'), style: const TextStyle(color: Color(0xFFF4C025), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 10),

                  // Location Access
                  _buildStatusTile(
                    icon: Icons.location_on,
                    title: tr('location_access'),
                    subtitle: tr('location_access_desc'),
                    trailing: _locationActive ? _statusChip(tr('status_active'), Colors.green) : _actionButton(tr('open_settings'), _openAppSettings),
                    onTap: () async {
                      // Request permission when tapped
                      await _requestPermission();
                      if (!_locationActive) _showInfoDialog(tr('location_permission_title'), tr('location_permission_msg'));
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
                        _showInfoDialog(tr('compass_unavailable_title'), tr('compass_unavailable_msg'));
                      }
                    },
                  ),

                  const SizedBox(height: 18),

                  Text(tr('general'), style: const TextStyle(color: Color(0xFFF4C025), fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 10),

                  // Language selection
                  _buildActionButton(
                    title: tr('language'),
                    subtitle: _localeLabel(EasyLocalization.of(context)!.locale),
                    icon: Icons.language,
                    onTap: _showLanguageDialog,
                  ),
                  const SizedBox(height: 8),

                  _buildActionButton(title: tr('about_qibla_compass'), subtitle: tr('version'), icon: Icons.info, onTap: () => _showInfoDialog(tr('about_qibla_compass'), tr('about_qibla_desc'))),
                  const SizedBox(height: 8),
                  _buildActionButton(title: tr('contact_us'), subtitle: tr('contact_us_desc'), icon: Icons.mail, onTap: _showContactDialog),
                  const SizedBox(height: 8),
                  _buildActionButton(title: tr('privacy_policy'), subtitle: tr('privacy_policy'), icon: Icons.verified_user, onTap: _showPrivacyPolicyDialog),

                ],
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildStatusTile({required IconData icon, required String title, required String subtitle, Widget? trailing, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x0DFFFFFF))),
        child: Row(
          children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0x14F4C025), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: const Color(0xFFF4C025))),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12))])),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _actionButton(String label, VoidCallback onTap) => TextButton(onPressed: onTap, child: Text(label, style: const TextStyle(color: Color(0xFFF4C025), fontWeight: FontWeight.w600)));

  Widget _statusChip(String label, Color bg) {
    final bgColor = bg.withAlpha((0.12 * 255).round());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildActionButton({required String title, required String subtitle, required IconData icon, VoidCallback? onTap}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: const Color(0x1AFFFFFF), borderRadius: BorderRadius.circular(20), border: Border.all(color: const Color(0x0DFFFFFF))),
        child: Row(children: [
          Container(width: 44, height: 44, decoration: BoxDecoration(color: const Color(0x0DFFFFFF), borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: Colors.white70)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)), const SizedBox(height: 4), Text(subtitle, style: const TextStyle(color: Colors.white60, fontSize: 12))])),
          const Icon(Icons.chevron_right, color: Colors.white30)
        ]),
      ),
    );
  }

  Future<void> _showLanguageDialog() async {
    final locales = EasyLocalization.of(context)!.supportedLocales;
    final current = EasyLocalization.of(context)!.locale;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tr('choose_language') == 'choose_language' ? tr('language') : tr('choose_language')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: locales
                .map((loc) => ListTile(
                      title: Text(_localeLabel(loc)),
                      trailing: loc == current ? const Icon(Icons.check, color: Color(0xFFF4C025)) : null,
                      onTap: () async {
                        final el = EasyLocalization.of(context);
                        // close dialog first to avoid using dialog context after awaiting
                        Navigator.of(ctx, rootNavigator: true).pop();
                        await el!.setLocale(loc);
                        if (!mounted) return;
                        setState(() {});
                      },

                    ))
                .toList(),
          ),
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
          TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(tr('dismiss'))),
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
        actions: [TextButton(onPressed: () => Navigator.of(ctx, rootNavigator: true).pop(), child: Text(tr('dismiss')))],
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

}
