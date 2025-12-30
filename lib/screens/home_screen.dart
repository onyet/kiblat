import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/location_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // Example heading in degrees. Will be updated by device compass.
  double headingDeg = 125.0;

  StreamSubscription<double?>? _headingSub;
  String _locationLabel = 'London, UK';

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    // small pop animation
    _controller.forward();

    // Start listening to compass updates
    _headingSub = LocationService.headingStream().listen((val) {
      if (val != null) {
        setState(() {
          headingDeg = val;
        });
      }
    });

    // Get location once and reverse geocode
    LocationService.getCurrentPosition().then((pos) async {
      final label = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      setState(() {
        _locationLabel = label.isNotEmpty ? label : '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
      });
    }).catchError((e) {
      // ignore - keep default
    });
  }

  @override
  void dispose() {
    _headingSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String _dirFromDegree(double deg) {
    // convert degree to cardinal abbreviation
    final dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((deg + 22.5) ~/ 45) % 8;
    return dirs[index];
  }

  @override
  Widget build(BuildContext context) {
    final dir = _dirFromDegree(headingDeg);
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with location + settings
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 36), // spacer
                  Column(
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.location_on, color: Colors.white70, size: 18),
                          const SizedBox(width: 6),
                          Text(tr('current_location'), style: const TextStyle(color: Colors.white70, fontSize: 12))
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(_locationLabel, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold))
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.settings, color: Colors.white70),
                    onPressed: () {
                      // open settings (not implemented)
                    },
                  )
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Compass
            Expanded(
              child: Center(
                child: Column(
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
                            boxShadow: [BoxShadow(color: const Color.fromARGB(16, 244, 192, 37), blurRadius: 40)],
                          ),
                        ),
                        Container(
                          width: 300,
                          height: 300,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white12, style: BorderStyle.solid),
                          ),
                        ),

                        // Cardinal labels
                        Positioned(
                          top: 28,
                          child: Text('N', style: TextStyle(color: const Color(0xFFF4C025), fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        Positioned(
                          bottom: 28,
                          child: Text('S', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        Positioned(
                          left: 28,
                          child: Text('W', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 18)),
                        ),
                        Positioned(
                          right: 28,
                          child: Text('E', style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 18)),
                        ),

                        // Rotating needle layer
                        Transform.rotate(
                          angle: (headingDeg) * math.pi / 180,
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Needle head
                                Positioned(
                                  top: 8,
                                  child: Column(
                                    children: [
                                      Container(
                                        width: 0,
                                        height: 0,
                                        decoration: const BoxDecoration(),
                                        child: CustomPaint(
                                          size: const Size(20, 24),
                                          painter: _TrianglePainter(color: const Color(0xFFF4C025)),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Container(width: 3, height: 80, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFF4C025), Colors.transparent])),),
                                    ],
                                  ),
                                ),

                                // decorative ring
                                Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white10))),

                                // center Kaaba box
                                Container(
                                  width: 56,
                                  height: 64,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Colors.black]),
                                    border: Border.all(color: Colors.white10),
                                  ),
                                  child: Stack(
                                    children: [
                                      Positioned(top: 8, left: 0, right: 0, child: Container(height: 6, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFBF953F), const Color(0xFFFFF6BA), const Color(0xFFBF953F)])))),
                                      Positioned(bottom: 8, right: 8, child: Container(width: 8, height: 12, decoration: BoxDecoration(border: Border.all(color: Colors.white12), color: const Color(0x66F4C025), borderRadius: BorderRadius.circular(2))))
                                    ],
                                  ),
                                )
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    // Degrees readout
                    Text(tr('degrees_label', namedArgs: {'deg': headingDeg.toStringAsFixed(0), 'dir': dir}), style: const TextStyle(color: Color(0xFFF4C025), fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF121008), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.straight, color: Color(0xFFF4C025), size: 18),
                          const SizedBox(width: 8),
                          Text(tr('distance_to_mecca'), style: const TextStyle(color: Color(0xFFCBCB90), fontSize: 14)),
                        ],
                      ),
                    )
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),
          ],
        ),
      ),
    );
  }
}

class _TrianglePainter extends CustomPainter {
  final Color color;
  const _TrianglePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
