// ignore_for_file: use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/location_service.dart';
import '../widgets/exit_helper.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  static const _languages = <String, String>{
    'in': 'Indonesia',
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
    final currentCode = context.locale.languageCode == 'id' ? 'in' : context.locale.languageCode;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await showExitAndMaybeShowAd(context);
      },
      child: Scaffold(
        backgroundColor: const Color(0xFF050505), // kaaba-black
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
                          color: const Color.fromARGB(31, 244, 192, 37),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(56, 244, 192, 37),
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
                  style: const TextStyle(
                    color: Color(0xFFF4C025),
                    fontWeight: FontWeight.bold,
                    fontSize: 28,
                  ),
                ),

                const SizedBox(height: 8),

                Text(
                  tr('welcome_description'),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white60,
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
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          dropdownColor: const Color(0xFF121212),
                          value: currentCode,
                          items: _languages.entries
                              .map(
                                (e) => DropdownMenuItem(
                                  value: e.key,
                                  child: Text(
                                    e.value,
                                    style: const TextStyle(color: Colors.white),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFFD4AF37), Color(0xFFF4C025)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () async {
                          final granted =
                              await LocationService.checkAndRequestPermission();
                          if (granted) {
                            Navigator.of(context).pushReplacementNamed('/home');
                            return;
                          }

                          final res = await showDialog<bool>(
                            context: context,
                            barrierDismissible: true,
                            builder: (ctx) => AlertDialog(
                              title: Text(tr('location_permission_title')),
                              content: Text(tr('location_permission_msg')),
                              actions: [
                                TextButton(
                                  onPressed: () async {
                                    Navigator.of(
                                      ctx,
                                      rootNavigator: true,
                                    ).pop(false);
                                    await LocationService.openAppSettings();
                                  },
                                  child: Text(tr('open_settings')),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.of(
                                    ctx,
                                    rootNavigator: true,
                                  ).pop(true),
                                  child: Text(tr('dismiss')),
                                ),
                              ],
                            ),
                          );

                          if (res == true) {
                            Navigator.of(context).pushReplacementNamed('/home');
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
                                style: const TextStyle(
                                  color: Colors.black,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(
                                Icons.arrow_forward,
                                color: Colors.black,
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
