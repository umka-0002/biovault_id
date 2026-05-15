
/// Reed-Solomon codec over GF(256).
/// Supports message length up to 255 bytes and parity length up to 255 bytes.
class ReedSolomon {
  final int dataShards;
  final int parityShards;
  final int totalShards;

  final List<int> _expTable = List.filled(512, 0);
  final List<int> _logTable = List.filled(256, 0);
  late final List<int> _generator;

  ReedSolomon({required this.dataShards, required this.parityShards})
      : totalShards = dataShards + parityShards {
    if (dataShards <= 0 || parityShards <= 0) {
      throw ArgumentError('Data and parity shards must be positive');
    }
    if (totalShards > 255) {
      throw ArgumentError('Total shard count cannot exceed 255 for GF(256) Reed-Solomon');
    }

    _initializeGaloisField();
    _generator = _buildGeneratorPolynomial(parityShards);
  }

  void _initializeGaloisField() {
    var x = 1;
    for (var i = 0; i < 255; i++) {
      _expTable[i] = x;
      _logTable[x] = i;
      x <<= 1;
      if (x & 0x100 != 0) {
        x ^= 0x11d;
      }
    }
    for (var i = 255; i < 512; i++) {
      _expTable[i] = _expTable[i - 255];
    }
    _logTable[0] = 0;
  }

  int _add(int a, int b) => a ^ b;
  int _subtract(int a, int b) => a ^ b;

  int _multiply(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _expTable[_logTable[a] + _logTable[b]];
  }

  int _divide(int a, int b) {
    if (b == 0) {
      throw ArgumentError('Division by zero in GF(256)');
    }
    if (a == 0) return 0;
    final diff = _logTable[a] - _logTable[b];
    return _expTable[(diff % 255 + 255) % 255];
  }

  int _inverse(int a) {
    if (a == 0) {
      throw ArgumentError('Inverse of zero is not defined');
    }
    return _expTable[255 - _logTable[a]];
  }

  int _power(int a, int power) {
    if (power == 0) return 1;
    if (a == 0) return 0;
    return _expTable[(_logTable[a] * power) % 255];
  }

  List<int> _polyMultiply(List<int> a, List<int> b) {
    final result = List<int>.filled(a.length + b.length - 1, 0);
    for (var i = 0; i < a.length; i++) {
      for (var j = 0; j < b.length; j++) {
        result[i + j] = _add(result[i + j], _multiply(a[i], b[j]));
      }
    }
    return result;
  }

  List<int> _polyAdd(List<int> a, List<int> b) {
    final length = a.length > b.length ? a.length : b.length;
    final result = List<int>.filled(length, 0);
    for (var i = 0; i < length; i++) {
      final aCoef = i < a.length ? a[i] : 0;
      final bCoef = i < b.length ? b[i] : 0;
      result[i] = _add(aCoef, bCoef);
    }
    return result;
  }

  List<int> _polyScale(List<int> poly, int scalar) {
    return poly.map((coeff) => _multiply(coeff, scalar)).toList(growable: false);
  }

  List<int> _polyEvaluate(List<int> poly, int x) {
    var result = 0;
    for (var i = poly.length - 1; i >= 0; i--) {
      result = _multiply(result, x) ^ poly[i];
    }
    return result;
  }

  List<int> _buildGeneratorPolynomial(int degree) {
    var generator = <int>[1];
    for (var i = 0; i < degree; i++) {
      generator = _polyMultiply(generator, <int>[1, _power(2, i)]);
    }
    return generator;
  }

  List<int> encode(List<int> message) {
    if (message.length != dataShards) {
      throw ArgumentError('Message length must be $dataShards bytes');
    }

    final padded = List<int>.from(message)
      ..addAll(List<int>.filled(parityShards, 0));

    for (var i = 0; i < dataShards; i++) {
      final coefficient = padded[i];
      if (coefficient != 0) {
        for (var j = 0; j < _generator.length; j++) {
          padded[i + j] = _add(padded[i + j], _multiply(_generator[j], coefficient));
        }
      }
    }

    return padded.sublist(dataShards);
  }

