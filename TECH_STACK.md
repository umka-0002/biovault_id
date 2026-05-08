# BioVault ID — Технологический стек и внедрение

## Общий стек

```
┌───────────────────────────────────────────────────────────┐
│                   Frontend Layer                          │
│              Flutter 3.11.5 (iOS/Android)                 │
├───────────────────────────────────────────────────────────┤
│  Edge AI      │  Crypto       │ Storage    │ Blockchain   │
│  TensorFlow   │  Reed-Solomon │ IPFS       │ Web3dart     │
│  Lite + XNNP  │  + Fuzzy Ext. │ + AES      │ + EVM RPC    │
└───────────────────────────────────────────────────────────┘
```

---

## 1. Frontend (Flutter)

### Зависимости
```yaml
dependencies:
  # Flutter Framework
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8

  # Edge AI
  tflite_flutter: ^0.10.4       # TensorFlow Lite inference
  image: ^4.0.17                # Image processing

  # Web3 & Blockchain
  web3dart: ^2.7.3              # Ethereum client
  http: ^1.1.0                  # HTTP requests
  dio: ^5.3.0                   # Advanced HTTP

  # Optional: Crypto & Security
  # pointycastle: ^3.6.2         # Cryptographic operations
  # flutter_secure_storage: ^9.0 # Secure key storage
```

### Структура проекта (детальная)

```
lib/
├── main.dart
│   ├── MyApp (MaterialApp)
│   └── MyHomePage (entry point)
│
├── services/
│   ├── face_recognition_service.dart
│   │   ├── loadModel() → Future<void>
│   │   ├── predict(image) → List<double>
│   │   ├── _imageToByteListFloat32() → Uint8List
│   │   └── dispose() → void
│   │
│   ├── fuzzy_extractor_service.dart (IN PROGRESS)
│   │   ├── enroll(embedding) → Future<FuzzyKey>
│   │   ├── verify(embedding) → Future<String?>
│   │   ├── _reedSolomonEncode() → (key, syndrome)
│   │   └── _reedSolomonDecode() → String
│   │
│   ├── ipfs_service.dart (IN PROGRESS)
│   │   ├── upload(data) → Future<String> (CID)
│   │   ├── download(cid) → Future<Map>
│   │   └── configureGateway(url) → void
│   │
│   ├── blockchain_service.dart (IN PROGRESS)
│   │   ├── registerBio(syndrome, cid) → Future<String>
│   │   ├── verifyBio(syndrome) → Future<bool>
│   │   ├── getUserData(address) → Future<UserData>
│   │   └── _initializeWeb3() → void
│   │
│   └── biometric_auth_service.dart
│       ├── authenticate() → Future<bool>
│       ├── _performLivenessCheck() → Future<bool>
│       └── _compareEmbeddings() → double
│
├── models/
│   ├── user_profile.dart
│   │   └── class UserProfile
│   │
│   ├── face_embedding.dart
│   │   └── class FaceEmbedding
│   │
│   ├── blockchain_transaction.dart
│   │   └── class BioTxn
│   │
│   └── fuzzy_key.dart
│       └── class FuzzyKey
│
├── ui/
│   ├── screens/
│   │   ├── camera_screen.dart
│   │   │   ├── _CameraScreenState
│   │   │   ├── _initializeCamera()
│   │   │   ├── _captureAndProcess()
│   │   │   └── _showFaceDetection()
│   │   │
│   │   ├── enrollment_screen.dart
│   │   │   ├── Multi-frame enrollment
│   │   │   ├── Progress tracking
│   │   │   └── Fuzzy Extractor integration
│   │   │
│   │   ├── verification_screen.dart
│   │   │   ├── Single frame verification
│   │   │   ├── Blockchain verification
│   │   │   └── Result display
│   │   │
│   │   └── profile_screen.dart
│   │       ├── User info
│   │       ├── Verification history
│   │       └── Account recovery
│   │
│   └── widgets/
│       ├── camera_preview_widget.dart
│       ├── embedding_display_widget.dart
│       ├── verification_status_widget.dart
│       └── blockchain_transaction_widget.dart
│
└── utils/
    ├── constants.dart
    │   ├── const int EMBEDDING_SIZE = 128
    │   ├── const String FACENET_MODEL = 'assets/models/facenet.tflite'
    │   └── const String CONTRACT_ADDRESS = '0x...'
    │
    ├── crypto_utils.dart
    │   ├── hashEmbedding() → String
    │   ├── encryptData() → Uint8List
    │   ├── decryptData() → String
    │   └── generateSignature() → String
    │
    └── logger.dart
        └── Logging utilities
```

