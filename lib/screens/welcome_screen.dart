// ignore_for_file: use_build_context_synchronously

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../utils/theme_util.dart';
import '../widgets/exit_helper.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with WidgetsBindingObserver {
  static const _languages = <String, String>{
    'in': 'Bahasa Indonesia',
    'ar': 'العربية',
    'en': 'English',
    'zh': '中文',
    'ru': 'Русский',
    'ja': '日本語',
    'de': 'Deutsch',
    'pt': 'Português',
  };

  bool _permissionGranted = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Silent permission check on launch
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkCurrentPermissionSilently();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkCurrentPermissionSilently();
    }
  }

  Future<void> _checkCurrentPermissionSilently() async {
    final granted = await LocationService.isPermissionGranted();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
      });
    }
  }

  Future<void> _requestLocationPermission() async {
    final granted = await LocationService.checkAndRequestPermission();
    if (mounted) {
      setState(() {
        _permissionGranted = granted;
      });
    }

    if (!granted) {
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
    final locale = context.locale;
    final String currentCode;
    if (locale.languageCode == 'id') {
      currentCode = 'in';
    } else if (_languages.containsKey(locale.languageCode)) {
      currentCode = locale.languageCode;
    } else {
      currentCode = 'en';
    }

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
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Column(
              children: [
                const Spacer(),

                // logo
                SizedBox(
                  width: 140,
                  height: 140,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: accentColor.withValues(alpha: 0.12),
                          boxShadow: [
                            BoxShadow(
                              color: accentColor.withValues(alpha: 0.22),
                              blurRadius: 30,
                              spreadRadius: -10,
                            ),
                          ],
                        ),
                      ),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: Image.asset(
                          'assets/images/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 18),

                // title
                Text(
                  tr('welcome_title'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: isLight ? const Color(0xFFB58A0D) : const Color(0xFFD4AF37),
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  tr('welcome_description'),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),

                const Spacer(),

                // Required Permissions List (Premium Layout)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: textColor.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: _permissionGranted
                          ? Colors.green.withValues(alpha: 0.3)
                          : Colors.red.withValues(alpha: 0.2),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        color: _permissionGranted ? Colors.green : accentColor,
                        size: 28,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tr('location_access'),
                              style: TextStyle(
                                color: textColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tr('location_access_desc'),
                              style: TextStyle(
                                color: subTextColor,
                                fontSize: 13,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Status / Grant Action
                      if (_permissionGranted)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 28,
                        )
                      else
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accentColor,
                            foregroundColor: isLight ? Colors.white : Colors.black,
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          onPressed: _requestLocationPermission,
                          child: Text(
                            tr('grant_permission').split(' ')[0], // Get first word: e.g. "Grant" / "Berikan"
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),

                const Spacer(),

                // Language selector (above button)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${tr('language')}: ',
                      style: TextStyle(color: subTextColor),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: textColor.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: bgColor,
                          value: currentCode,
                          items: _languages.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    style: TextStyle(color: textColor),
                                  ),
                                ),
                              )
                              .toList(),
                          onChanged: (val) {
                            if (val != null) {
                              context.setLocale(Locale(val));
                            }
                          },
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 18),

                // Primary Gradient Action Button
                Column(
                  children: [
                    SizedBox(
                      width: double.infinity,
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        child: Ink(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: _permissionGranted
                                  ? [accentColor, accentColor.withValues(alpha: 0.85)]
                                  : [textColor.withValues(alpha: 0.1), textColor.withValues(alpha: 0.05)],
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _permissionGranted
                                ? () async {
                                    final prefs = await SharedPreferences.getInstance();
                                    await prefs.setBool('seen_welcome', true);
                                    Navigator.of(context).pushReplacementNamed('/home');
                                  }
                                : null, // Disabled until permissions are granted
                            child: Container(
                              alignment: Alignment.center,
                              constraints: const BoxConstraints(minHeight: 48),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    tr('get_started'),
                                    style: TextStyle(
                                      color: _permissionGranted
                                          ? (isLight ? Colors.white : Colors.black)
                                          : subTextColor,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.arrow_forward,
                                    color: _permissionGranted
                                        ? (isLight ? Colors.white : Colors.black)
                                        : subTextColor,
                                    size: 20,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
