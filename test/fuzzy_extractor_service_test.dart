import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:biovault_id/services/fuzzy_extractor_service.dart';
import 'package:biovault_id/models/fuzzy_key.dart';

void main() {
  group('FuzzyExtractorService', () {
    late FuzzyExtractorService service;

    setUp(() {
      service = FuzzyExtractorService();
    });

    test('enroll creates valid FuzzyKey from embedding', () async {
      final embedding = List<double>.generate(128, (i) => sin(i / 10.0));

      final fuzzyKey = await service.enroll(embedding);

      expect(fuzzyKey, isA<FuzzyKey>());
      expect(fuzzyKey.publicSyndrome, isNotEmpty);
      expect(fuzzyKey.privateKey, isNotEmpty);
      expect(fuzzyKey.metadata.framesCount, equals(1));
      expect(fuzzyKey.metadata.averageQuality, greaterThanOrEqualTo(0.0));
    });

    test('enroll throws on invalid embedding length', () async {
      final invalidEmbedding = [1.0, 2.0, 3.0];

      expect(
        () => service.enroll(invalidEmbedding),
        throwsA(isA<ArgumentError>()),
      );
    });

    test('verify succeeds for identical embedding', () async {
      final embedding = List<double>.generate(128, (i) => cos(i / 15.0));
      final fuzzyKey = await service.enroll(embedding);

      final result = await service.verify(embedding, fuzzyKey.publicSyndrome);

      expect(result.success, isTrue);
      expect(result.recoveredKey, equals(fuzzyKey.privateKey));
      expect(result.embeddingDistance, lessThanOrEqualTo(5.0));
    });

    test('verify succeeds for slightly noisy embedding', () async {
      final embedding = List<double>.generate(128, (i) => sin(i / 10.0));
      final fuzzyKey = await service.enroll(embedding);

      final noisyEmbedding = embedding.map((value) {
        return (value + 0.02).clamp(-1.0, 1.0);
      }).toList();

      final result = await service.verify(noisyEmbedding, fuzzyKey.publicSyndrome);

      expect(result.success, isTrue);
      expect(result.recoveredKey, equals(fuzzyKey.privateKey));
      expect(result.correctedErrors, greaterThanOrEqualTo(0));
    });

    test('verify rejects completely different embedding', () async {
      final embedding = List<double>.generate(128, (i) => sin(i / 10.0));
      final fuzzyKey = await service.enroll(embedding);

      final differentEmbedding = List<double>.generate(128, (i) => cos(i / 5.0));
      final result = await service.verify(differentEmbedding, fuzzyKey.publicSyndrome);

      expect(result.success, isFalse);
      expect(result.recoveredKey, isNull);
      expect(result.errorMessage, isNotNull);
    });

    test('verify throws on invalid embedding length', () async {
      final invalidEmbedding = [1.0, 2.0, 3.0];
      final dummySyndrome = '0,1,2';

      expect(
        () => service.verify(invalidEmbedding, dummySyndrome),
        throwsA(isA<ArgumentError>()),
      );
    });
  });
}
