import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../models/fuzzy_key.dart';
import '../utils/reed_solomon_new.dart';

class FuzzyExtractorService {
  static const int embeddingSize = 512; 
  static const int dataShards = 64;   // 512 bits = 64 bytes
  static const int parityShards = 80;  // Corrects up to 40 byte errors
  late final ReedSolomon _rs;

  FuzzyExtractorService() {
    _rs = ReedSolomon(dataShards: dataShards, parityShards: parityShards);
  }

  Future<FuzzyKey> enroll(List<double> embedding) async {
    if (embedding.length != embeddingSize) {
      throw ArgumentError('Embedding должен быть размером $embeddingSize');
    }

    final binarized = _binarizeEmbedding(embedding);
    
    final syndrome = base64Encode(_rs.encode(binarized));
    final privateKey = _generatePrivateKey(binarized);

    final metadata = EnrollmentMetadata(
      enrollmentTime: DateTime.now(),
      framesCount: 1,
      averageQuality: 0.0,
      algorithmVersion: 'FuzzyExtractor-SignBinarization-RS255-v1',
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
    final newBinarized = _binarizeEmbedding(newEmbedding);
    final parity = base64Decode(publicSyndrome);

    if (parity.length != parityShards) {
       return VerificationResult(
        success: false, correctedErrors: 0, 
        verificationTimeMs: 0, errorMessage: 'Invalid syndrome length'
      );
    }

    final codeword = Uint8List(dataShards + parityShards);
    codeword.setRange(0, dataShards, newBinarized);
    codeword.setRange(dataShards, codeword.length, parity);

    final recovered = _rs.decode(codeword);
    final verificationTimeMs = DateTime.now().difference(startTime).inMilliseconds;

    if (recovered == null) {
      // If RS fails, we still want to report the Hamming distance for debugging
      // (though it's harder to compute "distance" in embedding space from bits easily without bits->embedding)
      // Actually, we can just return distance to newEmbedding if we had the original bits.
      return VerificationResult(
        success: false,
        recoveredKey: null,
        correctedErrors: -1,
        embeddingDistance: double.nan,
        verificationTimeMs: verificationTimeMs,
        errorMessage: 'Face mismatch (Too much noise). Please use better lighting.',
      );
    }

    final recoveredKey = _generatePrivateKey(recovered);
    final errors = _countDifferences(newBinarized, recovered);
    
    // We don't have the original float embedding, but we can return the bit-error count as a metric
    final bitDistance = errors / (dataShards * 8);

    return VerificationResult(
      success: true,
      recoveredKey: recoveredKey,
      correctedErrors: errors,
      embeddingDistance: bitDistance,
      verificationTimeMs: verificationTimeMs,
    );
  }

  Uint8List _binarizeEmbedding(List<double> embedding) {
    final result = Uint8List(dataShards);
    for (int i = 0; i < embeddingSize; i++) {
      if (embedding[i] > 0) {
        final byteIdx = i >> 3;
        final bitIdx = i & 7;
        result[byteIdx] |= (1 << bitIdx);
      }
    }
    return result;
  }

  String _generatePrivateKey(Uint8List bits) {
    return sha256.convert(bits).toString();
  }

  int _countDifferences(Uint8List a, Uint8List b) {
    var count = 0;
    for (var i = 0; i < a.length && i < b.length; i++) {
      if (a[i] != b[i]) {
        // Count bits
        int xor = a[i] ^ b[i];
        while (xor > 0) {
          if (xor & 1 == 1) count++;
          xor >>= 1;
        }
      }
    }
    return count;
  }

  /// Calculates component-wise median of multiple embeddings
  static List<double> medianEmbedding(List<List<double>> embeddings) {
    if (embeddings.isEmpty) return List.filled(embeddingSize, 0.0);
    
    final result = List<double>.filled(embeddingSize, 0.0);
    for (int i = 0; i < embeddingSize; i++) {
      final components = embeddings.map((e) => e[i]).toList()..sort();
      result[i] = components[components.length ~/ 2];
    }
    return result;
  }
}
