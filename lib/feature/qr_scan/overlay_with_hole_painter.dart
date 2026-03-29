import 'package:collector_app/common/app/theme.dart';
import 'package:flutter/material.dart';

class OverlayWithHolePainter extends CustomPainter {
  final double holeSize;
  final Color overlayColor;
  final double cornerRadius;

  OverlayWithHolePainter({
    required this.holeSize,
    Color? overlayColor,
    this.cornerRadius = 15,
  }) : overlayColor =
            overlayColor ?? CustomTheme.appThemeColorPrimary.withOpacity(.3);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = overlayColor;
    final centerX = size.width / 2;
    final centerY = size.height / 2;
    final halfHole = holeSize / 2;

    final holeRect = Rect.fromLTRB(centerX - halfHole, centerY - halfHole,
        centerX + halfHole, centerY + halfHole);

    final holePath = Path()
      ..addRRect(
          RRect.fromRectAndRadius(holeRect, Radius.circular(cornerRadius)));

    final fullPath = Path()
      ..addRect(Rect.fromLTWH(0, 0, size.width, size.height));

    final overlayPath =
        Path.combine(PathOperation.difference, fullPath, holePath);
    canvas.drawPath(overlayPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
