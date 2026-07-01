// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import '../services/settings_service.dart';
import '../utils/theme_util.dart';
import '../widgets/exit_helper.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

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

  @override
  Widget build(BuildContext context) {
    final locale = context.locale;
    // Map 'id' or any other code to 'in' if that's what's in our supported list
    final String currentCode;
    if (locale.languageCode == 'id') {
      currentCode = 'in';
    } else if (_languages.containsKey(locale.languageCode)) {
      currentCode = locale.languageCode;
    } else {
      currentCode = 'en'; // default to english in dropdown if current not supported
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

                // Custom gradient button using Ink (no white border artifacts)
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
                        onTap: () async {
                          final granted =
                              await LocationService.checkAndRequestPermission();
                          
                          // Mark as seen so they don't see it again
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.setBool('seen_welcome', true);

                          if (granted) {
                            Navigator.of(context).pushReplacementNamed('/home');
                          } else {
                            Navigator.of(context).pushReplacementNamed('/permission_onboarding');
                          }
                        },
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
                                  color: isLight ? Colors.white : Colors.black,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Icon(
                                Icons.arrow_forward,
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

                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
