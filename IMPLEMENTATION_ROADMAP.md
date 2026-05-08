# BioVault ID — Implementation Roadmap

## ✅ Завершено

### Phase 1: Edge AI (MTCNN + FaceNet)
- [x] `FaceRecognitionService` — основная логика
- [x] `face_recognition_service.dart` — инференс FaceNet
- [x] TensorFlow Lite интеграция
- [x] XNNPACK delegate (GPU ускорение)
- [x] Предобработка изображений

## 🔄 В разработке

### Phase 2: Fuzzy Extractor (Reed-Solomon)
- [ ] `FuzzyExtractorService` создание
- [ ] Reed-Solomon энкодирование
- [ ] Reed-Solomon декодирование с коррекцией
- [ ] Quantization / De-quantization
- [ ] Тестирование с реальными embeddings
- [ ] Выбор RS библиотеки (Dart)

### Phase 3: IPFS Integration
- [ ] `IPFSService` создание
- [ ] HTTP gateway конфигурация
- [ ] Upload зашифрованных данных
- [ ] Download и декрипт
- [ ] Error handling и retry logic

### Phase 4: Blockchain (Smart Contract)
- [ ] `BlockchainService` создание
- [ ] Смарт-контракт `BioVaultID.sol`
- [ ] Развертывание на тестовой сети (Sepolia)
- [ ] Web3 интеграция (web3dart)
- [ ] Транзакции и подписание

### Phase 5: UI Screens
- [ ] `CameraScreen` — захват видео и детекция
- [ ] `EnrollmentScreen` — процесс регистрации
- [ ] `VerificationScreen` — проверка лица
- [ ] `ProfileScreen` — профиль пользователя

## 📋 TODO: Подробный план

### 🎯 1. Fuzzy Extractor Service

**Файл**: `lib/services/fuzzy_extractor_service.dart`

```dart
class FuzzyExtractorService {
  // TODO: Реализовать
  Future<FuzzyKey> enroll(List<double> embedding) async {}
  Future<String?> verify(List<double> embedding, String syndrome) async {}
  List<int> _quantizeEmbedding(List<double> embedding) {}
  List<double> _dequantizeEmbedding(List<int> quantized) {}
  (String, String) _reedSolomonEncode(List<int> data) {}
  String? _reedSolomonDecode(List<int> received, String syndrome) {}
}
```

**Шаги**:
1. Выбрать RS библиотеку или написать свою
2. Реализовать quantization
3. Реализовать encode/decode
4. Добавить unit tests

**Выбор RS библиотеки**:
- Вариант A: `pointycastle` (если есть RS)
- Вариант B: Собственная реализация (контроль, но много кода)
- Вариант C: FFI wrapper на C/C++ библиотеку

### 🎯 2. IPFS Service

**Файл**: `lib/services/ipfs_service.dart`

```dart
class IPFSService {
  // TODO: Реализовать
  Future<String> uploadEncrypted(Map<String, dynamic> data) async {}
  Future<Map<String, dynamic>> downloadDecrypted(String cid) async {}
  Uint8List _encryptData(String data) {}
  String _decryptData(dynamic data) {}
}
```

**Шаги**:
1. Настроить IPFS daemon на локальной машине или использовать Infura
2. Реализовать AES-256-GCM шифрование
3. Добавить JSON сериализацию
4. Тестирование upload/download

### 🎯 3. Blockchain Service

**Файл**: `lib/services/blockchain_service.dart`

```dart
class BlockchainService {
  // TODO: Реализовать
  Future<void> initialize() async {}
  Future<String> registerBio(String syndrome, String ipfsCID) async {}
  Future<bool> verifyBio(String syndrome) async {}
  Future<Map<String, dynamic>?> getUserData(String address) async {}
}
```

**Шаги**:
1. Развернуть контракт на Sepolia testnet
2. Инициализировать web3dart клиент
3. Реализовать транзакции
4. Обработка gas fees
5. Error handling для блокчейн операций

### 🎯 4. UI Screens

#### 4.1 CameraScreen
**Файл**: `lib/ui/screens/camera_screen.dart`

```dart
class CameraScreen extends StatefulWidget {
  // TODO:
  // 1. camera plugin интеграция
  // 2. Видеопоток в реальном времени
  // 3. MTCNN детекция лица
  // 4. Отрисовка bounding box
  // 5. Кнопка захвата кадра
}
```

#### 4.2 EnrollmentScreen
**Файл**: `lib/ui/screens/enrollment_screen.dart`

```dart
class EnrollmentScreen extends StatefulWidget {
  // TODO:
  // 1. Захват N кадров лица
  // 2. Прогресс индикатор
  // 3. Fuzzy Extractor интеграция
  // 4. IPFS upload
  // 5. Blockchain публикация
}
```

#### 4.3 VerificationScreen
**Файл**: `lib/ui/screens/verification_screen.dart`

```dart
class VerificationScreen extends StatefulWidget {
  // TODO:
  // 1. Сканирование лица
  // 2. Fuzzy Extractor верификация
  // 3. Blockchain проверка
  // 4. Результат (✓ успех / ✗ ошибка)
}
```

---

## 🧪 Testing Plan

### Unit Tests
- [ ] `test/services/face_recognition_service_test.dart`
  - Тестирование загрузки модели
  - Тестирование инференса
  - Тестирование нормализации

- [ ] `test/services/fuzzy_extractor_service_test.dart`
  - Тестирование quantization
  - Тестирование RS encode/decode
  - Тестирование коррекции ошибок

- [ ] `test/services/ipfs_service_test.dart`
  - Mock IPFS тесты
  - Шифрование/дешифрование

