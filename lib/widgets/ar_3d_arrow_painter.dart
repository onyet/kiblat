import 'package:flutter/material.dart';

/// A custom painter that renders a pseudo-3D directional arrow.
class Ar3DArrowPainter extends CustomPainter {
  final Color color;
  final double angle; // angle in radians

  Ar3DArrowPainter({required this.color, required this.angle});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width * 0.4;

    // Create a perspective transform effect
    // We draw an arrow head that looks like it's pointing into or out of the screen
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    // Shadow for depth
    final shadowPath = Path();
    shadowPath.moveTo(0, -radius);
    shadowPath.lineTo(-radius * 0.5, radius * 0.2);
    shadowPath.lineTo(radius * 0.5, radius * 0.2);
    shadowPath.close();
    canvas.drawPath(shadowPath, shadowPaint);

    // Main Arrow Body (3D look with gradient)
    final path = Path();
    path.moveTo(0, -radius); // Tip
    path.lineTo(-radius * 0.4, radius * 0.3); // Bottom Left
    path.lineTo(0, radius * 0.1); // Inner indent
    path.lineTo(radius * 0.4, radius * 0.3); // Bottom Right
    path.close();

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        color,
        color.withValues(alpha: 0.7),
      ],
    );

    paint.shader = gradient.createShader(Rect.fromLTWH(-radius, -radius, radius * 2, radius * 2));
    canvas.drawPath(path, paint);

    // Side faces for 3D extrusion effect
    final leftFace = Path();
    leftFace.moveTo(0, -radius);
    leftFace.lineTo(-radius * 0.4, radius * 0.3);
    leftFace.lineTo(-radius * 0.45, radius * 0.35); // Extrusion
    leftFace.lineTo(0, -radius - 5);
    leftFace.close();
    canvas.drawPath(leftFace, Paint()..color = color.withValues(alpha: 0.5));

    final rightFace = Path();
    rightFace.moveTo(0, -radius);
    rightFace.lineTo(radius * 0.4, radius * 0.3);
    rightFace.lineTo(radius * 0.45, radius * 0.35); // Extrusion
    rightFace.lineTo(0, -radius - 5);
    rightFace.close();
    canvas.drawPath(rightFace, Paint()..color = color.withValues(alpha: 0.5));

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant Ar3DArrowPainter oldDelegate) {
    return oldDelegate.color != color || oldDelegate.angle != angle;
  }
}
