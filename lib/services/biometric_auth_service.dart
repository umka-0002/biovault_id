import 'package:image/image.dart' as img;

import 'face_recognition_service.dart';
import 'fuzzy_extractor_service.dart';
import '../models/fuzzy_key.dart';

class BiometricAuthService {
  final FaceRecognitionService faceRecognitionService;
  final FuzzyExtractorService fuzzyExtractorService;

  BiometricAuthService({
    FaceRecognitionService? faceRecognitionService,
    FuzzyExtractorService? fuzzyExtractorService,
  })  : faceRecognitionService = faceRecognitionService ?? FaceRecognitionService(),
        fuzzyExtractorService = fuzzyExtractorService ?? FuzzyExtractorService();

  Future<void> initialize() async {
    await faceRecognitionService.loadModel();
  }

  Future<FuzzyKey> enrollFromImage(img.Image faceImage) async {
    final embedding = faceRecognitionService.predict(faceImage);
    return fuzzyExtractorService.enroll(embedding);
  }

  Future<VerificationResult> verifyFromImage(
    img.Image faceImage,
    String publicSyndrome,
  ) async {
    final embedding = faceRecognitionService.predict(faceImage);
    return fuzzyExtractorService.verify(embedding, publicSyndrome);
  }

  Future<FuzzyKey> enrollFromEmbedding(List<double> embedding) async {
    return fuzzyExtractorService.enroll(embedding);
  }

  Future<VerificationResult> verifyFromEmbedding(
    List<double> embedding,
    String publicSyndrome,
  ) async {
    return fuzzyExtractorService.verify(embedding, publicSyndrome);
  }

  void dispose() {
    faceRecognitionService.dispose();
  }
}