### Инициализация приложения

```dart
// lib/main.dart
import 'package:flutter/material.dart';
import 'services/face_recognition_service.dart';
import 'services/blockchain_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // 1. Загрузить ML модели
  final faceService = FaceRecognitionService();
  await faceService.loadModel();
  
  // 2. Инициализировать blockchain
  final blockchainService = BlockchainService();
  await blockchainService.initialize();
  
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioVault ID',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const CameraScreen(),
    );
  }
}
```

---

## 2. Edge AI Layer

### TensorFlow Lite модели

#### a) MTCNN (Multi-task Cascaded CNN)
- **Размер**: ~3 MB
- **Входные данные**: 任意大小 видеокадр (обычно 480×640)
- **Выходные данные**: Координаты лиц + ключевые точки
- **Вычисления**: ~30-50ms на мобильном GPU

#### b) FaceNet
- **Размер**: ~23 MB (мобильная версия)
- **Входные данные**: 160×160×3 изображение
- **Выходные данные**: 128-мерный вектор (embedding)
- **Вычисления**: ~200-300ms на CPU, ~50-100ms на GPU/NPU

### Текущая реализация (детали)

[см. lib/services/face_recognition_service.dart](lib/services/face_recognition_service.dart)

```dart
class FaceRecognitionService {
  Interpreter? _interpreter;

  // Загрузка модели с ускорением
  Future<void> loadModel() async {
    try {
      final options = InterpreterOptions();
      
      // GPU ускорение на Android
      if (Platform.isAndroid) {
        options.addDelegate(XNNPackDelegate());
      }
      
      // GPU ускорение на iOS
      if (Platform.isIOS) {
        options.addDelegate(GpuDelegateV2());
      }

      _interpreter = await Interpreter.fromAsset(
        'assets/models/facenet.tflite',
        options: options,
      );
      
      print("✓ Модель FaceNet загружена успешно");
    } catch (e) {
      print("✗ Ошибка загрузки: $e");
      rethrow;
    }
  }

  // Главная функция: получить embedding
  List<double> predict(img.Image faceImage) {
    if (_interpreter == null) {
      throw Exception("Модель не инициализирована. Вызовите loadModel()");
    }

    // 1. Resize до 160×160
    img.Image resizedImage = img.copyResize(
      faceImage,
      width: 160,
      height: 160,
    );

    // 2. Конвертировать в Float32 тензор
    var input = _imageToByteListFloat32(resizedImage);

    // 3. Подготовить буфер для output (1 × 128 эмбеддинг)
    var output = List.filled(1 * 128, 0.0).reshape([1, 128]);

    // 4. Запустить инференс
    _interpreter!.run(input, output);

    // 5. Вернуть вектор
    return List<double>.from(output[0]);
  }

  // Предобработка: RGB байты → Float32 нормализованный
  Uint8List _imageToByteListFloat32(img.Image image) {
    var convertedBytes = Float32List(1 * 160 * 160 * 3);
    var buffer = Float32List.view(convertedBytes.buffer);
    
    int pixelIndex = 0;
    
    for (var i = 0; i < 160; i++) {
      for (var j = 0; j < 160; j++) {
        var pixel = image.getPixel(j, i);
        
        // Нормализация: (value - 127.5) / 128.0
        buffer[pixelIndex++] = (img.getRed(pixel) - 127.5) / 128.0;
        buffer[pixelIndex++] = (img.getGreen(pixel) - 127.5) / 128.0;
        buffer[pixelIndex++] = (img.getBlue(pixel) - 127.5) / 128.0;
      }
    }
    
    return convertedBytes.buffer.asUint8List();
  }

  // Освобождение ресурсов
  void dispose() {
    _interpreter?.close();
  }
}
```

### Оптимизация на Android

**файл**: `android/app/build.gradle.kts`

