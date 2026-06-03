import 'dart:typed_data';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:biovault_id/utils/reed_solomon_new.dart';

void main() {
  group('ReedSolomon', () {
    test('encode/decode works without errors', () {
      final rs = ReedSolomon(dataShards: 10, parityShards: 4);
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final parity = rs.encode(data);
      
      final codeword = Uint8List(14);
      codeword.setRange(0, 10, data);
      codeword.setRange(10, 14, parity);
      
      final recovered = rs.decode(codeword);
      expect(recovered, equals(data));
    });

    test('encode/decode corrects 2 errors', () {
      final rs = ReedSolomon(dataShards: 10, parityShards: 4); // t = 2
      final data = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
      final parity = rs.encode(data);
      
      final codeword = Uint8List(14);
      codeword.setRange(0, 10, data);
      codeword.setRange(10, 14, parity);
      
      // Corrupt 2 bytes
      codeword[0] ^= 0xFF;
      codeword[5] ^= 0xAA;
      
      final recovered = rs.decode(codeword);
      expect(recovered, equals(data));
    });

    test('encode/decode corrects 60 errors with parityShards: 127', () {
      final rs = ReedSolomon(dataShards: 128, parityShards: 127);
      final data = Uint8List.fromList(List.generate(128, (i) => i % 256));
      final parity = rs.encode(data);
      
      final codeword = Uint8List(255);
      codeword.setRange(0, 128, data);
      codeword.setRange(128, 255, parity);
      
      final rand = Random(42);
      final indices = List.generate(255, (i) => i)..shuffle(rand);
      for (int i = 0; i < 60; i++) {
        codeword[indices[i]] ^= 0x01;
      }
      
      final recovered = rs.decode(codeword);
      expect(recovered, isNotNull);
      expect(recovered, equals(data));
    });
  });
}
