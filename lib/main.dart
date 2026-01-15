import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/prayer_times_screen.dart';
import 'navigation/page_transitions.dart';
import 'services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
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
    // Initialize AdMob when UI is ready (runs in background)
    // We don't await so the UI isn't blocked
    AdService.initialize();

    // Load persisted settings into the global SettingsService so listeners can react
    SettingsService.instance.load();

    // Initialize notifications after first frame to have a valid navigator key
    WidgetsBinding.instance.addPostFrameCallback((_) {
      NotificationService.instance.initialize(_navigatorKey);
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
    }
    // Optionally, when app becomes inactive/paused we could reload as well
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: EasyLocalization.of(context) != null ? tr('app_title') : 'Kiblat',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        // Optimize animations
        useMaterial3: false,
      ),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
      onGenerateRoute: (settings) {
        // Build the appropriate screen based on route name
        final Widget page;
        switch (settings.name) {
          case '/welcome':
            page = const WelcomeScreen();
            break;
          case '/home':
            page = const HomeScreen();
            break;
          case '/settings':
            page = const SettingsScreen();
            break;
          case '/prayer_times':
            final args = settings.arguments as Map<String, dynamic>?;
            page = PrayerTimesScreen(
              locationLabel: args?['locationLabel'] ?? 'Unknown',
              qiblaDeg: args?['qiblaDeg'] ?? 0.0,
            );
            break;
          default:
            return null;
        }

        // Apply smooth transitions based on route
        if (settings.name == '/welcome') {
          return PageTransitions.fadeSlideTransition((_) => page);
        } else if (settings.name == '/home') {
          return PageTransitions.fadeSlideTransition((_) => page);
        } else if (settings.name == '/settings' ||
            settings.name == '/prayer_times') {
          return PageTransitions.slideInRightTransition((_) => page);
        }

        // Default transition
        return PageTransitions.fadeSlideTransition((_) => page);
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