```kotlin
dependencies {
    // TensorFlow Lite с GPU support
    implementation("org.tensorflow:tensorflow-lite:2.14.0")
    implementation("org.tensorflow:tensorflow-lite-gpu:2.14.0")
    implementation("org.tensorflow:tensorflow-lite-gpu-delegate-plugin:0.4.4")
}
```

### Оптимизация на iOS

**файл**: `ios/Podfile`

```ruby
post_install do |installer|
  installer.pods_project.targets.each do |target|
    flutter_additional_ios_build_settings(target)
    target.build_configurations.each do |config|
      config.build_settings['GCC_PREPROCESSOR_DEFINITIONS'] ||= [
        '$(inherited)',
        'TENSORFLOW_LITE_USE_NNAPI',
      ]
    end
  end
end
```

---

## 3. Fuzzy Extractor (Reed-Solomon)

### Теория

**Reed-Solomon коды** — это алгебраический код с исправлением ошибок:
- **n** = 256 (всего символов)
- **k** = 128 (информационные символы)
- **t** = 64 (исправляемые ошибки)

**Формула**: $t = \lfloor (n - k) / 2 \rfloor = \lfloor (256 - 128) / 2 \rfloor = 64$

### Энкодирование (Регистрация)

```
Embedding (128-мер вектор) → Quantization → 256 символов
    ↓
Reed-Solomon encode:
    • Информационные: 128 символов (embedding)
    • Паритет: 128 символов (correction codes)
    ↓
Публичный синдром: hash(паритет) → в blockchain
Приватный ключ: SHA-256(информационные + secret) → хранить локально
```

### Декодирование (Верификация)

```
Новый embedding → Quantization → 256 символов (с ошибками)
    ↓
Reed-Solomon decode:
    • Использовать синдром из blockchain
    • Исправить до 64 символа ошибок
    ↓
Восстановленный embedding → SHA-256 → ключ
```

### Реализация (псевдокод)

```dart
// lib/services/fuzzy_extractor_service.dart (IN PROGRESS)
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

class FuzzyExtractorService {
  static const int EMBEDDING_SIZE = 128;
  static const int REED_SOLOMON_N = 256;
  static const int REED_SOLOMON_K = 128;
  static const int CORRECTION_CAPABILITY = 64;

  // Фаза 1: Енролмент (привязка лица к ключу)
  Future<FuzzyKey> enroll(List<double> embedding) async {
    // 1. Quantize: 128-мер float вектор → 128 целых символов
    List<int> quantized = _quantizeEmbedding(embedding);

    // 2. Reed-Solomon encode
    final (publicSyndrome, privateKey) = 
      _reedSolomonEncode(quantized);

    // 3. Вернуть оба компонента
    return FuzzyKey(
      publicSyndrome: publicSyndrome,
      privateKey: privateKey,
      enrollmentTime: DateTime.now(),
    );
  }

  // Фаза 2: Верификация (проверить лицо)
  Future<String?> verify(
    List<double> newEmbedding,
    String publicSyndrome,
  ) async {
    try {
      // 1. Quantize новый embedding
      List<int> quantized = _quantizeEmbedding(newEmbedding);

      // 2. Reed-Solomon decode с использованием синдрома
      String? recoveredKey = _reedSolomonDecode(
        quantized,
        publicSyndrome,
      );

      if (recoveredKey == null) {
        print("✗ Слишком много ошибок: лицо не совпадает");
        return null;
      }

      print("✓ Лицо верифицировано. Ключ восстановлен");
      return recoveredKey;
    } catch (e) {
      print("✗ Ошибка верификации: $e");
      return null;
    }
  }

  // Quantization: нормализованный float вектор → целые числа
  List<int> _quantizeEmbedding(List<double> embedding) {
    List<int> result = [];
    for (double value in embedding) {
      // Масштабирование: [-1, 1] → [0, 255]
      int quantized = ((value + 1.0) * 127.5).toInt();
      result.add(quantized.clamp(0, 255));
    }
    return result;
  }

  // De-quantization: целые числа → float вектор
  List<double> _dequantizeEmbedding(List<int> quantized) {
    List<double> result = [];
    for (int value in quantized) {
      // Масштабирование: [0, 255] → [-1, 1]
      double dequantized = (value / 127.5) - 1.0;
      result.add(dequantized);
    }
    return result;
  }

  // Reed-Solomon Encode
  (String, String) _reedSolomonEncode(List<int> data) {
    // Примечание: Здесь нужна реальная RS библиотека
    // Это ПСЕВДОКОД для иллюстрации
    
    // 1. Добавить паритет
    List<int> codeword = _addParitySymbols(data); // 128 → 256

    // 2. Вычислить синдром (публичный)
    String syndrome = sha256.convert(codeword.sublist(128)).toString();

    // 3. Вычислить ключ (приватный)
    String key = sha256.convert(data).toString();

    return (syndrome, key);
  }

  // Reed-Solomon Decode (с коррекцией ошибок)
  String? _reedSolomonDecode(List<int> received, String syndrome) {
    try {
      // 1. Попытка исправить ошибки (до 64 символов)
      List<int>? corrected = _correctErrors(received, syndrome);

      if (corrected == null) {
        return null; // Слишком много ошибок
      }

      // 2. Восстановленные данные → ключ
      String recoveredKey = sha256.convert(corrected.sublist(0, 128)).toString();

      return recoveredKey;
    } catch (e) {
      return null;
    }
  }

  // Исправление ошибок (Berlekamp-Massey или Euclidean algorithm)
  List<int>? _correctErrors(List<int> received, String syndrome) {
    // STUB: нужна реальная RS реализация
    // Здесь должна быть Berlekamp-Massey or Peterson–Gorenstein–Zierler algorithm
    
    // Для прототипа: просто проверить синдром
    String receivedSyndrome = sha256.convert(received.sublist(128)).toString();
    
    if (receivedSyndrome == syndrome) {
      return received; // Нет ошибок
    }
    
    // TODO: Реальная коррекция ошибок
    return null;
  }

  List<int> _addParitySymbols(List<int> data) {
    // STUB: добавить 128 символов паритета
    List<int> parity = List.filled(128, 0);
    return [...data, ...parity];
  }
}

// Модель данных
class FuzzyKey {
  final String publicSyndrome;
  final String privateKey;
  final DateTime enrollmentTime;

  FuzzyKey({
    required this.publicSyndrome,
    required this.privateKey,
    required this.enrollmentTime,
  });
}
```

