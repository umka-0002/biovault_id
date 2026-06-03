import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_mlkit_face_detection/google_mlkit_face_detection.dart';
import 'package:camera/camera.dart';

class FaceRecognitionService {
  Uint8List? _modelBuffer;

  Future<void> loadModel() async {
    try {
      _modelBuffer = (await rootBundle.load('assets/models/facenet.tflite')).buffer.asUint8List();
      debugPrint("Модель FaceNet успешно загружена в буфер");
    } catch (e) {
      debugPrint("Ошибка при загрузке модели: $e");
    }
  }

  // Превращаем картинку в 512-мерный вектор (Embedding)
  Future<List<double>> predict(img.Image faceImage) async {
    if (_modelBuffer == null) throw Exception("Модель не загружена");

    // We offload the image processing and inference to a background isolate
    // to keep the UI thread responsive.
    return await foundation.compute(_inferenceTask, {
      'faceImage': faceImage,
      'modelBuffer': _modelBuffer!,
    });
  }

  static Future<List<double>> _inferenceTask(Map<String, dynamic> params) async {
    final img.Image faceImage = params['faceImage'];
    final Uint8List modelBuffer = params['modelBuffer'];

    final options = InterpreterOptions();
    if (Platform.isAndroid) {
      options.addDelegate(XNNPackDelegate());
    }

    final interpreter = Interpreter.fromBuffer(
      modelBuffer,
      options: options,
    );

    try {
      // 1. Resize to model input size
      img.Image resizedImage = img.copyResize(faceImage, width: 160, height: 160);
      
      // 2. Prepare Input buffer
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
      interpreter.run(input.reshape([1, 160, 160, 3]), output);

      // 5. L2 Normalization
      final embedding = List<double>.from(output[0]);
      return _staticL2Normalize(embedding);
    } finally {
      interpreter.close();
    }
  }

  static List<double> _staticL2Normalize(List<double> vector) {
    double sum = 0;
    for (var v in vector) {
      sum += v * v;
    }
    double norm = sqrt(sum);
    if (norm < 1e-6) return vector;
    return vector.map((v) => v / norm).toList();
  }

  /// Estimates image quality using Laplacian variance (blur detection)
  /// Higher value means sharper image.
  Future<double> estimateQualityAsync(img.Image faceImage) async {
    return await foundation.compute(_qualityTask, faceImage);
  }

  static double _qualityTask(img.Image faceImage) {
    // 1. Grayscale
    final grayscale = img.grayscale(faceImage);
    
    // 2. Laplacian kernel
    final kernel = [
      0.0,  1.0, 0.0,
      1.0, -4.0, 1.0,
      0.0,  1.0, 0.0
    ];
    
    // 3. Convolution
    final laplacian = img.convolution(grayscale, filter: kernel);
    
    // 4. Calculate variance of Laplacian
    double mean = 0.0;
    int count = 0;
    for (final pixel in laplacian) {
      mean += (pixel.r + pixel.g + pixel.b) / 3.0; // Average of channels
      count++;
    }
    mean /= count;
    
    double variance = 0.0;
    for (final pixel in laplacian) {
      double val = (pixel.r + pixel.g + pixel.b) / 3.0;
      double diff = val - mean;
      variance += diff * diff;
    }
    variance /= count;
    
    return variance;
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
  Future<img.Image?> cropFaceAsync(CameraImage image, Face face, int sensorOrientation) async {
    return await foundation.compute(_cropTask, {
      'image': image,
      'face': face,
      'orientation': sensorOrientation,
    });
  }

  static img.Image? _cropTask(Map<String, dynamic> params) {
    final CameraImage image = params['image'];
    final Face face = params['face'];
    final int sensorOrientation = params['orientation'];

    try {
      final img.Image? rawImage = _staticConvertCameraImage(image);
      if (rawImage == null) return null;

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

      return img.copyRotate(faceCrop, angle: sensorOrientation);
    } catch (e) {
      return null;
    }
  }

  static img.Image? _staticConvertCameraImage(CameraImage image) {
    try {
      final int width = image.width;
      final int height = image.height;
      final imgImage = img.Image(width: width, height: height);

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
      return null;
    }
  }

  void dispose() {
    // No specific interpreter to close anymore since they are created/closed in isolates
  }
}
