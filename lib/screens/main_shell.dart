import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:kiblat/screens/home_screen.dart';
import 'package:kiblat/screens/prayer_times_screen.dart';
import 'package:kiblat/screens/prayer_tracker_screen.dart';
import 'package:kiblat/screens/tasbih/tasbih_screen.dart';

/// Shell widget that hosts the main navigation with a BottomNavigationBar.
/// Tabs:
///  0 – 🧭 Kompas (HomeScreen)
///  1 – 📅 Jadwal (PrayerTimesScreen)
///  2 – 📔 Catatan (PrayerTrackerScreen)
class MainShell extends StatefulWidget {
  /// Allows external callers (e.g., SettingsScreen) to switch tabs.
  static final GlobalKey<MainShellState> shellKey =
      GlobalKey<MainShellState>();

  /// Switch to a tab from anywhere in the app tree.
  static void switchTab(int index) {
    shellKey.currentState?._setTab(index);
  }

  const MainShell({super.key});

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _currentIndex = 0;
  // Keep screens alive between tab switches using IndexedStack
  final _screens = const [
    HomeScreen(),
    PrayerTimesScreen(),
    PrayerTrackerScreen(),
    TasbihScreen(),
  ];

  @override
  void initState() {
    super.initState();
    // Honour the defaultLaunchScreen preference on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = SettingsService.instance.notifier.value;
      if (settings.defaultLaunchScreen == 'prayer_times') {
        _setTab(1);
      }
    });
  }

  void _setTab(int index) {
    if (!mounted) return;
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: SettingsService.instance.notifier,
      builder: (context, settings, _) {
        final bgColor = AppTheme.getBackgroundColor(settings, context);
        final cardColor = AppTheme.getCardColor(settings, context);
        final accentColor = AppTheme.getAccentColor(settings, context);
        final secTextColor =
            AppTheme.getSecondaryTextColor(settings, context);
        final borderColor = AppTheme.getBorderColor(settings, context);

        return Scaffold(
          backgroundColor: bgColor,
          body: IndexedStack(
            index: _currentIndex,
            children: _screens,
          ),
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: cardColor,
              border: Border(
                top: BorderSide(color: borderColor, width: 0.8),
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.15),
                  blurRadius: 12,
                  offset: const Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                height: 64,
                child: Row(
                  children: [
                    _buildNavItem(
                      index: 0,
                      icon: Icons.explore_outlined,
                      activeIcon: Icons.explore,
                      labelKey: 'compass',
                      fallback: 'Kompas',
                      accentColor: accentColor,
                      secTextColor: secTextColor,
                    ),
                    _buildNavItem(
                      index: 1,
                      icon: Icons.calendar_today_outlined,
                      activeIcon: Icons.calendar_today,
                      labelKey: 'prayers',
                      fallback: 'Jadwal',
                      accentColor: accentColor,
                      secTextColor: secTextColor,
                    ),
                    _buildNavItem(
                      index: 2,
                      icon: Icons.assignment_outlined,
                      activeIcon: Icons.assignment,
                      labelKey: 'catatan',
                      fallback: 'Catatan',
                      accentColor: accentColor,
                      secTextColor: secTextColor,
                    ),
                    _buildNavItem(
                      index: 3,
                      icon: Icons.radio_button_checked,
                      activeIcon: Icons.radio_button_checked,
                      labelKey: 'tasbih',
                      fallback: 'Tasbih',
                      accentColor: accentColor,
                      secTextColor: secTextColor,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNavItem({
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String labelKey,
    required String fallback,
    required Color accentColor,
    required Color secTextColor,
  }) {
    final isActive = _currentIndex == index;
    final label = EasyLocalization.of(context) != null &&
            tr(labelKey) != labelKey
        ? tr(labelKey)
        : fallback;

    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _setTab(index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  isActive ? activeIcon : icon,
                  key: ValueKey(isActive),
                  color: isActive ? accentColor : secTextColor,
                  size: 24,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight:
                      isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? accentColor : secTextColor,
                ),
              ),
              const SizedBox(height: 2),
              // Active indicator dot
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isActive ? 20 : 0,
                height: 2,
                decoration: BoxDecoration(
                  color: isActive ? accentColor : Colors.transparent,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
