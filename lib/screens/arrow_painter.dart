import 'package:flutter/material.dart';

class ArrowPainter extends CustomPainter {
  final Color color;
  const ArrowPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path();
    // triangle head
    path.moveTo(size.width / 2, 0);
    path.lineTo(0, size.height * 0.7);
    path.lineTo(size.width, size.height * 0.7);
    path.close();
    canvas.drawPath(path, paint);

    // small inner cut for a bit of style
    final innerPaint = Paint()..color = const Color.fromARGB(31, 0, 0, 0);
    final inner = Path();
    inner.moveTo(size.width / 2, size.height * 0.12);
    inner.lineTo(size.width * 0.16, size.height * 0.64);
    inner.lineTo(size.width * 0.84, size.height * 0.64);
    inner.close();
    canvas.drawPath(inner, innerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