  List<int> decode(List<int> codeword) {
    if (codeword.length != totalShards) {
      throw ArgumentError('Codeword length must be $totalShards bytes');
    }

    final syndromes = _calculateSyndromes(codeword);
    if (syndromes.every((value) => value == 0)) {
      return codeword.sublist(0, dataShards);
    }

    final sigma = _berlekampMassey(syndromes);
    final errorLocations = _findErrorLocations(sigma);
    if (errorLocations == null) {
      throw Exception('Too many errors to correct');
    }

    final errorMagnitudes = _calculateErrorMagnitudes(syndromes, sigma, errorLocations);
    final corrected = List<int>.from(codeword);
    for (var i = 0; i < errorLocations.length; i++) {
      final position = errorLocations[i];
      corrected[position] = _add(corrected[position], errorMagnitudes[i]);
    }

    return corrected.sublist(0, dataShards);
  }

  List<int> _calculateSyndromes(List<int> codeword) {
    final syndromes = List<int>.filled(parityShards, 0);
    for (var i = 0; i < parityShards; i++) {
      syndromes[i] = _polyEvaluate(codeword, _power(2, i + 1));
    }
    return syndromes;
  }

  List<int> _berlekampMassey(List<int> syndromes) {
    var sigma = <int>[1];
    var b = <int>[1];
    var l = 0;
    var m = 1;
    var bLast = 1;

    for (var n = 0; n < syndromes.length; n++) {
      var discrepancy = syndromes[n];
      for (var i = 1; i <= l; i++) {
        discrepancy = _add(discrepancy, _multiply(sigma[i], syndromes[n - i]));
      }

      if (discrepancy != 0) {
        final t = List<int>.from(sigma);
        final scale = _divide(discrepancy, bLast);
        final shifted = List<int>.filled(m, 0)
          ..addAll(_polyScale(b, scale));
        sigma = _polyAdd(sigma, shifted);

        if (2 * l <= n) {
          l = n + 1 - l;
          b = t;
          bLast = discrepancy;
          m = 1;
        } else {
          m += 1;
        }
      } else {
        m += 1;
      }
    }

    return sigma;
  }

  List<int>? _findErrorLocations(List<int> errorLocator) {
    final errorCount = errorLocator.length - 1;
    if (errorCount == 0) {
      return <int>[];
    }

    final locations = <int>[];
    for (var i = 0; i < totalShards; i++) {
      final evaluation = _polyEvaluate(errorLocator, _power(2, 255 - i));
      if (evaluation == 0) {
        locations.add(i);
      }
    }

    if (locations.length != errorCount) {
      return null;
    }
    return locations;
  }

  List<int> _buildOmega(List<int> syndromes, List<int> errorLocator) {
    final product = _polyMultiply(syndromes, errorLocator);
    return product.sublist(0, parityShards);
  }

  List<int> _polyDerivative(List<int> poly) {
    if (poly.length <= 1) {
      return <int>[0];
    }
    final derivative = <int>[];
    for (var i = 1; i < poly.length; i++) {
      derivative.add(_multiply(poly[i], i));
    }
    return derivative;
  }

  List<int> _calculateErrorMagnitudes(
    List<int> syndromes,
    List<int> errorLocator,
    List<int> errorLocations,
  ) {
    final omega = _buildOmega(syndromes, errorLocator);
    final derivative = _polyDerivative(errorLocator);
    final magnitudes = <int>[];

    for (final position in errorLocations) {
      final x = _power(2, 255 - position);
      final xInv = _inverse(x);
      final numerator = _polyEvaluate(omega, xInv);
      final denominator = _polyEvaluate(derivative, xInv);
      final magnitude = _divide(_multiply(numerator, xInv), denominator);
      magnitudes.add(magnitude);
    }

    return magnitudes;
  }
}
