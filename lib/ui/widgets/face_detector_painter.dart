import 'package:flutter/material.dart';
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';

class FaceDetectorPainter extends CustomPainter {
  FaceDetectorPainter(this.faces, this.absoluteImageSize, this.rotation);

  final List<Face> faces;
  final Size absoluteImageSize;
  final InputImageRotation rotation;

  @override
  void paint(Canvas canvas, Size size) {
    final Paint paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0
      ..color = Colors.green;

    for (final Face face in faces) {
      canvas.drawRect(
        _translateX(face.boundingBox, rotation, size, absoluteImageSize),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }

  Rect _translateX(
    Rect rect,
    InputImageRotation rotation,
    Size size,
    Size absoluteImageSize,
  ) {
    double x, y, width, height;

    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      x = rect.left * size.width / absoluteImageSize.height;
      y = rect.top * size.height / absoluteImageSize.width;
      width = rect.width * size.width / absoluteImageSize.height;
      height = rect.height * size.height / absoluteImageSize.width;
    } else {
      x = rect.left * size.width / absoluteImageSize.width;
      y = rect.top * size.height / absoluteImageSize.height;
      width = rect.width * size.width / absoluteImageSize.width;
      height = rect.height * size.height / absoluteImageSize.height;
    }

    return Rect.fromLTWH(x, y, width, height);
  }
}
