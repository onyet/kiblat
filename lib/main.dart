import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'screens/welcome_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/ad_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await EasyLocalization.ensureInitialized();

  // Enable test mode in debug for easier ad testing
  if (kDebugMode) {
    AdService.setTestMode(true);
  }

  // Inisialisasi AdMob
  await AdService.initialize();

  runApp(
    EasyLocalization(
      supportedLocales: const [
        Locale('id'),
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
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Ensure an ad is loaded at app start
    AdService.instance.loadInterstitialAd();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
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
      debugShowCheckedModeBanner: false,
      title: tr('app_title'),
      theme: ThemeData(primarySwatch: Colors.blue),
      localizationsDelegates: context.localizationDelegates,
      supportedLocales: context.supportedLocales,
      locale: context.locale,
      home: const SplashScreen(),
      routes: {
        '/welcome': (context) => const WelcomeScreen(),
        '/home': (context) => const HomeScreen(),
        '/settings': (context) => const SettingsScreen(),
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

    // After animation completes and a small delay, navigate depending on build and first-run
    Future.delayed(const Duration(milliseconds: 1400), () {
      if (mounted) {
        _navigateAfterSplash();
      }
    });
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
