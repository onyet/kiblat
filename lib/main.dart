import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_shell.dart';
import 'navigation/page_transitions.dart';
import 'services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/services/notification_service.dart';
import 'package:kiblat/services/home_widget_service.dart';
import 'package:kiblat/services/billing_service.dart';
import 'package:kiblat/models/prayer_settings_model.dart';
import 'package:kiblat/utils/theme_util.dart';

/// Migrate old Indonesian locale code 'id' to 'in' for existing users
/// EasyLocalization stores locale in SharedPreferences with key 'locale'
/// Old users who selected Indonesian had 'id' saved, but file is now 'in.json'
Future<void> _migrateIndonesianLocale() async {
  final prefs = await SharedPreferences.getInstance();
  final savedLocale = prefs.getString('locale');

  // Check if saved locale is the old 'id' code (could be 'id', 'id_', 'id_ID', etc.)
  if (savedLocale != null && savedLocale.startsWith('id')) {
    // Migrate to new 'in' code
    await prefs.setString('locale', 'in');
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Migrate old 'id' locale to 'in' for existing users before EasyLocalization init
  await _migrateIndonesianLocale();

  await EasyLocalization.ensureInitialized();

  // Enable test mode in debug for easier ad testing
  if (kDebugMode) {
    AdService.setTestMode(true);
  }

  // AdMob initialization moved to `MainApp.initState` to avoid blocking startup
  // (initialization now happens when the app's UI is ready)

  // Lock orientation to portrait only (phone-focused UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('in'),
        Locale('ar'),
        Locale('en'),
        Locale('zh'),
        Locale('ru'),
        Locale('ja'),
        Locale('de'),
        Locale('pt'),
      ],
      // Force start locale to 'in' to avoid loading legacy 'id.json' on some devices
      startLocale: const Locale('in'),
      path: 'assets/translations',
      fallbackLocale: const Locale('en'),
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatefulWidget {
  const MainApp({super.key});

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Initialize notifications and load settings after first frame to avoid blocking UI
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      // Load persisted settings into the global SettingsService so listeners can react
      await SettingsService.instance.load();
      await BillingService.instance.initialize();

      final prayerSettings = SettingsService.instance.notifier.value;

      // Only initialize AdMob for non-pro users (Privacy First)
      if (!prayerSettings.isProUser) {
        await AdService.initialize();
      }

      await NotificationService.instance.initialize(_navigatorKey);

      if (prayerSettings.enablePrayerNotifications) {
        unawaited(
          NotificationService.instance
              .schedulePrayerNotificationsForCurrentLocation(prayerSettings),
        );
      }

      // Initialize home widget service for Android/iOS home screen widgets
      unawaited(HomeWidgetService.instance.initialize());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Dispose AdService to avoid background callbacks trying to speak to a detached engine
    try {
      AdService.instance.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // When app resumes, refresh/load interstitial so it's ready when user closes later
    if (state == AppLifecycleState.resumed) {
      AdService.instance.reloadInterstitialAd();
      
      final prayerSettings = SettingsService.instance.notifier.value;
      if (prayerSettings.enablePrayerNotifications) {
        unawaited(
          NotificationService.instance
              .schedulePrayerNotificationsForCurrentLocation(prayerSettings),
        );
      }
    }
    // Optionally, when app becomes inactive/paused we could reload as well
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PrayerSettings>(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, prayerSettings, child) {
        final isLight = AppTheme.isLight(prayerSettings, context);
        return MaterialApp(
          navigatorKey: _navigatorKey,
          debugShowCheckedModeBanner: false,
          title: EasyLocalization.of(context) != null ? tr('app_title') : 'Kiblat',
          theme: ThemeData(
            brightness: isLight ? Brightness.light : Brightness.dark,
            primaryColor: AppTheme.getAccentColor(prayerSettings),
            scaffoldBackgroundColor: AppTheme.getBackgroundColor(prayerSettings, context),
            cardColor: AppTheme.getCardColor(prayerSettings, context),
            useMaterial3: false,
            // ── Component themes so ALL widgets inherit the active accent ──
            colorScheme: ColorScheme(
              brightness: isLight ? Brightness.light : Brightness.dark,
              primary: AppTheme.getAccentColor(prayerSettings),
              onPrimary: isLight ? Colors.white : Colors.black,
              secondary: AppTheme.getAccentColor(prayerSettings),
              onSecondary: isLight ? Colors.white : Colors.black,
              error: Colors.redAccent,
              onError: Colors.white,
              surface: AppTheme.getCardColor(prayerSettings, context),
              onSurface: AppTheme.getTextColor(prayerSettings, context),
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: AppTheme.getAccentColor(prayerSettings),
              linearTrackColor: AppTheme.getAccentColor(prayerSettings).withValues(alpha: 0.1),
            ),
            iconTheme: IconThemeData(
              color: AppTheme.getAccentColor(prayerSettings),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getAccentColor(prayerSettings),
                foregroundColor: isLight ? Colors.black : Colors.black,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.getAccentColor(prayerSettings),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.getAccentColor(prayerSettings),
                side: BorderSide(color: AppTheme.getAccentColor(prayerSettings)),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: AppTheme.getCardColor(prayerSettings, context),
              labelStyle: TextStyle(color: AppTheme.getTextColor(prayerSettings, context)),
              side: BorderSide(color: AppTheme.getBorderColor(prayerSettings, context)),
            ),
            switchTheme: SwitchThemeData(
              thumbColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.getAccentColor(prayerSettings);
                }
                return null;
              }),
              trackColor: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return AppTheme.getAccentColor(prayerSettings).withValues(alpha: 0.4);
                }
                return null;
              }),
            ),
          ),
          localizationsDelegates: context.localizationDelegates,
          supportedLocales: context.supportedLocales,
          locale: context.locale,
          home: const SplashScreen(),
          onGenerateRoute: (settings) {
            final Widget page;
            switch (settings.name) {
              case '/welcome':
                page = const WelcomeScreen();
                break;
              case '/home':
                page = MainShell(key: MainShell.shellKey);
                break;
              case '/settings':
                page = const SettingsScreen();
                break;
              default:
                return null;
            }

            if (settings.name == '/welcome') {
              return PageTransitions.fadeSlideTransition((_) => page);
            } else if (settings.name == '/home') {
              return PageTransitions.fadeSlideTransition((_) => page);
            } else if (settings.name == '/settings') {
              return PageTransitions.slideInRightTransition((_) => page);
            }

            return PageTransitions.fadeSlideTransition((_) => page);
          },
        );
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.05,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutBack));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeIn));

    _controller.forward();

    // Pre-warm the animation curves to avoid first-frame lag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUpAnimations();
    });

    // After animation completes and a small delay, navigate depending on build and first-run
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        _navigateAfterSplash();
      }
    });
  }

  /// Pre-compile animation curves to reduce first-transition lag
  void _warmUpAnimations() {
    // Pre-warm easeOutCubic curve used in transitions
    Curves.easeOutCubic.transform(0.5);
    // Pre-warm linear curve
    Curves.linear.transform(0.5);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: ScaleTransition(scale: _scaleAnimation, child: _buildLogo()),
        ),
      ),
    );
  }

  Widget _buildLogo() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/logo.png', width: 120, height: 120),
        const SizedBox(height: 12),
        const Text(
          'Kiblat',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Future<void> _navigateAfterSplash() async {
    // In debug builds, always show the welcome screen for testing
    if (kDebugMode) {
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/welcome');
      return;
    }

    // In production, show Welcome only on first run
    try {
      final prefs = await SharedPreferences.getInstance();
      final seen = prefs.getBool('seen_welcome') ?? false;
      if (!seen) {
        await prefs.setBool('seen_welcome', true);
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/welcome');
      } else {
        if (!mounted) return;
        Navigator.of(context).pushReplacementNamed('/home');
      }
    } catch (e) {
      // On error, fallback to welcome screen
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/welcome');
    }
  }
}
