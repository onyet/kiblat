import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/screens/ar_qibla_screen.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';

import 'arrow_painter.dart';

/// Stateless widget that renders the compass, qibla arrow, degree readout and distance.
class HomeCompass extends StatelessWidget {
  final double headingDeg;
  final double qiblaDeg;
  final double distanceKm;
  final bool isLocationReady;
  final String theme;
  final bool isLight;

  const HomeCompass({
    super.key,
    required this.headingDeg,
    required this.qiblaDeg,
    required this.distanceKm,
    required this.isLocationReady,
    required this.isLight,
    this.theme = 'gold',
  });

  String _dirFromDegree(double deg) {
    final dirs = ['dir_n', 'dir_ne', 'dir_e', 'dir_se', 'dir_s', 'dir_sw', 'dir_w', 'dir_nw'];
    final index = ((deg + 22.5) ~/ 45) % 8;
    return tr(dirs[index]);
  }

  @override
  Widget build(BuildContext context) {
    final dir = _dirFromDegree(qiblaDeg);

    final NumberFormat distFmt =
        NumberFormat.decimalPattern(context.locale.toString())
          ..minimumFractionDigits = 1
          ..maximumFractionDigits = 1;
    final String formattedDistance = distFmt.format(distanceKm);

    // Resolve Dynamic Theme
    final settings = SettingsService.instance.notifier.value;
    final String effectiveTheme = AppTheme.getEffectiveTheme(settings);

    // Resolve theme colors
    final Color primaryColor;
    final Color secondaryColor;
    final Color circularBorder1;
    final Color circularBorder2;
    final Color distanceBg;
    final Color distanceText;
    final Color northColor;

    switch (effectiveTheme) {
      case 'gold':
        primaryColor = isLight ? const Color(0xFFB58A0D) : const Color(0xFFD4AF37); // Gold
        secondaryColor = primaryColor.withValues(alpha: 0.5);
        circularBorder1 = isLight ? Colors.black12 : primaryColor.withValues(alpha: 0.25);
        circularBorder2 = isLight ? Colors.black.withValues(alpha: 0.08) : primaryColor.withValues(alpha: 0.4);
        distanceBg = isLight ? Colors.white : const Color(0xFF1F1B0F);
        distanceText = isLight ? Colors.black87 : const Color(0xFFFCF6BA);
        northColor = primaryColor;
        break;
      case 'dark':
        primaryColor = isLight ? Colors.black : Colors.white;
        secondaryColor = primaryColor.withValues(alpha: 0.2);
        circularBorder1 = primaryColor.withValues(alpha: 0.05);
        circularBorder2 = primaryColor.withValues(alpha: 0.1);
        distanceBg = isLight ? Colors.white : const Color(0xFF121212);
        distanceText = isLight ? Colors.black54 : Colors.white60;
        northColor = primaryColor;
        break;
      case 'cyber':
        primaryColor = const Color(0xFF00E6FF); // Cyber Cyan
        secondaryColor = const Color(0xFF00FF87).withValues(alpha: 0.5); // Cyber Green
        circularBorder1 = const Color(0xFF00E6FF).withValues(alpha: 0.2);
        circularBorder2 = const Color(0xFF00E6FF).withValues(alpha: 0.4);
        distanceBg = isLight ? Colors.white : const Color(0xFF081C1F);
        distanceText = isLight ? Colors.black87 : const Color(0xFF00FF87);
        northColor = const Color(0xFF00E6FF);
        break;
      default: // 'classic' or fallback
        primaryColor = isLight ? const Color(0xFF2E7D32) : const Color(0xFF4CAF50); // Green
        secondaryColor = primaryColor.withValues(alpha: 0.5);
        circularBorder1 = isLight ? Colors.black12 : primaryColor.withValues(alpha: 0.25);
        circularBorder2 = isLight ? Colors.black.withValues(alpha: 0.08) : primaryColor.withValues(alpha: 0.4);
        distanceBg = isLight ? Colors.white : const Color(0xFF0F1E12);
        distanceText = isLight ? Colors.black87 : const Color(0xFFC8E6C9);
        northColor = primaryColor;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Ambient glow + circular compass
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 320,
              height: 320,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: circularBorder1, width: 1.5),
                color: isLight ? Colors.white : Colors.transparent,
              ),
            ),
            Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: circularBorder2,
                  style: BorderStyle.solid,
                ),
                gradient: isLight ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white,
                    Colors.grey.shade50,
                  ],
                ) : null,
              ),
            ),

            // Rotating dial
            Transform.rotate(
              angle: (-headingDeg) * math.pi / 180,
              child: SizedBox(
                width: 300,
                height: 300,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Container(
                      width: 240,
                      height: 240,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: circularBorder1, width: 1),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      child: Text(
                        tr('north'),
                        style: TextStyle(
                          color: northColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: 16,
                      child: Text(
                        tr('south'),
                        style: TextStyle(
                          color: secondaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      left: 16,
                      child: Text(
                        tr('west'),
                        style: TextStyle(
                          color: secondaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 16,
                      child: Text(
                        tr('east'),
                        style: TextStyle(
                          color: secondaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ),

                    // center marker
                    Positioned(
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

            if (!isLocationReady)
              Positioned(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: primaryColor,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('calculating'),
                      style: TextStyle(color: isLight ? Colors.black54 : Colors.white70),
                    ),
                  ],
                ),
              )
            else ...[
              // Qibla arrow on top
              AnimatedRotation(
                turns: ((qiblaDeg - headingDeg) / 360.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: SizedBox(
                  width: 300,
                  height: 300,
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CustomPaint(
                          size: const Size(28, 34),
                          painter: ArrowPainter(color: primaryColor),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 6,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                primaryColor,
                                Colors.transparent,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              
              // Kaaba at center + Hit area for AR
              AnimatedRotation(
                turns: ((qiblaDeg - headingDeg) / 360.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
                child: GestureDetector(
                  onTap: () {
                    final settings = SettingsService.instance.notifier.value;
                    if (settings.isProUser) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ArQiblaScreen(qiblaBearing: qiblaDeg),
                        ),
                      );
                    }
                  },
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    width: 70, // larger hit area
                    height: 80,
                    alignment: Alignment.center,
                    child: Container(
                      width: 56,
                      height: 64,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF1A1A1A), Colors.black],
                        ),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Stack(
                        children: [
                          Positioned(
                            top: 8,
                            left: 0,
                            right: 0,
                            child: Container(
                              height: 6,
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Color(0xFFBF953F),
                                    Color(0xFFFFF6BA),
                                    Color(0xFFBF953F),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Positioned(
                            bottom: 8,
                            right: 8,
                            child: Container(
                              width: 8,
                              height: 12,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.white12),
                                color: const Color(0x66F4C025),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),

        const SizedBox(height: 20),
        // Degrees readout
        Text(
          tr(
            'degrees_label',
            namedArgs: {'deg': qiblaDeg.toStringAsFixed(0), 'dir': dir},
          ),
          style: TextStyle(
            color: primaryColor,
            fontSize: 40,
            fontWeight: FontWeight.bold,
            shadows: isLight ? [
              Shadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              )
            ] : null,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: distanceBg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: circularBorder1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.straight, color: primaryColor, size: 18),
              const SizedBox(width: 8),
              // show formatted distance when location is ready, otherwise show label + spinner
              if (isLocationReady) ...[
                Text(
                  tr(
                    'distance_to_mecca_fmt',
                    namedArgs: {'dist': formattedDistance},
                  ),
                  style: TextStyle(
                    color: distanceText,
                    fontSize: 14,
                    fontWeight: isLight ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
              ] else ...[
                Text(
                  tr('distance_to_mecca'),
                  style: TextStyle(
                    color: distanceText,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
