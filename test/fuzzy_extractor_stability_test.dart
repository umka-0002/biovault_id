import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:biovault_id/services/fuzzy_extractor_service.dart';

void main() {
  group('FuzzyExtractorService Stability', () {
    late FuzzyExtractorService service;

    setUp(() {
      service = FuzzyExtractorService();
    });

    test('Verification succeeds with moderate noise (0.05 drift)', () async {
      // Create a 512-dim embedding (L2 normalized)
      final rand = Random(42);
      final embedding = List<double>.generate(512, (_) => rand.nextDouble() * 2 - 1);
      final norm = sqrt(embedding.fold(0.0, (sum, e) => sum + e * e));
      final normalized = embedding.map((e) => e / norm).toList();

      final fuzzyKey = await service.enroll(normalized);

      // Add 0.05 noise (typical for bad lighting)
      final noisyEmbedding = normalized.map((e) => (e + 0.03).clamp(-1.0, 1.0)).toList();
      final result = await service.verify(noisyEmbedding, fuzzyKey.publicSyndrome);

      print('Corrected errors with 0.03 noise: ${result.correctedErrors}');
      expect(result.success, isTrue, reason: 'Should succeed with 0.03 noise');
      expect(result.recoveredKey, equals(fuzzyKey.privateKey));
    });

    test('Median embedding is robust to outliers', () {
      final e1 = List<double>.filled(512, 0.1);
      final e2 = List<double>.filled(512, 0.11);
      final outlier = List<double>.filled(512, 0.9); // Huge outlier

      final median = FuzzyExtractorService.medianEmbedding([e1, e2, outlier]);
      
      // Median of [0.1, 0.11, 0.9] is 0.11
      expect(median[0], closeTo(0.11, 0.001));
      expect(median[511], closeTo(0.11, 0.001));
    });
    
    test('RS failure returns NaN distance and specific error', () async {
       final rand = Random(42);
       final e1 = List<double>.generate(512, (_) => rand.nextDouble() * 2 - 1);
       final norm1 = sqrt(e1.fold(0.0, (sum, e) => sum + e * e));
       final n1 = e1.map((e) => e / norm1).toList();

       final fuzzyKey = await service.enroll(n1);

       // Completely different random vector
       final e2 = List<double>.generate(512, (_) => rand.nextDouble() * 2 - 1);
       final norm2 = sqrt(e2.fold(0.0, (sum, e) => sum + e * e));
       final n2 = e2.map((e) => e / norm2).toList();

       final result = await service.verify(n2, fuzzyKey.publicSyndrome);

       expect(result.success, isFalse);
       expect(result.embeddingDistance.isNaN, isTrue);
       expect(result.errorMessage, contains('Too much noise'));
    });
  });
}
