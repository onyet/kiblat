import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:geolocator/geolocator.dart';

import '../services/location_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _locationActive = false;
  bool _compassAvailable = false;

  @override
  void initState() {
    super.initState();
    _refreshStatus();
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
                  // Ambient glow
                  Align(alignment: Alignment.topRight, child: Container(width: 160, height: 160, decoration: BoxDecoration(color: const Color(0x0FF4C025), borderRadius: BorderRadius.circular(999)))) ,

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

                  _buildActionButton(title: tr('about_qibla_compass'), subtitle: tr('version'), icon: Icons.info, onTap: () => _showInfoDialog(tr('about_qibla_compass'), tr('version'))),
                  const SizedBox(height: 8),
                  _buildActionButton(title: tr('contact_us'), subtitle: tr('contact_us_desc'), icon: Icons.mail, onTap: () => _showInfoDialog(tr('contact_us'), tr('contact_us_desc'))),
                  const SizedBox(height: 8),
                  _buildActionButton(title: tr('privacy_policy'), subtitle: tr('privacy_policy'), icon: Icons.verified_user, onTap: () => _showInfoDialog(tr('privacy_policy'), tr('privacy_policy'))),

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


}
