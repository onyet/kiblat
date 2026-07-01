// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/services/location_service.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:kiblat/widgets/exit_helper.dart';

class PermissionOnboardingScreen extends StatefulWidget {
  const PermissionOnboardingScreen({super.key});

  @override
  State<PermissionOnboardingScreen> createState() => _PermissionOnboardingScreenState();
}

class _PermissionOnboardingScreenState extends State<PermissionOnboardingScreen>
    with WidgetsBindingObserver {
  bool _checkingPermission = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Initial check in case it was already granted
    _checkCurrentPermission(silent: true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCurrentPermission(silent: true);
    }
  }

  Future<void> _checkCurrentPermission({bool silent = false}) async {
    if (_checkingPermission) return;
    
    // Check permission silently without triggering the OS prompt
    final granted = await LocationService.isPermissionGranted();
    if (granted && mounted) {
      Navigator.of(context).pushReplacementNamed('/home');
    }
  }

  Future<void> _requestLocationPermission() async {
    if (_checkingPermission) return;
    
    setState(() => _checkingPermission = true);
    final granted = await LocationService.checkAndRequestPermission();
    setState(() => _checkingPermission = false);

    if (granted) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } else {
      if (mounted) {
        showDialog(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(
              tr('permission_denied_title'),
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
            content: Text(
              tr('permission_denied_desc'),
              style: const TextStyle(color: Colors.black87),
            ),
            actions: [
              TextButton(
                onPressed: () async {
                  Navigator.of(ctx).pop();
                  await LocationService.openAppSettings();
                },
                child: Text(
                  tr('open_settings'),
                  style: const TextStyle(color: Color(0xFFB58A0D), fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: Text(
                  tr('dismiss'),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final isLight = AppTheme.isLight(settings, context);
    final accentColor = AppTheme.getAccentColor(settings, context);
    final bgColor = isLight ? Colors.white : const Color(0xFF0F0F0F);
    final textColor = isLight ? Colors.black87 : Colors.white;
    final subTextColor = isLight ? Colors.black54 : Colors.white70;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await showExitAndMaybeShowAd(context);
      },
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              children: [
                const Spacer(),

                // Animated location permission graphics (premium concentric circles style)
                Center(
                  child: SizedBox(
                    width: 160,
                    height: 160,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Outer glowing circle
                        Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.05),
                          ),
                        ),
                        // Middle circle
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.1),
                          ),
                        ),
                        // Inner circle
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor.withValues(alpha: 0.15),
                            boxShadow: [
                              BoxShadow(
                                color: accentColor.withValues(alpha: 0.3),
                                blurRadius: 20,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.location_on,
                            size: 40,
                            color: accentColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                // Title
                Text(
                  tr('permission_onboarding_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w800,
                    fontSize: 26,
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 16),

                // Description
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    tr('permission_onboarding_desc'),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: subTextColor,
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),

                const Spacer(),

                // Loading Indicator / Button
                if (_checkingPermission)
                  const CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFD4AF37)),
                  )
                else
                  Column(
                    children: [
                      // Grant permission button
                      SizedBox(
                        width: double.infinity,
                        child: Material(
                          color: Colors.transparent,
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [accentColor, accentColor.withValues(alpha: 0.85)],
                              ),
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: _requestLocationPermission,
                              child: Container(
                                alignment: Alignment.center,
                                constraints: const BoxConstraints(minHeight: 52),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      tr('grant_permission'),
                                      style: TextStyle(
                                        color: isLight ? Colors.white : Colors.black,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.arrow_forward_rounded,
                                      color: isLight ? Colors.white : Colors.black,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 16),
                      
                      // Fallback Settings Button
                      TextButton.icon(
                        onPressed: () => LocationService.openAppSettings(),
                        icon: Icon(Icons.settings_outlined, color: accentColor, size: 20),
                        label: Text(
                          tr('open_settings'),
                          style: TextStyle(
                            color: accentColor,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
