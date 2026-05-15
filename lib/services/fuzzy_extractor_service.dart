import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/fuzzy_key.dart';
import '../utils/reed_solomon.dart';

class FuzzyExtractorService {
  static const int embeddingSize = 128;
  static const int paritySize = 127;
  static const double _maxDistanceForVerification = 12.0;

  final ReedSolomon _reedSolomon =
      ReedSolomon(dataShards: embeddingSize, parityShards: paritySize);

  Future<FuzzyKey> enroll(List<double> embedding) async {
    if (embedding.length != embeddingSize) {
      throw ArgumentError('Embedding должен быть размером $embeddingSize');
    }

    final quantized = _quantizeEmbedding(embedding);
    final syndrome = _buildSyndrome(quantized);
    final privateKey = _buildPrivateKey(quantized);
    final metadata = EnrollmentMetadata(
      enrollmentTime: DateTime.now(),
      framesCount: 1,
      averageQuality: _calculateEmbeddingQuality(embedding),
      algorithmVersion: 'ReedSolomon-v1',
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
    if (newEmbedding.length != embeddingSize) {
      throw ArgumentError('Embedding должен быть размером $embeddingSize');
    }

    final startTime = DateTime.now();
    final quantized = _quantizeEmbedding(newEmbedding);
    final parityBytes = _decodeSyndrome(publicSyndrome);
    final codeword = <int>[...quantized]..addAll(parityBytes);

    int correctedErrors = 0;
    List<int> recoveredMessage;
    try {
      recoveredMessage = _reedSolomon.decode(codeword);
      correctedErrors = _estimateErrorCount(quantized, recoveredMessage);
    } catch (error) {
      return VerificationResult(
        success: false,
        correctedErrors: 0,
        embeddingDistance: _calculateEmbeddingDistance(newEmbedding, quantized),
        verificationTimeMs:
            DateTime.now().difference(startTime).inMilliseconds,
        errorMessage: 'Не удалось восстановить embedding: $error',
      );
    }

    final recoveredKey = _buildPrivateKey(recoveredMessage);
    final distance = _calculateEmbeddingDistance(newEmbedding, recoveredMessage);
    final verificationTimeMs = DateTime.now().difference(startTime).inMilliseconds;

    return VerificationResult(
      success: true,
      recoveredKey: recoveredKey,
      correctedErrors: correctedErrors,
      embeddingDistance: distance,
      verificationTimeMs: verificationTimeMs,
    );
  }

  String _buildSyndrome(List<int> quantized) {
    return base64Encode(Uint8List.fromList(_reedSolomon.encode(quantized)));
  }

  List<int> _decodeSyndrome(String syndrome) {
    return base64Decode(syndrome);
  }

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
