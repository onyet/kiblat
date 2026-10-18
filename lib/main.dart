import 'dart:async';

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/welcome_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/main_shell.dart';
import 'navigation/page_transitions.dart';
import 'services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/services/notification_service.dart';
import 'package:kiblat/services/home_widget_service.dart';
import 'package:kiblat/services/billing_service.dart';
import 'package:kiblat/services/geonames_service.dart';
import 'package:kiblat/services/location_service.dart';
import 'package:kiblat/services/location_profile_service.dart';
import 'package:kiblat/services/calc_preset_service.dart';
import 'package:kiblat/services/qada_service.dart';
import 'package:kiblat/services/tasbih_pro_service.dart';
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
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  // Migrate old 'id' locale to 'in' for existing users before EasyLocalization init
  await _migrateIndonesianLocale();

  await EasyLocalization.ensureInitialized();

  // AdMob initialization moved to `MainApp.initState` to avoid blocking startup
  // (initialization now happens when the app's UI is ready)

  // Lock orientation to portrait only (phone-focused UX)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Only initialize AdMob for non-pro users (Privacy First)
  // We check the persisted Pro status here if possible, or just initialize anyway.
  // Initializing multiple times is fine per AdService logic.
  final prefs = await SharedPreferences.getInstance();
  final isPro = prefs.getBool('isProUser') ?? false;
  if (!isPro) {
    debugPrint('[Main] AdMob initialization deferred to _runInitialization');
  }

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

  /// Completes when background services finish (or fail safely).
  /// Never throws [LateInitializationError] if Splash reads it early.
  static Future<void> initFuture = Future.value();

  @override
  State<MainApp> createState() => _MainAppState();
}

class _MainAppState extends State<MainApp> with WidgetsBindingObserver {
  final GlobalKey<NavigatorState> _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Start background initialization immediately
    MainApp.initFuture = _runInitialization();

