import 'dart:io';
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
      ..strokeWidth = 3.0
      ..color = Colors.greenAccent;

    for (final Face face in faces) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          _transformRect(face.boundingBox, size),
          const Radius.circular(12),
        ),
        paint,
      );
    }
  }

  Rect _transformRect(Rect rect, Size size) {
    // 1. Calculate scale factors
    double scaleX, scaleY;
    if (rotation == InputImageRotation.rotation90deg ||
        rotation == InputImageRotation.rotation270deg) {
      scaleX = size.width / absoluteImageSize.height;
      scaleY = size.height / absoluteImageSize.width;
    } else {
      scaleX = size.width / absoluteImageSize.width;
      scaleY = size.height / absoluteImageSize.height;
    }

    // 2. Scale the coordinates
    double left = rect.left * scaleX;
    double top = rect.top * scaleY;
    double right = rect.right * scaleX;
    double bottom = rect.bottom * scaleY;

    // 3. Mirror for front camera (common on Android)
    if (Platform.isAndroid) {
      double flippedLeft = size.width - right;
      double flippedRight = size.width - left;
      left = flippedLeft;
      right = flippedRight;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  @override
  bool shouldRepaint(FaceDetectorPainter oldDelegate) {
    return oldDelegate.absoluteImageSize != absoluteImageSize ||
        oldDelegate.faces != faces;
  }
}