### Используемые библиотеки (при наличии)

- **pointycastle**: Для криптографических операций
- **Собственная реализация**: Reed-Solomon на Dart (рекомендуется для контроля)

---

## 4. IPFS Integration

### Архитектура

```
Dart App
   ↓
HTTP Client (dio)
   ↓
IPFS HTTP API (:5001)
   ↓
IPFS Daemon
```

### Сервис

```dart
// lib/services/ipfs_service.dart (IN PROGRESS)
import 'package:dio/dio.dart';

class IPFSService {
  late Dio _httpClient;
  String _gatewayUrl = 'http://localhost:5001';

  IPFSService() {
    _httpClient = Dio(
      BaseOptions(
        baseUrl: _gatewayUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );
  }

  // Загрузить зашифрованные данные
  Future<String> uploadEncrypted(Map<String, dynamic> data) async {
    try {
      final jsonData = jsonEncode(data);
      final encryptedData = _encryptData(jsonData);

      FormData formData = FormData.fromMap({
        'file': MultipartFile.fromBytes(
          encryptedData,
          filename: 'biometric_backup',
        ),
      });

      Response response = await _httpClient.post(
        '/api/v0/add',
        data: formData,
      );

      final cid = response.data['Hash'];
      print("✓ Загружено в IPFS: $cid");
      return cid;
    } catch (e) {
      print("✗ Ошибка загрузки в IPFS: $e");
      rethrow;
    }
  }

  // Скачать и расшифровать данные
  Future<Map<String, dynamic>> downloadDecrypted(String cid) async {
    try {
      Response response = await _httpClient.get(
        '/ipfs/$cid',
      );

      final decrypted = _decryptData(response.data);
      final json = jsonDecode(decrypted);

      print("✓ Скачано из IPFS: $cid");
      return json;
    } catch (e) {
      print("✗ Ошибка скачивания из IPFS: $e");
      rethrow;
    }
  }

  // Шифрование (AES-256-GCM)
  Uint8List _encryptData(String data) {
    // TODO: Реальное шифрование
    // Использовать приватный ключ пользователя
    return utf8.encode(data) as Uint8List;
  }

  // Дешифрование
  String _decryptData(dynamic data) {
    // TODO: Реальное дешифрование
    return utf8.decode(data);
  }
}
```

