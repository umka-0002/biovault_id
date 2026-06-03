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
    final List<double> embedding = await faceRecognitionService.predict(faceImage);
    return await fuzzyExtractorService.enroll(embedding);
  }

  Future<VerificationResult> verifyFromImage(
    img.Image faceImage,
    String publicSyndrome,
  ) async {
    final List<double> embedding = await faceRecognitionService.predict(faceImage);
    return await fuzzyExtractorService.verify(embedding, publicSyndrome);
  }

  Future<FuzzyKey> enrollFromEmbedding(List<double> embedding) async {
    return await fuzzyExtractorService.enroll(embedding);
  }

  Future<VerificationResult> verifyFromEmbedding(
    List<double> embedding,
    String publicSyndrome,
  ) async {
    return await fuzzyExtractorService.verify(embedding, publicSyndrome);
  }

  void dispose() {
    faceRecognitionService.dispose();
  }
}
