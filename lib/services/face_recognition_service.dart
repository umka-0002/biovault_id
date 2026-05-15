import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class FaceRecognitionService {
  Interpreter? _interpreter;

  // Инициализация модели
  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      if (Platform.isAndroid) {
        options.addDelegate(XNNPackDelegate()); 
      }

      _interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
        options: options,
      );
      debugPrint("Модель FaceNet успешно загружена");
    } catch (e) {
      debugPrint("Ошибка при загрузке модели: $e");
    }
  }

  // Превращаем картинку в 512-мерный вектор (Embedding)
  List<double> predict(img.Image faceImage) {
    if (_interpreter == null) throw Exception("Модель не инициализирована");

    // 1. Resize to model input size
    img.Image resizedImage = img.copyResize(faceImage, width: 160, height: 160);
    
    // 2. Optimized 4D Input buffer [1, 160, 160, 3] as Float32List
    // Using Float32List is MUCH faster and memory-efficient than nested lists
    final input = Float32List(1 * 160 * 160 * 3);
    int index = 0;
    for (int y = 0; y < 160; y++) {
      for (int x = 0; x < 160; x++) {
        final pixel = resizedImage.getPixel(x, y);
        input[index++] = (pixel.r - 127.5) / 128.0;
        input[index++] = (pixel.g - 127.5) / 128.0;
        input[index++] = (pixel.b - 127.5) / 128.0;
      }
    }

    // 3. Prepare output buffer
    final output = Float32List(1 * 512).reshape([1, 512]);

    // 4. Run inference
    _interpreter!.run(input.reshape([1, 160, 160, 3]), output);

    // 5. L2 Normalization (CRITICAL for FaceNet accuracy)
    final embedding = List<double>.from(output[0]);
    return l2Normalize(embedding);
  }

  List<double> l2Normalize(List<double> vector) {
    double sum = 0;
    for (var v in vector) {
      sum += v * v;
    }
    double norm = sqrt(sum);
    if (norm < 1e-6) return vector; // Avoid division by zero
    return vector.map((v) => v / norm).toList();
  }

  /// Crops a face from a CameraImage based on ML Kit Face bounding box
  img.Image? cropFace(CameraImage image, Face face, int sensorOrientation) {
    try {
      final img.Image? rawImage = _convertCameraImage(image);
      if (rawImage == null) return null;

      // 1. Rotate the image to upright position based on sensor orientation
      // On most Androids, front camera is 270 degrees
      img.Image uprightImage = img.copyRotate(rawImage, angle: sensorOrientation);

      // 2. Transpose bounding box to rotated coordinates
      // For 270 degrees rotation: (x,y) of box needs to be mapped to rotated space
      // BUT simpler way: crop from raw and then rotate the crop.
      
      final Rect box = face.boundingBox;
      final int x = box.left.toInt().clamp(0, rawImage.width - 1);
      final int y = box.top.toInt().clamp(0, rawImage.height - 1);
      final int w = box.width.toInt().clamp(1, rawImage.width - x);
      final int h = box.height.toInt().clamp(1, rawImage.height - y);
      
      img.Image faceCrop = img.copyCrop(
        rawImage,
        x: x,
        y: y,
        width: w,
        height: h,
      );

      // Now rotate the crop to be upright
      return img.copyRotate(faceCrop, angle: sensorOrientation);
    } catch (e) {
      debugPrint("Error cropping face: $e");
      return null;
    }
  }

  /// Converts CameraImage (YUV420) to img.Image (RGB) with proper plane handling
  img.Image? _convertCameraImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final imgImage = img.Image(width: width, height: height);

      // Fast YUV to RGB
      final planeY = image.planes[0].bytes;
      final planeU = image.planes[1].bytes;
      final planeV = image.planes[2].bytes;

      final int uvRowStride = image.planes[1].bytesPerRow;
      final int uvPixelStride = image.planes[1].bytesPerPixel ?? 1;

      for (int y = 0; y < height; y++) {
        for (int x = 0; x < width; x++) {
          final int uvIndex = (y ~/ 2) * uvRowStride + (x ~/ 2) * uvPixelStride;
          
          final int yValue = planeY[y * width + x];
          final int uValue = planeU[uvIndex];
          final int vValue = planeV[uvIndex];

          final int r = (yValue + 1.370705 * (vValue - 128)).toInt().clamp(0, 255);
          final int g = (yValue - 0.337633 * (uValue - 128) - 0.698001 * (vValue - 128)).toInt().clamp(0, 255);
          final int b = (yValue + 1.732446 * (uValue - 128)).toInt().clamp(0, 255);

          imgImage.setPixelRgb(x, y, r, g, b);
        }
      }
      return imgImage;
    } catch (e) {
      debugPrint("Error converting camera image: $e");
      return null;
    }
  }

  void dispose() {
    _interpreter?.close();
  }
}
