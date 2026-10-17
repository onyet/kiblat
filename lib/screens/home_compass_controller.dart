import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../services/location_service.dart';

/// Controls compass heading stream and applies simple low-pass smoothing.
/// Also detects if the sensor data is "stale" using accelerometer data.
class CompassHeadingController {
  final Stream<double?> _source;
  final StreamController<double> _out = StreamController.broadcast();
  final StreamController<bool> _staleOut = StreamController.broadcast();

  Stream<double> get smoothedStream => _out.stream;
  Stream<bool> get staleStream => _staleOut.stream;

  StreamSubscription<double?>? _sub;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  double? _last;

  double _lastAccelMagnitude = 0;
  int _staleCounter = 0;
  bool _isStale = false;

  static double _normalizeHeading(double heading) =>
      (heading % 360 + 360) % 360;

  static double _shortestHeadingDelta(double from, double to) =>
      (to - from + 540) % 360 - 180;

  /// Provide an optional [source] for easier testing. If omitted, uses LocationService.headingStream().
  CompassHeadingController({Stream<double?>? source})
    : _source = source ?? LocationService.headingStream() {
    resume();
  }

  void resume() {
    if (_sub != null) return;
    debugPrint('[CompassHeadingController] Resuming sensors');

    _sub = _source.listen((val) {
      if (val == null) return;

      final heading = _normalizeHeading(val);
      final smoothed = _last == null
          ? heading
          : _normalizeHeading(
              _last! + _shortestHeadingDelta(_last!, heading) * 0.2,
            );

      // Check for stale data: if heading didn't change despite movement
      if (_last != null &&
          _shortestHeadingDelta(_last!, smoothed).abs() < 0.01) {
        if (_lastAccelMagnitude > 1.5) {
          // Significant movement
          _staleCounter++;
        }
      } else {
        _staleCounter = 0;
        if (_isStale) {
          _isStale = false;
          _staleOut.add(false);
        }
      }

      if (_staleCounter > 50) {
        // Approx 5 seconds of no change while moving
        if (!_isStale) {
          _isStale = true;
          _staleOut.add(true);
        }
      }

      _last = smoothed;
      if (!_out.isClosed) _out.add(smoothed);
    });

    _accelSub = accelerometerEventStream().listen((event) {
      // Calculate magnitude of movement (excluding gravity which is approx 9.8)
      double mag = math.sqrt(
        event.x * event.x + event.y * event.y + event.z * event.z,
      );
      _lastAccelMagnitude = (mag - 9.8).abs();
    });
  }

  void pause() {
    debugPrint('[CompassHeadingController] Pausing sensors');
    _sub?.cancel();
    _accelSub?.cancel();
    _sub = null;
    _accelSub = null;
  }

  void dispose() {
    pause();
    _out.close();
    _staleOut.close();
  }
}
