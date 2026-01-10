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

  const HomeCompass({
    super.key,
    required this.headingDeg,
    required this.qiblaDeg,
    required this.distanceKm,
    required this.isLocationReady,
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
                border: Border.all(color: Colors.white10),
                boxShadow: [
                  BoxShadow(
                    color: const Color.fromARGB(16, 244, 192, 37),
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
                  color: Colors.white12,
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
                        border: Border.all(color: Colors.white10),
                      ),
                    ),
                    Positioned(
                      top: 16,
                      child: Text(
                        tr('north'),
                        style: TextStyle(
                          color: const Color(0xFFF4C025),
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
                          color: Colors.white24,
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
                          color: Colors.white24,
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
                          color: Colors.white24,
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
                          color: Colors.white,
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
                    const SizedBox(
                      width: 48,
                      height: 48,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: Color(0xFFF4C025),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      tr('calculating'),
                      style: const TextStyle(
                        color: Colors.white70,
                      ),
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
                            border: Border.all(
                              color: Colors.white12,
                            ),
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
                          painter: ArrowPainter(
                            color: const Color(0xFFF4C025),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          width: 6,
                          height: 120,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                const Color(0xFFF4C025),
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
            namedArgs: {
              'deg': qiblaDeg.toStringAsFixed(0),
              'dir': dir,
            },
          ),
          style: const TextStyle(
            color: Color(0xFFF4C025),
            fontSize: 40,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF121008),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white10),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.straight,
                color: Color(0xFFF4C025),
                size: 18,
              ),
              const SizedBox(width: 8),
              // show formatted distance when location is ready, otherwise show label + spinner
              if (isLocationReady) ...[
                Text(
                  tr(
                    'distance_to_mecca_fmt',
                    namedArgs: {'dist': formattedDistance},
                  ),
                  style: const TextStyle(
                    color: Color(0xFFCBCB90),
                    fontSize: 14,
                  ),
                ),
              ] else ...[
                Text(
                  tr('distance_to_mecca'),
                  style: const TextStyle(
                    color: Color(0xFFCBCB90),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
