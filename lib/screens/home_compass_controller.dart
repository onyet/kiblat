import 'dart:async';
import 'dart:math' as math;
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

  /// Provide an optional [source] for easier testing. If omitted, uses LocationService.headingStream().
  CompassHeadingController({Stream<double?>? source})
    : _source = source ?? LocationService.headingStream() {
    
    _sub = _source.listen((val) {
      if (val == null) return;
      
      final smoothed = _last == null ? val : (_last! * 0.8 + val * 0.2);
      
      // Check for stale data: if heading didn't change despite movement
      if (_last != null && (smoothed - _last!).abs() < 0.01) {
        if (_lastAccelMagnitude > 1.5) { // Significant movement
          _staleCounter++;
        }
      } else {
        _staleCounter = 0;
        if (_isStale) {
          _isStale = false;
          _staleOut.add(false);
        }
      }

      if (_staleCounter > 50) { // Approx 5 seconds of no change while moving
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
      // Using userAccelerometerEvents would be better but it might not be available on all devices.
      // Let's use simple magnitude change.
      double mag = math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      _lastAccelMagnitude = (mag - 9.8).abs();
    });
  }

  void dispose() {
    _sub?.cancel();
    _accelSub?.cancel();
    _out.close();
    _staleOut.close();
  }
}
