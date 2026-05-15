import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/fuzzy_key.dart';
import '../utils/reed_solomon_new.dart';

class FuzzyExtractorService {
  static const int embeddingSize = 512; // Updated for FaceNet-512
  static const int chunkSize = 128;
  static const int paritySize = 127;
  late final ReedSolomon _rs;

  FuzzyExtractorService() {
    _rs = ReedSolomon(dataShards: chunkSize, parityShards: paritySize);
  }

  Future<FuzzyKey> enroll(List<double> embedding) async {
    if (embedding.length != embeddingSize) {
      throw ArgumentError('Embedding должен быть размером $embeddingSize');
    }

    final quantized = Uint8List.fromList(_quantizeEmbedding(embedding));
    
    // Split 512 into 4 chunks and encode each
    final syndromes = <String>[];
    for (int i = 0; i < 4; i++) {
      final chunk = quantized.sublist(i * chunkSize, (i + 1) * chunkSize);
      syndromes.add(base64Encode(_rs.encode(chunk)));
    }
    
    final publicSyndrome = syndromes.join(':');
    final privateKey = _generatePrivateKey(quantized);

    final metadata = EnrollmentMetadata(
      enrollmentTime: DateTime.now(),
      framesCount: 1,
      averageQuality: _calculateEmbeddingQuality(embedding),
      algorithmVersion: 'FuzzyExtractor-RS-512-v1',
    );

    return FuzzyKey(
      publicSyndrome: publicSyndrome,
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
    final newQuantized = Uint8List.fromList(_quantizeEmbedding(newEmbedding));
    final syndromeChunks = publicSyndrome.split(':');

    if (syndromeChunks.length != 4) {
      return VerificationResult(
        success: false, correctedErrors: 0, 
        verificationTimeMs: 0, errorMessage: 'Invalid syndrome format'
      );
    }

    final recoveredQuantized = Uint8List(embeddingSize);
    int totalErrors = 0;
    bool rsFailed = false;
    String failureReason = '';

    try {
      for (int i = 0; i < 4; i++) {
        final parity = base64Decode(syndromeChunks[i]);
        final chunk = newQuantized.sublist(i * chunkSize, (i + 1) * chunkSize);
        
        final codeword = Uint8List(chunkSize + paritySize);
        codeword.setRange(0, chunkSize, chunk);
        codeword.setRange(chunkSize, codeword.length, parity);

        final recovered = _rs.decode(codeword);
        if (recovered == null) {
          rsFailed = true;
          failureReason = 'Chunk $i mismatch';
          break;
        }
        
        recoveredQuantized.setRange(i * chunkSize, (i + 1) * chunkSize, recovered);
        totalErrors += _countDifferences(chunk, recovered);
      }
    } catch (e) {
      rsFailed = true;
      failureReason = e.toString();
    }

    final verificationTimeMs = DateTime.now().difference(startTime).inMilliseconds;

    // Even if RS fails, we want to know the distance for debugging
    // We can't recover the original vector easily, but we can compute distance to what we have
    // For now, let's return a special distance if RS fails, or implement a fallback distance check
    
    if (rsFailed) {
      return VerificationResult(
        success: false,
        recoveredKey: null,
        correctedErrors: -1,
        embeddingDistance: 1.0, // This will be improved once we have helper data
        verificationTimeMs: verificationTimeMs,
        errorMessage: 'Face mismatch: $failureReason',
      );
    }

    final recoveredKey = _generatePrivateKey(recoveredQuantized);
    final distance = _calculateDistance(newEmbedding, recoveredQuantized);

    return VerificationResult(
      success: true,
      recoveredKey: recoveredKey,
      correctedErrors: totalErrors,
      embeddingDistance: distance,
      verificationTimeMs: DateTime.now().difference(startTime).inMilliseconds,
    );
  }

  /// Calculates real Euclidean distance for debugging
  double calculateRawDistance(List<double> e1, List<double> e2) {
    if (e1.length != e2.length) return 1.0;
    double sum = 0;
    for (int i = 0; i < e1.length; i++) {
      double diff = e1[i] - e2[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  List<int> _quantizeEmbedding(List<double> embedding) {
    final result = <int>[];
    for (final value in embedding) {
      // High-precision quantization for L2 vectors
      // FaceNet components are small. We scale them by 5x to use the range better.
      // Range [-0.2, 0.2] maps to [0, 255]
      final scaled = (value * 5.0); 
      final quantized = ((scaled + 1.0) * 127.5).round().clamp(0, 255);
      result.add(quantized);
    }
    return result;
  }

  String _generatePrivateKey(Uint8List quantized) {
    return sha256.convert(quantized).toString();
  }

  double _calculateDistance(List<double> embedding, Uint8List quantized) {
    var sum = 0.0;
    for (var i = 0; i < embedding.length; i++) {
      final dequantized = (quantized[i] / 127.5) - 1.0;
      final diff = embedding[i] - dequantized;
      sum += diff * diff;
    }
    return sqrt(sum);
  }

  double _calculateEmbeddingQuality(List<double> embedding) {
    final mean = embedding.reduce((a, b) => a + b) / embedding.length;
    var variance = 0.0;
    for (final value in embedding) {
      variance += (value - mean) * (value - mean);
    }
    variance /= embedding.length;
    return (sqrt(variance) / 1.0).clamp(0.0, 1.0).toDouble();
  }

  int _countDifferences(Uint8List a, Uint8List b) {
    var count = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) count++;
    }
    return count;
  }
}