---

## 5. Blockchain Integration (Web3)

### Смарт-контракт (Solidity)

**Файл**: `contracts/BioVaultID.sol` (нужно создать)

```solidity
// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

contract BioVaultID {
    // Структура: данные биометрии пользователя
    struct BiometricData {
        bytes32 faceSyndrome;      // Публичный синдром Reed-Solomon
        string ipfsCID;            // Ссылка на IPFS хранилище
        uint256 enrollmentTime;    // Время регистрации
        uint256 lastVerification;  // Последняя верификация
        uint256 verificationCount; // Кол-во верификаций
    }

    // Маппинг: адрес → данные
    mapping(address => BiometricData) public bioData;
    mapping(address => bool) public isRegistered;

    // События
    event BioRegistered(
        address indexed user,
        bytes32 syndrome,
        string ipfsCID,
        uint256 timestamp
    );

    event VerificationSuccess(
        address indexed user,
        uint256 timestamp,
        uint256 totalCount
    );

    event BioUpdated(
        address indexed user,
        bytes32 newSyndrome,
        uint256 timestamp
    );

    // 1. Регистрация нового пользователя
    function registerBio(
        bytes32 _faceSyndrome,
        string memory _ipfsCID
    ) external {
        require(!isRegistered[msg.sender], "Already registered");
        require(_faceSyndrome != 0, "Invalid syndrome");
        require(bytes(_ipfsCID).length > 0, "Invalid IPFS CID");

        bioData[msg.sender] = BiometricData({
            faceSyndrome: _faceSyndrome,
            ipfsCID: _ipfsCID,
            enrollmentTime: block.timestamp,
            lastVerification: 0,
            verificationCount: 0
        });

        isRegistered[msg.sender] = true;

        emit BioRegistered(
            msg.sender,
            _faceSyndrome,
            _ipfsCID,
            block.timestamp
        );
    }

    // 2. Верификация лица
    function verifyBio(bytes32 _providedSyndrome) external {
        require(isRegistered[msg.sender], "Not registered");
        require(
            bioData[msg.sender].faceSyndrome == _providedSyndrome,
            "Verification failed"
        );

        bioData[msg.sender].lastVerification = block.timestamp;
        bioData[msg.sender].verificationCount++;

        emit VerificationSuccess(
            msg.sender,
            block.timestamp,
            bioData[msg.sender].verificationCount
        );
    }

    // 3. Получить данные пользователя
    function getUserData(address _user) external view returns (
        bytes32 syndrome,
        string memory ipfsCID,
        uint256 enrollmentTime,
        uint256 lastVerification,
        uint256 verificationCount,
        bool registered
    ) {
        return (
            bioData[_user].faceSyndrome,
            bioData[_user].ipfsCID,
            bioData[_user].enrollmentTime,
            bioData[_user].lastVerification,
            bioData[_user].verificationCount,
            isRegistered[_user]
        );
    }

    // 4. Обновить синдром (для смены лица)
    function updateBio(bytes32 _newSyndrome, string memory _newCID) external {
        require(isRegistered[msg.sender], "Not registered");
        require(_newSyndrome != 0, "Invalid syndrome");

        bioData[msg.sender].faceSyndrome = _newSyndrome;
        bioData[msg.sender].ipfsCID = _newCID;
        bioData[msg.sender].verificationCount = 0;

        emit BioUpdated(msg.sender, _newSyndrome, block.timestamp);
    }

    // 5. Проверить регистрацию
    function isUserRegistered(address _user) external view returns (bool) {
        return isRegistered[_user];
    }
}
```

### Dart Web3 сервис