    // Remove the native splash screen as soon as the first Flutter frame is drawn
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
    });
  }

  Future<void> _safeInit(String label, Future<void> Function() run) async {
    try {
      await run();
    } catch (e, st) {
      debugPrint('[Startup] $label failed: $e\n$st');
    }
  }

  Future<void> _runInitialization() async {
    debugPrint('[Startup] Background initialization started');
    try {
      // Independent I/O in parallel to shorten time-to-interactive.
      debugPrint('[Startup] Initializing GeoNamesService + Settings');
      await Future.wait([
        _safeInit('GeoNames', () => GeoNamesService.instance.initialize()),
        _safeInit('Settings', () => SettingsService.instance.load()),
        _safeInit('LocationProfiles', () => LocationProfileService.instance.load()),
        _safeInit('CalcPresets', () => CalcPresetService.instance.load()),
        _safeInit('Qada', () => QadaService.instance.load()),
        _safeInit('TasbihPro', () => TasbihProService.instance.load()),
      ]);

      final prayerSettings = SettingsService.instance.notifier.value;
      debugPrint(
        '[Startup] Settings loaded. isPro: ${prayerSettings.isProUser}',
      );

      // Billing, notifications, and (when needed) ads are independent after settings.
      // Failures must not crash cold start (Play review "broken functionality").
      debugPrint('[Startup] Initializing Billing + Notifications'
          '${prayerSettings.isProUser ? '' : ' + Ads'}');
      await Future.wait([
        _safeInit('Billing', () => BillingService.instance.initialize()),
        _safeInit(
          'Notifications',
          () => NotificationService.instance.initialize(_navigatorKey),
        ),
        if (!prayerSettings.isProUser)
          _safeInit('Ads', () => AdService.initialize()),
      ]);

      if (prayerSettings.enablePrayerNotifications) {
        debugPrint('[Startup] Scheduling Notifications');
        unawaited(
          NotificationService.instance
              .schedulePrayerNotificationsForCurrentLocation(prayerSettings),
        );
      }

      debugPrint('[Startup] Initializing HomeWidgetService');
      unawaited(
        _safeInit('HomeWidget', () => HomeWidgetService.instance.initialize()),
      );

      debugPrint('[Startup] Background initialization completed');
    } catch (e, st) {
      debugPrint('[Startup] Initialization error: $e\n$st');
    }
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
          title: EasyLocalization.of(context) != null
              ? tr('app_title')
              : 'Kiblat',
          theme: ThemeData(
            brightness: isLight ? Brightness.light : Brightness.dark,
            primaryColor: AppTheme.getAccentColor(prayerSettings),
            scaffoldBackgroundColor: AppTheme.getBackgroundColor(
              prayerSettings,
              context,
            ),
            cardColor: AppTheme.getCardColor(prayerSettings, context),
            useMaterial3: true,
            // ── Component themes so ALL widgets inherit the active accent ──
            colorScheme: ColorScheme(
              brightness: isLight ? Brightness.light : Brightness.dark,
              primary: AppTheme.getAccentColor(prayerSettings),
              onPrimary: Colors.white,
              secondary: AppTheme.getAccentColor(prayerSettings),
              onSecondary: Colors.white,
              error: Colors.redAccent,
              onError: Colors.white,
              surface: AppTheme.getCardColor(prayerSettings, context),
              onSurface: AppTheme.getTextColor(prayerSettings, context),
            ),
            progressIndicatorTheme: ProgressIndicatorThemeData(
              color: AppTheme.getAccentColor(prayerSettings),
              linearTrackColor: AppTheme.getAccentColor(
                prayerSettings,
              ).withValues(alpha: 0.1),
            ),
            iconTheme: IconThemeData(
              color: AppTheme.getAccentColor(prayerSettings),
            ),
            elevatedButtonTheme: ElevatedButtonThemeData(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.getAccentColor(prayerSettings),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
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
                side: BorderSide(
                  color: AppTheme.getAccentColor(prayerSettings),
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            cardTheme: CardThemeData(
              color: AppTheme.getCardColor(prayerSettings, context),
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(
                  color: AppTheme.getBorderColor(prayerSettings, context),
                ),
              ),
            ),
            chipTheme: ChipThemeData(
              backgroundColor: AppTheme.getCardColor(prayerSettings, context),
              labelStyle: TextStyle(
                color: AppTheme.getTextColor(prayerSettings, context),
              ),
              side: BorderSide(
                color: AppTheme.getBorderColor(prayerSettings, context),
              ),
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
                  return AppTheme.getAccentColor(
                    prayerSettings,
                  ).withValues(alpha: 0.4);
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
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _progressController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;
  late final TickerFuture _progressTicker;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
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
    _progressTicker = _progressController.forward();

    // Pre-warm the animation curves to avoid first-frame lag
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _warmUpAnimations();
    });

    _startTransitionTimer();
  }

  Future<void> _startTransitionTimer() async {
    // 1. Wait for MainApp's background services initialization to complete
    // Added a safety timeout of 5 seconds to prevent hanging on splash
    try {
      await MainApp.initFuture.timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('[SplashScreen] Initialization timed out or failed: $e');
    }

    // 2. Wait for the progress bar animation to complete (min 1500ms for visual polish)
    try {
      await _progressTicker;
    } catch (e) {
      debugPrint('[SplashScreen] Progress ticker error: $e');
    }

    if (mounted) {
      debugPrint('[SplashScreen] Transitioning to next screen');
      _navigateAfterSplash();
    }
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
    _progressController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<PrayerSettings>(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, settings, child) {
        final isLight = AppTheme.isLight(settings, context);
        final bgColor = isLight ? Colors.white : const Color(0xFF0F0F0F);

        return Scaffold(
          backgroundColor: bgColor,
          body: Stack(
            children: [
              Center(
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: _buildLogo(settings),
                  ),
                ),
              ),
              // Gradient or decorative element to ensure it's not "blank"
              Positioned.fill(
                child: IgnorePointer(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        colors: [
                          const Color(
                            0xFFD4AF37,
                          ).withValues(alpha: isLight ? 0.05 : 0.02),
                          Colors.transparent,
                        ],
                        radius: 1.2,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLogo(PrayerSettings settings) {
    final accentColor = AppTheme.getAccentColor(settings, context);
    final isLight = AppTheme.isLight(settings, context);
    final titleColor = isLight
        ? const Color(0xFFB58A0D)
        : const Color(0xFFD4AF37);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset('assets/images/logo.png', width: 120, height: 120),
        const SizedBox(height: 12),
        Text(
          'Kiblat',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
        const SizedBox(height: 28),
        // Premium horizontal progress bar
        Container(
          width: 160,
          height: 4,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(2),
            boxShadow: [
              BoxShadow(
                color: accentColor.withValues(alpha: 0.25),
                blurRadius: 8,
                offset: const Offset(0, 1),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: AnimatedBuilder(
              animation: _progressController,
              builder: (context, child) {
                return LinearProgressIndicator(
                  value: _progressController.value,
                  backgroundColor: accentColor.withValues(alpha: 0.1),
                  valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                );
              },
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _navigateAfterSplash() async {
    // Determine the next screen based on settings
    String nextRoute = '/home';
    try {
      final prefs = await SharedPreferences.getInstance();
      // Ensure we clear any stale state if needed, but normally null means first run
      final seen = prefs.getBool('seen_welcome') ?? false;
      debugPrint('Splash navigation: seen_welcome = $seen');
      if (!seen) {
        nextRoute = '/welcome';
      } else {
        // If welcome screen was already seen, verify silently if GPS permission is granted
        final hasGps = await LocationService.isPermissionGranted();
        if (!hasGps) {
          nextRoute = '/welcome';
        }
      }
    } catch (e) {
      debugPrint('Splash navigation pref error: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(nextRoute);
  }
}
