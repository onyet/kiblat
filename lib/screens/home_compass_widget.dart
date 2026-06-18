import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';

import 'arrow_painter.dart';

/// Stateless widget that renders the compass, qibla arrow, degree readout and distance.
class HomeCompass extends StatelessWidget {
  final double headingDeg;
  final double qiblaDeg;
  final double distanceKm;
  final bool isLocationReady;
  final String theme;

  const HomeCompass({
    super.key,
    required this.headingDeg,
    required this.qiblaDeg,
    required this.distanceKm,
    required this.isLocationReady,
    this.theme = 'classic',
  });

  String _dirFromDegree(double deg) {
    final dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((deg + 22.5) ~/ 45) % 8;
    return dirs[index];
  }

  @override
  Widget build(BuildContext context) {
    final dir = _dirFromDegree(qiblaDeg);

    final NumberFormat distFmt =
        NumberFormat.decimalPattern(context.locale.toString())
          ..minimumFractionDigits = 1
          ..maximumFractionDigits = 1;
    final String formattedDistance = distFmt.format(distanceKm);

    // Resolve theme colors
    final Color primaryColor;
    final Color secondaryColor;
    final Color circularBorder1;
    final Color circularBorder2;
    final Color shadowColor;
    final Color distanceBg;
    final Color distanceText;
    final Color northColor;

    switch (theme) {
      case 'gold':
        primaryColor = const Color(0xFFD4AF37); // Gold
        secondaryColor = const Color(0xFFD4AF37).withOpacity(0.5);
        circularBorder1 = const Color(0xFFD4AF37).withOpacity(0.25);
        circularBorder2 = const Color(0xFFD4AF37).withOpacity(0.4);
        shadowColor = const Color(0xFFD4AF37).withOpacity(0.15);
        distanceBg = const Color(0xFF1F1B0F);
        distanceText = const Color(0xFFFCF6BA);
        northColor = const Color(0xFFD4AF37);
        break;
      case 'dark':
        primaryColor = Colors.white;
        secondaryColor = Colors.white.withOpacity(0.2);
        circularBorder1 = Colors.white.withOpacity(0.05);
        circularBorder2 = Colors.white.withOpacity(0.1);
        shadowColor = Colors.white.withOpacity(0.05);
        distanceBg = const Color(0xFF121212);
        distanceText = Colors.white60;
        northColor = Colors.white;
        break;
      case 'cyber':
        primaryColor = const Color(0xFF00E6FF); // Cyber Cyan
        secondaryColor = const Color(0xFF00FF87).withOpacity(0.5); // Cyber Green
        circularBorder1 = const Color(0xFF00E6FF).withOpacity(0.2);
        circularBorder2 = const Color(0xFF00E6FF).withOpacity(0.4);
        shadowColor = const Color(0xFF00E6FF).withOpacity(0.15);
        distanceBg = const Color(0xFF081C1F);
        distanceText = const Color(0xFF00FF87);
        northColor = const Color(0xFF00E6FF);
        break;
      case 'classic':
      default:
        primaryColor = const Color(0xFFF4C025); // Classic Yellow/Gold
        secondaryColor = Colors.white24;
        circularBorder1 = Colors.white10;
        circularBorder2 = Colors.white12;
        shadowColor = const Color(0xFFF4C025).withOpacity(0.06);
        distanceBg = const Color(0xFF121008);
        distanceText = const Color(0xFFCBCB90);
        northColor = const Color(0xFFF4C025);
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
                border: Border.all(color: circularBorder1),
                boxShadow: [
                  BoxShadow(
                    color: shadowColor,
                    blurRadius: 40,
                  ),
                ],
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
                        border: Border.all(color: circularBorder1),
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
                      style: const TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              )
            else ...[
              // Kaaba at center
              AnimatedRotation(
                turns: ((qiblaDeg - headingDeg) / 360.0),
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOut,
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
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFBF953F),
                                const Color(0xFFFFF6BA),
                                const Color(0xFFBF953F),
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
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
