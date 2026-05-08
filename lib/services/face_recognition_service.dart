import 'dart:io';
import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

class FaceRecognitionService {
  Interpreter? _interpreter;

  // Инициализация модели
  Future<void> loadModel() async {
    try {
      // Настройки для ускорения на мобильных процессорах (NPU/GPU)
      final options = InterpreterOptions();
      if (Platform.isAndroid) {
        options.addDelegate(XNNPackDelegate()); 
      }

      _interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
        options: options,
      );
      print("Модель FaceNet успешно загружена");
    } catch (e) {
      print("Ошибка при загрузке модели: $e");
    }
  }

  // Превращаем картинку в 128/512-мерный вектор (Embedding)
  List<double> predict(img.Image faceImage) {
    if (_interpreter == null) throw Exception("Модель не инициализирована");

    // 1. Предобработка: меняем размер под вход модели (обычно 160x160 для FaceNet)
    img.Image resizedImage = img.copyResize(faceImage, width: 160, height: 160);
    
    // 2. Конвертируем в тензор (Float32) и нормализуем пиксели
    var input = _imageToByteListFloat32(resizedImage);

    // 3. Готовим буфер для вывода (output)
    // Если твоя модель FaceNet-512, замени 128 на 512
    var output = List.filled(1 * 128, 0.0).reshape([1, 128]);

    // 4. Запускаем нейросеть
    _interpreter!.run(input, output);

    // Возвращаем чистый вектор
    return List<double>.from(output[0]);
  }

  // Вспомогательная функция для обработки байтов изображения
  Uint8List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * 160 * 160 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    int pixelIndex = 0;
    for (var i = 0; i < 160; i++) {
      for (var j = 0; j < 160; j++) {
        var pixel = image.getPixel(j, i);
        // Нормализация: (pixel - 127.5) / 128.0
        buffer[pixelIndex++] = (img.getRed(pixel) - 127.5) / 128.0;
        buffer[pixelIndex++] = (img.getGreen(pixel) - 127.5) / 128.0;
        buffer[pixelIndex++] = (img.getBlue(pixel) - 127.5) / 128.0;
      }
    }
    return convertedBytes.buffer.asUint8List();
  }

  void dispose() {
    _interpreter?.close();
  }
}