```dart
// lib/services/blockchain_service.dart (IN PROGRESS)
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;

class BlockchainService {
  late Web3Client _web3Client;
  late ContractAbi _contractAbi;
  late EthereumAddress _contractAddress;
  late Credentials _credentials;

  final String rpcUrl = 'https://sepolia.infura.io/v3/YOUR_INFURA_KEY';
  final String contractAddressStr = '0x...'; // Развернутый контракт

  // Инициализация
  Future<void> initialize() async {
    try {
      _web3Client = Web3Client(rpcUrl, http.Client());
      
      // Загрузить ABI контракта
      _contractAbi = ContractAbi.fromJson(
        jsonDecode(BIOMETRIC_CONTRACT_ABI),
        'BioVaultID',
      );

      _contractAddress = EthereumAddress.fromHex(contractAddressStr);

      print("✓ Blockchain сервис инициализирован");
    } catch (e) {
      print("✗ Ошибка инициализации: $e");
      rethrow;
    }
  }

  // 1. Регистрация биометрии
  Future<String> registerBio(String syndrome, String ipfsCID) async {
    try {
      final function = _contractAbi.function('registerBio');

      final txHash = await _web3Client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: DeployedContract(_contractAbi, _contractAddress),
          function: function,
          parameters: [
            BigInt.parse(syndrome),
            ipfsCID,
          ],
        ),
      );

      print("✓ Регистрация отправлена. TxHash: $txHash");
      return txHash;
    } catch (e) {
      print("✗ Ошибка регистрации: $e");
      rethrow;
    }
  }

  // 2. Верификация лица
  Future<bool> verifyBio(String syndrome) async {
    try {
      final function = _contractAbi.function('verifyBio');

      await _web3Client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: DeployedContract(_contractAbi, _contractAddress),
          function: function,
          parameters: [
            BigInt.parse(syndrome),
          ],
        ),
      );

      print("✓ Верификация успешна");
      return true;
    } catch (e) {
      print("✗ Верификация ошибка: $e");
      return false;
    }
  }

  // 3. Получить данные пользователя
  Future<Map<String, dynamic>?> getUserData(String userAddress) async {
    try {
      final function = _contractAbi.function('getUserData');
      final addr = EthereumAddress.fromHex(userAddress);

      final result = await _web3Client.call(
        contract: DeployedContract(_contractAbi, _contractAddress),
        function: function,
        params: [addr],
      );

      return {
        'syndrome': result[0],
        'ipfsCID': result[1],
        'enrollmentTime': result[2],
        'lastVerification': result[3],
        'verificationCount': result[4],
        'registered': result[5],
      };
    } catch (e) {
      print("✗ Ошибка получения данных: $e");
      return null;
    }
  }

  void dispose() {
    _web3Client.dispose();
  }
}

const String BIOMETRIC_CONTRACT_ABI = '''
[
  {
    "inputs": [
      {"internalType": "bytes32", "name": "_faceSyndrome", "type": "bytes32"},
      {"internalType": "string", "name": "_ipfsCID", "type": "string"}
    ],
    "name": "registerBio",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "bytes32", "name": "_providedSyndrome", "type": "bytes32"}],
    "name": "verifyBio",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [{"internalType": "address", "name": "_user", "type": "address"}],
    "name": "getUserData",
    "outputs": [
      {"internalType": "bytes32", "name": "", "type": "bytes32"},
      {"internalType": "string", "name": "", "type": "string"},
      {"internalType": "uint256", "name": "", "type": "uint256"},
      {"internalType": "uint256", "name": "", "type": "uint256"},
      {"internalType": "uint256", "name": "", "type": "uint256"},
      {"internalType": "bool", "name": "", "type": "bool"}
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
''';
```

---

## Performance Metrics

| Компонент | Время | Примечание |
|-----------|-------|-----------|
| **MTCNN детекция** | 30-50ms | На GPU |
| **FaceNet embedding** | 50-100ms | На NPU/GPU |
| **Fuzzy Extractor** | ~10ms | Локальное вычисление |
| **IPFS upload** | 200-500ms | Зависит от сети |
| **IPFS download** | 100-300ms | Зависит от сети |
| **Blockchain verification** | 5-15s | Ждем подтверждения |
| **Полный цикл регистрации** | ~1-2s (локально) | Без blockchain |
| **Полный цикл верификации** | ~30s | С blockchain |

---

## Security Checklist

- [ ] Ключи хранятся в Secure Enclave (iOS) / Keystore (Android)
- [ ] Шифрование IPFS данных (AES-256-GCM)
- [ ] Подпись транзакций блокчейна
- [ ] Rate limiting для верификации
- [ ] Liveness detection (в разработке)
- [ ] Защита от MitM (HTTPS только)
- [ ] Регулярные аудиты безопасности

---

**Версия**: 1.0  
**Последнее обновление**: May 8, 2026
