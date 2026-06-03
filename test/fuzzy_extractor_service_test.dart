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

    test('enroll creates valid FuzzyKey from 512-dim embedding', () async {
      final embedding = List<double>.generate(512, (i) => sin(i / 10.0));

      final fuzzyKey = await service.enroll(embedding);

      expect(fuzzyKey, isA<FuzzyKey>());
      expect(fuzzyKey.publicSyndrome, isNotEmpty);
      expect(fuzzyKey.privateKey, isNotEmpty);
    });

    test('verify succeeds for identical embedding', () async {
      final embedding = List<double>.generate(512, (i) => cos(i / 15.0));
      final fuzzyKey = await service.enroll(embedding);

      final result = await service.verify(embedding, fuzzyKey.publicSyndrome);

      expect(result.success, isTrue);
      expect(result.recoveredKey, equals(fuzzyKey.privateKey));
      expect(result.correctedErrors, equals(0));
    });

    test('verify rejects completely random embedding', () async {
      final rand = Random(42);
      final embedding = List<double>.generate(512, (i) => rand.nextDouble() * 2 - 1);
      final fuzzyKey = await service.enroll(embedding);

      final differentEmbedding = List<double>.generate(512, (i) => rand.nextDouble() * 2 - 1);
      final result = await service.verify(differentEmbedding, fuzzyKey.publicSyndrome);

      expect(result.success, isFalse);
    });
  });
}
