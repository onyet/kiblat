import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:kiblat/screens/home_compass_controller.dart';

void main() {
  test('CompassHeadingController smoothing', () async {
    final source = StreamController<double?>();
    final controller = CompassHeadingController(source: source.stream);

    final results = <double>[];
    final sub = controller.smoothedStream.listen((v) => results.add(v));

    // emit values
    source.add(10.0);
    source.add(20.0);
    source.add(30.0);
    await source.close();

    // Wait a tick for events to be processed
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(results.length, 3);
    expect(results[0], closeTo(10.0, 1e-9));
    expect(results[1], closeTo(12.0, 1e-9));
    expect(results[2], closeTo(15.6, 1e-9));

    await sub.cancel();
    controller.dispose();
  });
}
