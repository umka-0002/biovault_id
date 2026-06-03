import 'dart:typed_data';
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
  });
}
