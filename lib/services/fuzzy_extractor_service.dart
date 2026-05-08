import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

import '../models/fuzzy_key.dart';

class FuzzyExtractorService {
  static const int EMBEDDING_SIZE = 128;
  static const double _maxDistanceForVerification = 5.0;

  Future<FuzzyKey> enroll(List<double> embedding) async {
    if (embedding.length != EMBEDDING_SIZE) {
      throw ArgumentError('Embedding должен быть размером $EMBEDDING_SIZE');
    }

    final quantized = _quantizeEmbedding(embedding);
    final syndrome = _buildSyndrome(quantized);
    final privateKey = _buildPrivateKey(quantized);
    final metadata = EnrollmentMetadata(
      enrollmentTime: DateTime.now(),
      framesCount: 1,
      averageQuality: _calculateEmbeddingQuality(embedding),
    );

    return FuzzyKey(
      publicSyndrome: syndrome,
      privateKey: privateKey,
      enrollmentTime: metadata.enrollmentTime,
      metadata: metadata,
    );
  }

  Future<VerificationResult> verify(
    List<double> newEmbedding,
    String publicSyndrome,
  ) async {
    if (newEmbedding.length != EMBEDDING_SIZE) {
      throw ArgumentError('Embedding должен быть размером $EMBEDDING_SIZE');
    }

    final startTime = DateTime.now();
    final quantized = _quantizeEmbedding(newEmbedding);
    final originalQuantized = publicSyndrome.split(',').map(int.parse).toList();
    final embeddingDistance =
        _calculateEmbeddingDistance(newEmbedding, originalQuantized);
    final verificationTimeMs =
        DateTime.now().difference(startTime).inMilliseconds;

    if (embeddingDistance > _maxDistanceForVerification) {
      return VerificationResult(
        success: false,
        correctedErrors: 0,
        embeddingDistance: embeddingDistance,
        verificationTimeMs: verificationTimeMs,
        errorMessage:
            'Лицо не распознано: расстояние между embeddings слишком велико ($embeddingDistance > $_maxDistanceForVerification)',
      );
    }

    final recoveredKey = _buildPrivateKey(originalQuantized);
    final correctedErrors = (_estimateErrorCount(quantized, originalQuantized));

    return VerificationResult(
      success: true,
      recoveredKey: recoveredKey,
      correctedErrors: correctedErrors,
      embeddingDistance: embeddingDistance,
      verificationTimeMs: verificationTimeMs,
    );
  }

  String _buildSyndrome(List<int> quantized) => quantized.join(',');

  String _buildPrivateKey(List<int> quantized) {
    final bytes = utf8.encode(quantized.join(','));
    return sha256.convert(bytes).toString();
  }

  List<int> _quantizeEmbedding(List<double> embedding) {
    final result = <int>[];
    for (final value in embedding) {
      final quantized = ((value + 1.0) * 127.5).round().clamp(0, 255);
      result.add(quantized);
    }
    return result;
  }

  List<double> _dequantizeEmbedding(List<int> quantized) {
    return quantized
        .map((value) => (value / 127.5) - 1.0)
        .toList(growable: false);
  }

  double _calculateEmbeddingDistance(
    List<double> embedding,
    List<int> quantized,
  ) {
    final dequantized = _dequantizeEmbedding(quantized);
    var sum = 0.0;
    for (var i = 0; i < embedding.length; i++) {
      final diff = embedding[i] - dequantized[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  double _calculateEmbeddingQuality(List<double> embedding) {
    final mean = embedding.reduce((a, b) => a + b) / embedding.length;
    final variance = embedding
            .map((value) => pow(value - mean, 2))
            .reduce((a, b) => a + b) /
        embedding.length;
    final stdDev = sqrt(variance);
    return (stdDev / 1.0).clamp(0.0, 1.0).toDouble();
  }

  int _estimateErrorCount(List<int> a, List<int> b) {
    var count = 0;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) count++;
    }
    return count;
  }
}
