import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:biovault_id/services/fuzzy_extractor_service.dart';

void main() {
  group('FuzzyExtractorService Binarization Stability', () {
    late FuzzyExtractorService service;

    setUp(() {
      service = FuzzyExtractorService();
    });

    test('Verification succeeds with moderate bit flips (30 bits)', () async {
      final rand = Random(42);
      final normalized = List.generate(512, (_) => rand.nextDouble() * 2 - 1);
      final fuzzyKey = await service.enroll(normalized);

      final noisyEmbedding = List<double>.from(normalized);
      final indices = List.generate(512, (i) => i)..shuffle(rand);
      for (int i = 0; i < 30; i++) {
        noisyEmbedding[indices[i]] = -normalized[indices[i]];
      }

      final result = await service.verify(noisyEmbedding, fuzzyKey.publicSyndrome);

      print('Corrected bit errors (30 flips): ${result.correctedErrors}');
      expect(result.success, isTrue);
      expect(result.recoveredKey, equals(fuzzyKey.privateKey));
    });

    test('Verification fails with too many bit flips (200 bits)', () async {
      final rand = Random(42);
      final normalized = List.generate(512, (_) => rand.nextDouble() * 2 - 1);
      final fuzzyKey = await service.enroll(normalized);

      final noisyEmbedding = List<double>.from(normalized);
      final indices = List.generate(512, (i) => i)..shuffle(rand);
      for (int i = 0; i < 200; i++) {
        noisyEmbedding[indices[i]] = -normalized[indices[i]];
      }

      final result = await service.verify(noisyEmbedding, fuzzyKey.publicSyndrome);
      expect(result.success, isFalse);
    });

    test('Median embedding with binarization', () async {
      final rand = Random(42);
      final base = List.generate(512, (_) => rand.nextDouble() * 2 - 1);
      
      final samples = List.generate(5, (s) {
        final sample = List<double>.from(base);
        for (int i = 0; i < 40; i++) {
          int idx = rand.nextInt(512);
          sample[idx] = -base[idx];
        }
        return sample;
      });

      final median = FuzzyExtractorService.medianEmbedding(samples);
      
      final fuzzyKey = await service.enroll(base);
      final result = await service.verify(median, fuzzyKey.publicSyndrome);
      
      expect(result.success, isTrue);
    });
  });
}