### Integration Tests
- [ ] Full enrollment flow
- [ ] Full verification flow
- [ ] Recovery scenario

### Performance Tests
- [ ] Embedding generation speed
- [ ] Fuzzy Extractor latency
- [ ] IPFS operations speed

---

## 📦 Dependencies to Add

### pubspec.yaml updates
```yaml
dependencies:
  # Existing
  flutter:
    sdk: flutter
  cupertino_icons: ^1.0.8
  tflite_flutter: ^0.10.4
  image: ^4.0.17
  web3dart: ^2.7.3
  http: ^1.1.0
  dio: ^5.3.0

  # NEW: For Fuzzy Extractor
  pointycastle: ^3.6.2           # Cryptographic operations
  crypto: ^3.0.2                 # SHA-256, etc.

  # NEW: For secure storage
  flutter_secure_storage: ^9.0.0 # Secure Enclave (iOS) / Keystore (Android)

  # NEW: For utilities
  json_annotation: ^4.8.0        # JSON serialization
  get_it: ^7.6.0                 # Service locator

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
  
  # NEW: Testing
  mockito: ^5.4.0
  build_runner: ^2.4.0
```

---

## 🏗️ Architecture Overview (Layers)

```
┌─────────────────────────────────────────────────────────┐
│                   UI Layer                              │
│     (Screens, Widgets, State Management)                │
├─────────────────────────────────────────────────────────┤
│                   Service Layer                         │
│  ┌─────────────┬──────────┬────────┬──────────────┐    │
│  │ Face        │ Fuzzy    │ IPFS   │ Blockchain   │    │
│  │ Recognition │ Extractor│ Service│ Service      │    │
│  └─────────────┴──────────┴────────┴──────────────┘    │
├─────────────────────────────────────────────────────────┤
│                   ML / Crypto Layer                     │
│  ┌──────────┬────────────┬──────────┬────────────┐     │
│  │TensorFlow│Reed-Solomon│ AES-256  │Web3Dart    │     │
│  │Lite      │Codes       │ GCM      │ Client     │     │
│  └──────────┴────────────┴──────────┴────────────┘     │
├─────────────────────────────────────────────────────────┤
│                   External Layer                        │
│  ┌──────────────┬──────────────┬──────────────────┐    │
│  │ TFLite Models│ IPFS Node    │ EVM Blockchain   │    │
│  │ (Local)      │ (HTTP API)   │ (Infura/Alchemy) │    │
│  └──────────────┴──────────────┴──────────────────┘    │
└─────────────────────────────────────────────────────────┘
```

---

## 🔐 Security Considerations

### Key Storage
- [ ] iOS: Secure Enclave через `flutter_secure_storage`
- [ ] Android: Android Keystore через `flutter_secure_storage`
- [ ] Never log private keys
- [ ] Clear sensitive data from memory

### Network Security
- [ ] HTTPS only for HTTP requests
- [ ] Certificate pinning (опционально)
- [ ] Rate limiting for blockchain calls

### Data Privacy
- [ ] Encrypt all IPFS uploads
- [ ] No facial images transmitted
- [ ] Embeddings only shared via Fuzzy Extractor

---

## 📱 Platform-Specific Tasks

### Android
- [ ] Configure XNNPACK in `build.gradle.kts`
- [ ] Request camera permissions in `AndroidManifest.xml`
- [ ] Test on real Android device with NPU

### iOS
- [ ] Configure GPU delegate in Podfile
- [ ] NSCameraUsageDescription in `Info.plist`
- [ ] Test on real iPhone with Neural Engine

### Web (Optional)
- [ ] WASM support for TensorFlow Lite
- [ ] WebXR for camera access
- [ ] LocalStorage for keys

---

## 🚀 Deployment Timeline

| Phase | Timeline | Milestone |
|-------|----------|-----------|
| Phase 1: Edge AI | Week 1-2 | ✓ Done |
| Phase 2: Fuzzy Extractor | Week 3-4 | In Progress |
| Phase 3: IPFS | Week 5-6 | Planned |
| Phase 4: Blockchain | Week 7-8 | Planned |
| Phase 5: UI | Week 9-10 | Planned |
| Phase 6: Testing | Week 11-12 | Planned |
| Phase 7: Testnet Release | Week 13-14 | Planned |
| Phase 8: Mainnet Ready | Week 15-16 | Planned |

---

## 📞 Support & Resources

### Documentation
- [Flutter Docs](https://flutter.dev/docs)
- [TensorFlow Lite Guide](https://www.tensorflow.org/lite/guide)
- [Reed-Solomon Wiki](https://en.wikipedia.org/wiki/Reed%E2%80%93Solomon_error_correction)
- [IPFS Docs](https://docs.ipfs.io/)
- [Solidity Docs](https://docs.soliditylang.org/)
- [web3dart API](https://pub.dev/packages/web3dart)

### Research Papers
- FaceNet: [arxiv.org/abs/1503.03832](https://arxiv.org/abs/1503.03832)
- Fuzzy Extractor: [eprint.iacr.org/2014/507](https://eprint.iacr.org/2014/507)
- Reed-Solomon: [IEEE Transactions](...)

---

## 🎓 Team Skills Needed

- [ ] Flutter Developer (UI/UX)
- [ ] ML Engineer (TensorFlow optimization)
- [ ] Cryptographer (Fuzzy Extractor, RS codes)
- [ ] Backend Engineer (IPFS, Blockchain)
- [ ] DevOps (Deployment, Monitoring)
- [ ] QA Engineer (Testing)
- [ ] Security Auditor

---

**Version**: 1.0  
**Last Updated**: May 8, 2026  
**Status**: 🔄 In Active Development
