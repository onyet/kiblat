import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:kiblat/services/settings_service.dart';
import 'package:kiblat/utils/theme_util.dart';
import 'package:kiblat/widgets/ar_3d_arrow_painter.dart';

class ArQiblaScreen extends StatefulWidget {
  final double qiblaBearing;
  const ArQiblaScreen({super.key, required this.qiblaBearing});

  @override
  State<ArQiblaScreen> createState() => _ArQiblaScreenState();
}

class _ArQiblaScreenState extends State<ArQiblaScreen> {
  CameraController? _cameraController;
  StreamSubscription? _compassSubscription;
  double _heading = 0;
  bool _isCameraReady = false;

  @override
  void initState() {
    super.initState();
    _initCamera();
    _compassSubscription = FlutterCompass.events?.listen((event) {
      if (mounted) setState(() => _heading = event.heading ?? 0);
    });
  }

  Future<void> _initCamera() async {
    if (!mounted) return;
    
    try {
      // 1. Check permissions again just to be sure
      // (Though usually handled by caller, sometimes state transitions are weird)
      
      // 2. Get cameras with a small retry if it returns empty initially
      List<CameraDescription> cameras = [];
      for (int i = 0; i < 3; i++) {
        try {
          cameras = await availableCameras();
          if (cameras.isNotEmpty) break;
        } catch (_) {}
        await Future.delayed(Duration(milliseconds: 300 * (i + 1)));
      }

      if (cameras.isEmpty || !mounted) return;
      
      // 3. Initialize controller
      final controller = CameraController(
        cameras[0], 
        ResolutionPreset.medium, 
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg, // More stable for simple previews
      );
      
      _cameraController = controller;
      
      // Important: Add listener to catch errors during or after initialization
      controller.addListener(() {
        if (mounted && controller.value.hasError) {
          debugPrint('Camera error: ${controller.value.errorDescription}');
        }
      });

      await controller.initialize();
      
      if (mounted) {
        setState(() => _isCameraReady = true);
      }
    } catch (e) {
      debugPrint('Error initializing camera: $e');
      // If it fails, we just don't show the camera preview
      if (mounted) {
        setState(() => _isCameraReady = false);
      }
    }
  }

  @override
  void dispose() {
    _compassSubscription?.cancel();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final settings = SettingsService.instance.notifier.value;
    final accentColor = AppTheme.getAccentColor(settings, context);

    // Calculate rotation angle in degrees
    double diffDeg = (widget.qiblaBearing - _heading + 360) % 360;
    if (diffDeg > 180) diffDeg -= 360;
    
    // Is facing Qibla?
    bool isFacing = diffDeg.abs() < 12;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_isCameraReady && _cameraController != null)
            CameraPreview(_cameraController!)
          else
            const Center(child: CircularProgressIndicator(color: Colors.white)),

          // 3D Perspective Directional Indicator
          Center(
            child: AnimatedRotation(
              turns: diffDeg / 360,
              duration: const Duration(milliseconds: 100),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Floor Ring with Perspective
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.002) // depth
                      ..rotateX(1.3), // tilt to floor
                    alignment: Alignment.center,
                    child: Container(
                      width: 320,
                      height: 320,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isFacing ? accentColor : Colors.white24, 
                          width: 3
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: (isFacing ? accentColor : Colors.white).withValues(alpha: 0.2),
                            blurRadius: 40,
                            spreadRadius: 5,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // The "3D" Arrow Model
                  Transform(
                    transform: Matrix4.identity()
                      ..setEntry(3, 2, 0.001)
                      ..rotateX(-0.5), // lean forward slightly
                    alignment: Alignment.center,
                    child: CustomPaint(
                      size: const Size(200, 200),
                      painter: Ar3DArrowPainter(
                        color: isFacing ? accentColor : Colors.white70,
                        angle: 0, // already rotated by AnimatedRotation
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Floating Badge
          if (isFacing)
            Center(
              child: Transform.translate(
                offset: const Offset(0, -180),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(15),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        shape: BoxShape.circle,
                        border: Border.all(color: accentColor, width: 3),
                        boxShadow: [
                          BoxShadow(color: accentColor.withValues(alpha: 0.5), blurRadius: 20)
                        ],
                      ),
                      child: const Icon(Icons.mosque, color: Colors.white, size: 40),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      tr('facing_qibla').toUpperCase(),
                      style: TextStyle(
                        color: accentColor,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                        letterSpacing: 3,
                        shadows: const [Shadow(color: Colors.black, blurRadius: 5)]
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // HUD - Instructions
          Positioned(
            bottom: 60,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(35),
                  border: Border.all(color: isFacing ? accentColor : Colors.white24, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isFacing ? Icons.verified : Icons.sync_problem_rounded,
                      color: isFacing ? accentColor : Colors.white,
                    ),
                    const SizedBox(width: 15),
                    Text(
                      isFacing ? tr('facing_qibla') : tr('turn_to_kaaba'),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Close Button
          Positioned(
            top: 50,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black45,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
          
          Positioned(
            top: 55,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.amber,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Text(
                "3D AR ENGINE", 
                style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 11)
              ),
            ),
          ),
        ],
      ),
    );
  }
}
