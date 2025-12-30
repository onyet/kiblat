import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:easy_localization/easy_localization.dart';
import '../services/location_service.dart';
import 'arrow_painter.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  // Example heading in degrees. Will be updated by device compass.
  double headingDeg = 125.0;
  double qiblaDeg = 0.0; // absolute bearing to Kaaba
  double distanceKm = 0.0;
  bool _isLocationReady = false; // true when qibla bearing and distance are calculated

  StreamSubscription<double?>? _headingSub;
  String _locationLabel = 'London, UK';
  double? _lastHeading; // for smoothing


  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    // small pop animation
    _controller.forward();

    // Compass availability
    if (!LocationService.hasCompass()) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showErrorAlert(
          title: tr('compass_unavailable_title'),
          message: tr('compass_unavailable_msg'),
        );
      });
    } else {
      // Start listening to compass updates (smoothed)
      _headingSub = LocationService.headingStream().listen((val) {
        if (val != null) {
          // basic low-pass smoothing to reduce jitter
          final smoothed = _lastHeading == null ? val : (_lastHeading! * 0.8 + val * 0.2);
          _lastHeading = smoothed;
          setState(() {
            headingDeg = smoothed;
          });
        }
      });
    }

    // Check and request location permission first
    LocationService.checkAndRequestPermission().then((granted) {
      if (!granted) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _showErrorAlert(
            title: tr('location_permission_title'),
            message: tr('location_permission_msg'),
            actions: [
              DialogAction(tr('open_settings'), (ctx) async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await LocationService.openAppSettings();
              }),
              DialogAction(tr('dismiss'), (ctx) => Navigator.of(ctx, rootNavigator: true).pop()),
            ],
          );
        });
        return;
      }

      // Permissions granted - fetch location on a background async method
      _fetchAndSetLocation();
    });
  }

  @override
  void dispose() {
    _headingSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _fetchAndSetLocation() async {
    try {
      final pos = await LocationService.getCurrentPosition();
      final label = await LocationService.reverseGeocode(pos.latitude, pos.longitude);
      if (!mounted) return;
      setState(() {
        _locationLabel = label.isNotEmpty ? label : '${pos.latitude.toStringAsFixed(3)}, ${pos.longitude.toStringAsFixed(3)}';
        // compute precise qibla bearing
        qiblaDeg = LocationService.qiblaBearing(pos.latitude, pos.longitude);
        // compute distance and mark ready so arrow is shown
        distanceKm = LocationService.distanceToKaabaKm(pos.latitude, pos.longitude);
        _isLocationReady = true;
      });
    } catch (e) {
      if (!mounted) return;
      // ensure we hide arrow while failing
      setState(() { _isLocationReady = false; });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showErrorAlert(
          title: tr('location_unavailable_title'),
          message: tr('location_unavailable_msg'),
          actions: [
            DialogAction(tr('open_location_settings'), (ctx) async {
                Navigator.of(ctx, rootNavigator: true).pop();
                await LocationService.openLocationSettings();
            }),
            DialogAction(tr('dismiss'), (ctx) => Navigator.of(ctx, rootNavigator: true).pop()),
          ],
        );
      });
    }
  }

  String _dirFromDegree(double deg) {
    // convert degree to cardinal abbreviation
    final dirs = ['N', 'NE', 'E', 'SE', 'S', 'SW', 'W', 'NW'];
    final index = ((deg + 22.5) ~/ 45) % 8;
    return dirs[index];
  }

  // -- Error dialog helper --
  void _showErrorAlert({required String title, required String message, List<DialogAction>? actions}) {
    final dialogActions = actions ?? [DialogAction(tr('ok'), (ctx) => Navigator.of(ctx, rootNavigator: true).pop())];
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: dialogActions
            .map((a) => TextButton(onPressed: () => a.onPressed(ctx), child: Text(a.label)))
            .toList(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dir = _dirFromDegree(qiblaDeg);

    // Format distance according to current locale when ready
    final NumberFormat distFmt = NumberFormat.decimalPattern(context.locale.toString())
      ..minimumFractionDigits = 1
      ..maximumFractionDigits = 1;
    final String formattedDistance = distFmt.format(distanceKm);

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

                        // Rotating dial: rotate the dial opposite to device heading so that cardinal labels indicate true directions
                        Transform.rotate(
                          angle: (-headingDeg) * math.pi / 180,
                          child: SizedBox(
                            width: 300,
                            height: 300,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Needle/dial decorations (the dial rotates)
                                // decorative ring
                                Container(width: 240, height: 240, decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: Colors.white10))),

                                // cardinal labels (now move with the rotating dial)
                                Positioned(
                                  top: 16,
                                  child: Text(tr('north'), style: TextStyle(color: const Color(0xFFF4C025), fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                                Positioned(
                                  bottom: 16,
                                  child: Text(tr('south'), style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                                Positioned(
                                  left: 16,
                                  child: Text(tr('west'), style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 18)),
                                ),
                                Positioned(
                                  right: 16,
                                  child: Text(tr('east'), style: TextStyle(color: Colors.white24, fontWeight: FontWeight.bold, fontSize: 18)),
                                ),

                                // center marker
                                Positioned(
                                  child: Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(4)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        // Show loader while location/qibla are being calculated
                        if (!_isLocationReady)
                          Positioned(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const SizedBox(width: 48, height: 48, child: CircularProgressIndicator(strokeWidth: 3, color: Color(0xFFF4C025))),
                                const SizedBox(height: 8),
                                Text(tr('calculating'), style: const TextStyle(color: Colors.white70)),
                              ],
                            ),
                          )
                        else ...[
                          // Kaaba at center, rotated to face the Qibla direction (drawn before arrow so arrow is visible on top)
                          AnimatedRotation(
                            turns: ((qiblaDeg - headingDeg) / 360.0),
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeOut,
                            child: Container(
                              width: 56,
                              height: 64,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                gradient: const LinearGradient(colors: [Color(0xFF1A1A1A), Colors.black]),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: Stack(
                                children: [
                                  Positioned(top: 8, left: 0, right: 0, child: Container(height: 6, decoration: BoxDecoration(gradient: LinearGradient(colors: [const Color(0xFFBF953F), const Color(0xFFFFF6BA), const Color(0xFFBF953F)])) )),
                                  Positioned(bottom: 8, right: 8, child: Container(width: 8, height: 12, decoration: BoxDecoration(border: Border.all(color: Colors.white12), color: const Color(0x66F4C025), borderRadius: BorderRadius.circular(2))))
                                ],
                              ),
                            ),
                          ),

                          // Qibla arrow on top - rotate relative to device heading for screen alignment
                          // pointerAngle = qiblaDeg - headingDeg
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
                                    // Arrow head (larger)
                                    CustomPaint(
                                      size: const Size(28, 34),
                                      painter: ArrowPainter(color: const Color(0xFFF4C025)),
                                    ),
                                    const SizedBox(height: 6),
                                    // Shaft
                                    Container(
                                      width: 6,
                                      height: 120,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(colors: [const Color(0xFFF4C025), Colors.transparent]),
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
                    // Degrees readout (show Qibla bearing and direction)
                    Text(tr('degrees_label', namedArgs: {'deg': qiblaDeg.toStringAsFixed(0), 'dir': dir}), style: const TextStyle(color: Color(0xFFF4C025), fontSize: 40, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(color: const Color(0xFF121008), borderRadius: BorderRadius.circular(999), border: Border.all(color: Colors.white10)),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.straight, color: Color(0xFFF4C025), size: 18),
                          const SizedBox(width: 8),
                          // show formatted distance when location is ready, otherwise show label + spinner
                          if (_isLocationReady) ...[
                            Text(tr('distance_to_mecca_fmt', namedArgs: {'dist': formattedDistance}), style: const TextStyle(color: Color(0xFFCBCB90), fontSize: 14)),
                          ] else ...[
                            Text(tr('distance_to_mecca'), style: const TextStyle(color: Color(0xFFCBCB90), fontSize: 14)),
                            const SizedBox(width: 8),
                            const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                          ]
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

class DialogAction {
  final String label;
  final FutureOr<void> Function(BuildContext) onPressed;
  DialogAction(this.label, this.onPressed);
}

