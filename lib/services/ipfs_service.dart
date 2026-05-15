import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:pointycastle/export.dart';

class IpfsService {
  final Dio _dio;
  String gatewayUrl;
  static const int _ivSize = 12;
  static const int _tagSize = 128;
  
  bool _isTestMode = false;
  final Map<String, Uint8List> _mockIpfs = {};

  IpfsService({String? gatewayUrl, Dio? dio, bool testMode = true})
      : gatewayUrl = gatewayUrl ?? 'https://ipfs.io',
        _dio = dio ?? Dio(),
        _isTestMode = testMode;

  /// Загружает зашифрованные данные в IPFS и возвращает CID.
  Future<String> uploadEncryptedData(Uint8List payload) async {
    if (_isTestMode) {
      final mockHash = "Qm" + sha256.convert(payload).toString().substring(0, 44);
      _mockIpfs[mockHash] = payload;
      print("Mock IPFS: Uploaded data with CID $mockHash");
      return mockHash;
    }
    
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(payload, filename: 'payload.bin'),
    });

    final response = await _dio.post(
      '$gatewayUrl/api/v0/add',
      data: formData,
      options: Options(headers: {'Content-Type': 'multipart/form-data'}),
    );

    return response.data['Hash'] as String;
  }

  /// Загружает данные из IPFS по CID.
  Future<Uint8List> downloadData(String cid) async {
    if (_isTestMode) {
      if (_mockIpfs.containsKey(cid)) {
        return _mockIpfs[cid]!;
      }
      throw Exception("CID $cid not found in mock storage");
    }
    final url = '$gatewayUrl/ipfs/$cid';
    final response = await _dio.get<List<int>>(url,
        options: Options(responseType: ResponseType.bytes));
    return Uint8List.fromList(response.data ?? []);
  }

  Uint8List encryptPayload(String payload, String key) {
    final plaintext = utf8.encode(payload);
    final aesKey = _deriveKey(key);
    final iv = _secureRandom(_ivSize);
    final cipher = GCMBlockCipher(AESFastEngine())
      ..init(true, AEADParameters(KeyParameter(aesKey), _tagSize, iv, Uint8List(0)));
    final encrypted = cipher.process(Uint8List.fromList(plaintext));
    return Uint8List.fromList(iv + encrypted);
  }

  String decryptPayload(Uint8List encryptedPayload, String key) {
    final iv = encryptedPayload.sublist(0, _ivSize);
    final ciphertext = encryptedPayload.sublist(_ivSize);
    final aesKey = _deriveKey(key);
    final cipher = GCMBlockCipher(AESFastEngine())
      ..init(false, AEADParameters(KeyParameter(aesKey), _tagSize, iv, Uint8List(0)));
    final decrypted = cipher.process(Uint8List.fromList(ciphertext));
    return utf8.decode(decrypted);
  }

  Uint8List _deriveKey(String key) {
    final keyBytes = utf8.encode(key);
    final hash = sha256.convert(keyBytes).bytes;
    return Uint8List.fromList(hash);
  }

  Uint8List _secureRandom(int length) {
    final random = SecureRandom('Fortuna')
      ..seed(KeyParameter(_seed()));
    return random.nextBytes(length);
  }

  Uint8List _seed() {
    final seed = Uint8List(32);
    final rnd = Random.secure();
    for (var i = 0; i < seed.length; i++) {
      seed[i] = rnd.nextInt(256);
    }
    return seed;
  }
}
