import 'dart:async';

import '../services/location_service.dart';

/// Controls compass heading stream and applies simple low-pass smoothing.
///
/// The smoothing used is exponential-like: smoothed = last==null ? val : last*0.8 + val*0.2
class CompassHeadingController {
  final Stream<double?> _source;
  final StreamController<double> _out = StreamController.broadcast();
  Stream<double> get smoothedStream => _out.stream;

  StreamSubscription<double?>? _sub;
  double? _last;

  /// Provide an optional [source] for easier testing. If omitted, uses LocationService.headingStream().
  CompassHeadingController({Stream<double?>? source})
    : _source = source ?? LocationService.headingStream() {
    _sub = _source.listen((val) {
      if (val == null) return;
      final smoothed = _last == null ? val : (_last! * 0.8 + val * 0.2);
      _last = smoothed;
      if (!_out.isClosed) _out.add(smoothed);
    });
  }

  void dispose() {
    _sub?.cancel();
    _out.close();
  }
}
