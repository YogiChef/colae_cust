import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class QRScannerOverlay extends StatelessWidget {
  const QRScannerOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: QRScannerOverlayPainter(), child: Container());
  }
}

class QRScannerOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final double scanAreaRatio = 0.7;
    final double scanAreaSize = size.width * scanAreaRatio;
    final double left = (size.width - scanAreaSize) / 2;
    final double top = (size.height - scanAreaSize) / 2;

    final double cornerLength = 40;
    final double cornerThickness = 2;
    final double cornerRadius = 7;

    final Paint paint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = cornerThickness
      ..style = PaintingStyle.stroke;

    Path pathTL = Path();
    pathTL.moveTo(left + cornerLength, top);
    pathTL.lineTo(left + cornerRadius, top);
    pathTL.arcToPoint(
      Offset(left, top + cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );
    pathTL.lineTo(left, top + cornerLength);
    canvas.drawPath(pathTL, paint);

    Path pathTR = Path();
    pathTR.moveTo(left + scanAreaSize - cornerLength, top);
    pathTR.lineTo(left + scanAreaSize - cornerRadius, top);
    pathTR.arcToPoint(
      Offset(left + scanAreaSize, top + cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );
    pathTR.lineTo(left + scanAreaSize, top + cornerLength);
    canvas.drawPath(pathTR, paint);

    Path pathBL = Path();
    pathBL.moveTo(left + cornerLength, top + scanAreaSize);
    pathBL.lineTo(left + cornerRadius, top + scanAreaSize);
    pathBL.arcToPoint(
      Offset(left, top + scanAreaSize - cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: true,
    );
    pathBL.lineTo(left, top + scanAreaSize - cornerLength);
    canvas.drawPath(pathBL, paint);

    Path pathBR = Path();
    pathBR.moveTo(left + scanAreaSize - cornerLength, top + scanAreaSize);
    pathBR.lineTo(left + scanAreaSize - cornerRadius, top + scanAreaSize);
    pathBR.arcToPoint(
      Offset(left + scanAreaSize, top + scanAreaSize - cornerRadius),
      radius: Radius.circular(cornerRadius),
      clockwise: false,
    );
    pathBR.lineTo(left + scanAreaSize, top + scanAreaSize - cornerLength);
    canvas.drawPath(pathBR, paint);

    final Paint linePaint = Paint()
      ..color = Colors.redAccent
      ..strokeWidth = 2;
    final double middleX = size.width / 2;
    final double topOffset = 20.h;
    final double bottomOffset = 20.h;
    canvas.drawLine(
      Offset(middleX, topOffset),
      Offset(middleX, size.height - bottomOffset),
      linePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
