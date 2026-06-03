import 'dart:typed_data';
import 'dart:math';

/// Reed-Solomon codec over GF(256) using the primitive polynomial x^8 + x^4 + x^3 + x^2 + 1 (0x11D).
class ReedSolomon {
  final int dataShards;
  final int parityShards;
  final int totalShards;

  final Uint8List _expTable = Uint8List(512);
  final Uint8List _logTable = Uint8List(256);
  late final Uint8List _generator;

  ReedSolomon({required this.dataShards, required this.parityShards})
      : totalShards = dataShards + parityShards {
    if (dataShards <= 0 || parityShards <= 0) {
      throw ArgumentError('Data and parity shards must be positive');
    }
    if (totalShards > 255) {
      throw ArgumentError('Total shard count cannot exceed 255');
    }
    _initializeGaloisField();
    _generator = _buildGeneratorPolynomial(parityShards);
  }

  void _initializeGaloisField() {
    int x = 1;
    for (int i = 0; i < 255; i++) {
      _expTable[i] = x;
      _logTable[x] = i;
      x <<= 1;
      if (x & 0x100 != 0) x ^= 0x11d;
    }
    for (int i = 255; i < 512; i++) {
      _expTable[i] = _expTable[i - 255];
    }
    _logTable[0] = 0;
  }

  int _multiply(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _expTable[_logTable[a] + _logTable[b]];
  }

  int _divide(int a, int b) {
    if (b == 0) throw ArgumentError('Division by zero');
    if (a == 0) return 0;
    int diff = _logTable[a] - _logTable[b];
    return _expTable[(diff % 255 + 255) % 255];
  }

  int _inverse(int a) {
    if (a == 0) throw ArgumentError('Cannot invert zero');
    return _expTable[255 - _logTable[a]];
  }

  int _power(int a, int power) {
    if (a == 0) return 0;
    if (power == 0) return 1;
    int p = (power % 255 + 255) % 255;
    return _expTable[(_logTable[a] * p) % 255];
  }

  Uint8List _polyMul(Uint8List a, Uint8List b) {
    final result = Uint8List(a.length + b.length - 1);
    for (int i = 0; i < a.length; i++) {
      for (int j = 0; j < b.length; j++) {
        result[i + j] ^= _multiply(a[i], b[j]);
      }
    }
    return result;
  }

  Uint8List _buildGeneratorPolynomial(int degree) {
    Uint8List gen = Uint8List.fromList([1]);
    for (int i = 0; i < degree; i++) {
      gen = _polyMul(gen, Uint8List.fromList([1, _power(2, i)]));
    }
    return gen;
  }

  /// Encodes data and returns parity symbols.
  Uint8List encode(Uint8List data) {
    if (data.length != dataShards) {
      throw ArgumentError('Data length must be $dataShards');
    }
    final msg = Uint8List(totalShards);
    msg.setRange(0, dataShards, data);

    for (int i = 0; i < dataShards; i++) {
      int coef = msg[i];
      if (coef != 0) {
        for (int j = 1; j < _generator.length; j++) {
          msg[i + j] ^= _multiply(coef, _generator[j]);
        }
      }
    }
    return msg.sublist(dataShards);
  }

  /// Decodes a codeword and attempts to correct errors.
  Uint8List? decode(Uint8List codeword) {
    if (codeword.length != totalShards) {
      throw ArgumentError('Codeword length must be $totalShards');
    }

    final syndromes = Uint8List(parityShards);
    bool hasError = false;
    for (int i = 0; i < parityShards; i++) {
      int s = 0;
      int x = _power(2, i);
      for (int j = 0; j < totalShards; j++) {
        s = _multiply(s, x) ^ codeword[j];
      }
      syndromes[i] = s;
      if (s != 0) hasError = true;
    }

    if (!hasError) return codeword.sublist(0, dataShards);

    // Berlekamp-Massey
    Uint8List lambda = Uint8List.fromList([1]);
    Uint8List b = Uint8List.fromList([1]);
    int l = 0;
    int m = 1;
    int bInv = 1;

    for (int n = 0; n < parityShards; n++) {
      int d = syndromes[n];
      for (int i = 1; i <= l; i++) {
        if (i < lambda.length) {
          d ^= _multiply(lambda[lambda.length - 1 - i], syndromes[n - i]);
        }
      }

      if (d == 0) {
        m++;
      } else {
        Uint8List oldLambda = Uint8List.fromList(lambda);
        int factor = _divide(d, bInv);
        
        Uint8List term = Uint8List(b.length + m);
        for (int i = 0; i < b.length; i++) {
          term[i] = _multiply(factor, b[i]);
        }
        
        int maxSize = max(lambda.length, term.length);
        Uint8List nextLambda = Uint8List(maxSize);
        for (int i = 0; i < lambda.length; i++) {
          nextLambda[maxSize - 1 - i] ^= lambda[lambda.length - 1 - i];
        }
        for (int i = 0; i < term.length; i++) {
          nextLambda[maxSize - 1 - i] ^= term[term.length - 1 - i];
        }
        
        int firstNonZero = 0;
        while (firstNonZero < nextLambda.length && nextLambda[firstNonZero] == 0) {
          firstNonZero++;
        }
        lambda = nextLambda.sublist(min(firstNonZero, nextLambda.length - 1));

        if (2 * l <= n) {
          l = n + 1 - l;
          b = oldLambda;
          bInv = d;
          m = 1;
        } else {
          m++;
        }
      }
    }

    if (l > parityShards ~/ 2) return null; // Exceeds correction capacity

    final errorLocations = <int>[];
    for (int k = 0; k < totalShards; k++) {
      int xInv = _power(2, k - (totalShards - 1));
      int eval = 0;
      for (int j = 0; j < lambda.length; j++) {
        eval ^= _multiply(lambda[lambda.length - 1 - j], _power(xInv, j));
      }
      if (eval == 0) {
        errorLocations.add(k);
      }
    }

    if (errorLocations.length != l) return null;

    Uint8List omega = Uint8List(parityShards);
    for (int i = 0; i < parityShards; i++) {
      for (int j = 0; j <= i && j < lambda.length; j++) {
        omega[i] ^= _multiply(syndromes[i - j], lambda[lambda.length - 1 - j]);
      }
    }

    Uint8List lambdaPrime = Uint8List(lambda.length - 1);
    for (int i = 1; i < lambda.length; i += 2) {
      lambdaPrime[lambdaPrime.length - i] = lambda[lambda.length - 1 - i];
    }

    final correctedCodeword = Uint8List.fromList(codeword);
    for (int i = 0; i < errorLocations.length; i++) {
      int loc = errorLocations[i];
      int xInv = _power(2, loc - (totalShards - 1));
      int x = _inverse(xInv);
      
      int num = 0;
      for (int j = 0; j < omega.length; j++) {
        num ^= _multiply(omega[j], _power(xInv, j));
      }
      
      int den = 0;
      for (int j = 0; j < lambdaPrime.length; j++) {
        den ^= _multiply(lambdaPrime[lambdaPrime.length - 1 - j], _power(xInv, j));
      }
      
      int errorValue = _multiply(x, _divide(num, den));
      correctedCodeword[loc] ^= errorValue;
    }

    // Final check: syndromes must be zero for the corrected codeword
    for (int i = 0; i < parityShards; i++) {
      int s = 0;
      int x = _power(2, i);
      for (int j = 0; j < totalShards; j++) {
        s = _multiply(s, x) ^ correctedCodeword[j];
      }
      if (s != 0) return null;
    }

    return correctedCodeword.sublist(0, dataShards);
  }
}
