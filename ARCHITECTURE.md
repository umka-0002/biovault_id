# BioVault ID — Архитектура децентрализованной экосистемы

## Обзор проекта

**BioVault ID** — это полноценный Full-stack Web3 проект, который реализует децентрализованную систему биометрической идентификации на основе лиц. Система состоит из **пяти критически важных уровней**, каждый из которых решает свою задачу.

> **Ключевой принцип**: Лицо пользователя никогда не покидает его телефон. Все вычисления происходят локально, на устройстве.

---

## Пять уровней архитектуры

```
┌─────────────────────────────────────────────────────────────┐
│ 1. FRONTEND (Клиент)                                        │
│    Flutter app (iOS/Android) — Единственное место,          │
│    где "живет" лицо пользователя                            │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│ 2. EDGE AI (Интеллект)                                      │
│    TensorFlow Lite внутри телефона                          │
│    • MTCNN — детекция лица                                 │
│    • FaceNet — создание эмбеддинга (цифровой отпечаток)   │
└──────────────────┬──────────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────────┐
│ 3. FUZZY EXTRACTOR (Криптографический мост)                │
│    Коды Рида-Соломона: "шумный" вектор → стабильный ключ   │
│    Это делает систему научной, а не просто приложением     │
└──────────────────┬──────────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
┌───────▼──────┐      ┌──────▼────────┐
│ 4. IPFS      │      │ 5. BLOCKCHAIN │
│ Хранилище    │      │ Реестр и      │
│ Зашифр. дан. │      │ логика        │
└──────────────┘      └───────────────┘
```

---

## 1. Frontend (Клиент) — Flutter

### Назначение
Кроссплатформенное мобильное приложение, которое:
- Захватывает видеопоток с камеры
- Запускает локальные нейросети
- Управляет приватными ключами
- Взаимодействует с IPFS и блокчейном

### Поддерживаемые платформы
- **iOS** — через AppDelegate + Swift-интеграция
- **Android** — через MainActivity + Kotlin-интеграция
- **Web** (опционально)
- **Desktop** (Linux, macOS, Windows)

### Технологический стек
```yaml
Flutter: ^3.11.5
TensorFlow Lite: tflite_flutter ^0.10.4
Image Processing: image ^4.0.17
Web3 Integration: web3dart ^2.7.3
HTTP Client: dio ^5.3.0
```

### Структура приложения
```
lib/
├── main.dart                          # Точка входа
├── services/
│   ├── face_recognition_service.dart # Edge AI оркестратор
│   ├── fuzzy_extractor_service.dart   # Криптографический мост
│   ├── ipfs_service.dart              # IPFS интеграция
│   ├── blockchain_service.dart        # Blockchain взаимодействие
│   └── biometric_auth_service.dart    # Биометрическая аутентификация
├── models/
│   ├── user_profile.dart
│   ├── face_embedding.dart
│   └── blockchain_transaction.dart
├── ui/
│   ├── screens/
│   │   ├── camera_screen.dart
│   │   ├── verification_screen.dart
│   │   └── profile_screen.dart
│   └── widgets/
└── utils/
    ├── crypto_utils.dart
    └── constants.dart
```

---

## 2. Edge AI (Интеллект) — TensorFlow Lite

### Назначение
Локальная обработка изображений лица на телефоне. **Ни одна фотография не отправляется на сервер**.

### Компоненты

#### 2.1 MTCNN (Multi-Task Cascaded Convolutional Networks)
- **Задача**: Обнаружение лица на изображении
- **Вход**: Видеокадр (любой размер)
- **Выход**: Координаты лица, ключевые точки (глаза, нос, рот)
- **Оптимизация**: XNNPACK delegate для NPU/GPU на мобильных процессорах

#### 2.2 FaceNet
- **Задача**: Преобразование лица в 128/512-мерный вектор (embedding)
- **Вход**: Кроп лица 160×160px (нормализованное)
- **Выход**: Вектор чисел с плавающей запятой (эмбеддинг)
- **Свойство**: Два похожих лица → похожие вектора

### Предобработка изображения
```
Видеокадр → MTCNN → Кроп лица → Resize (160×160) → 
Нормализация (pixel - 127.5) / 128.0 → Float32 тензор
```

### Текущая реализация
Файл: [lib/services/face_recognition_service.dart](lib/services/face_recognition_service.dart)

```dart
// Загрузка модели с ускорением на мобильных NPU
Future<void> loadModel() async {
  final options = InterpreterOptions();
  if (Platform.isAndroid) {
    options.addDelegate(XNNPackDelegate()); // GPU/NPU ускорение
  }
  _interpreter = await Interpreter.fromAsset(
    'assets/models/facenet.tflite',
    options: options,
  );
}

// Получение эмбеддинга
List<double> predict(img.Image faceImage) {
  // Предобработка → нейросеть → вектор
  var output = List.filled(1 * 128, 0.0).reshape([1, 128]);
  _interpreter!.run(input, output);
  return List<double>.from(output[0]); // 128-мерный вектор
}
```

---

## 3. Fuzzy Extractor (Криптографический мост)

### Назначение
Это самый инновационный компонент системы. Решает проблему: **биометрия "шумная"**.

### Проблема
- FaceNet выдает вектор **~0.95 сходства** при повторном сканировании одного и того же лица
- Невозможно использовать вектор напрямую как ключ
- Нужен способ превратить "шумный" вектор в **стабильный криптографический ключ**

### Решение: Fuzzy Extractor на базе кодов Рида-Соломона

#### Фаза регистрации:
```
1. Захватить лицо N раз → N векторов (слегка отличаются)
2. Вычислить средний вектор (helper data)
3. Применить Reed-Solomon код:
   - Входные данные: средний вектор (шумный)
   - Выход: криптографический ключ K (256 бит, стабильный)
   - Сохранить: публичный "синдром" (опубликовать в blockchain)
```

#### Фаза верификации:
```
1. Захватить лицо → новый вектор (немного отличается)
2. Применить Reed-Solomon:
   - Входные данные: новый вектор + синдром из blockchain
   - Выход: ТОТЖЕ ключ K (если лицо соответствует)
   - Ошибка: если лицо чужого человека
```

#### Параметры кода Рида-Соломона:
```
n = 256 (длина кода)
k = 128 (информационные символы)
t = 64  (коррекция ошибок)
```

### Реализация (псевдокод на Dart)
```dart
class FuzzyExtractorService {
  // Енролмент: привязка лица к ключу
  Future<String> enroll(List<double> faceEmbedding) async {
    // 1. Создать helper data
    final helperData = _generateHelperData(faceEmbedding);
    
    // 2. Применить Reed-Solomon
    final (key, publicSyndrome) = 
      _reedSolomonEncode(faceEmbedding, helperData);
    
    // 3. Сохранить в blockchain
    await _publishToBlockchain(publicSyndrome);
    
    // 4. Возвернуть приватный ключ
    return key;
  }

  // Верификация: проверить лицо и получить ключ
  Future<String?> verify(List<double> newEmbedding) async {
    // 1. Загрузить синдром из blockchain
    final syndrome = await _loadFromBlockchain();
    
    // 2. Применить Reed-Solomon с коррекцией
    final key = _reedSolomonDecode(newEmbedding, syndrome);
    
    // 3. Если ошибок в пределах t, ключ восстановлен
    return key; // или null, если слишком много ошибок
  }
}
```

---

## 4. IPFS (Децентрализованное хранилище)

### Назначение
Хранить зашифрованные вспомогательные данные системы для восстановления доступа.

### Что хранится в IPFS
```
{
  "user_id": "hash(公钥)",
  "enrollment_data": "encrypted_helper_data",
  "backup_keys": "encrypted_backup_seed",
  "version": "1.0",
  "timestamp": 1234567890,
  "checksum": "sha256_hash"
}
```

### Сценарий восстановления
```
Пользователь потерял телефон
    ↓
Восстановил приложение на новом телефоне
    ↓
Загрузил зашифрованные данные из IPFS
    ↓
Сканировал лицо + Fuzzy Extractor восстановил ключ
    ↓
Расшифровал данные (PubSub подпись от Fuzzy Extractor)
    ↓
✓ Доступ восстановлен
```

### Интеграция
```dart
class IPFSService {
  final Dio _httpClient; // HTTP gateway к IPFS узлу

  // Загрузить данные
  Future<String> upload(Map<String, dynamic> data) async {
    final encrypted = _encryptData(data);
    final response = await _httpClient.post(
      'http://localhost:5001/api/v0/add',
      data: encrypted,
    );
    return response.data['Hash']; // IPFS CID
  }

  // Скачать данные
  Future<Map> download(String cid) async {
    final response = await _httpClient.get(
      'http://localhost:8080/ipfs/$cid',
    );
    return _decryptData(response.data);
  }
}
```

---

## 5. Blockchain (Реестр и логика)

### Назначение
Хранить анонимный реестр пользователей и логику умного контракта. **Это "бэкенд", который нельзя взломать или подделать**.

### Солидити смарт-контракт (EVM-сеть)

#### Основная структура:
```solidity
contract BioVaultID {
  // Синдром: публичный хеш лица пользователя
  mapping(address => bytes32) public faceSyndrome;
  
  // IPFS CID вспомогательных данных
  mapping(address => string) public ipfsCID;
  
  // История верификации (для аналитики)
  mapping(address => uint256) public lastVerificationTime;
  mapping(address => uint256) public verificationCount;

  // Событие: лицо пользователя зарегистрировано
  event BioRegistered(address indexed user, bytes32 syndrome, string ipfs);
  
  // Событие: верификация произошла
  event VerificationSuccess(address indexed user, uint256 timestamp);

  // Регистрация: публикация синдрома
  function registerBio(
    bytes32 _syndrome,
    string memory _ipfsCID
  ) external {
    require(faceSyndrome[msg.sender] == 0, "Already registered");
    faceSyndrome[msg.sender] = _syndrome;
    ipfsCID[msg.sender] = _ipfsCID;
    emit BioRegistered(msg.sender, _syndrome, _ipfsCID);
  }

  // Верификация: проверить синдром + обновить счетчик
  function verifyBio(bytes32 _providedSyndrome) external {
    require(faceSyndrome[msg.sender] != 0, "Not registered");
    require(faceSyndrome[msg.sender] == _providedSyndrome, "Verification failed");
    
    lastVerificationTime[msg.sender] = block.timestamp;
    verificationCount[msg.sender]++;
    emit VerificationSuccess(msg.sender, block.timestamp);
  }

  // Получить данные пользователя
  function getUserData(address _user) external view returns (
    bytes32 syndrome,
    string memory ipfs,
    uint256 lastVerification,
    uint256 totalVerifications
  ) {
    return (
      faceSyndrome[_user],
      ipfsCID[_user],
      lastVerificationTime[_user],
      verificationCount[_user]
    );
  }
}
```

### Взаимодействие с контрактом (Dart)
```dart
class BlockchainService {
  late EthereumAddress _contractAddress;
  late Credentials _credentials;

  // Публикация синдрома
  Future<String> registerBio(
    String syndrome,
    String ipfsCID,
  ) async {
    final function = _contract.function('registerBio');
    final txHash = await _client.sendTransaction(
      _credentials,
      Transaction.callContract(
        contract: _contract,
        function: function,
        parameters: [
          BigInt.parse(syndrome),
          ipfsCID,
        ],
      ),
    );
    return txHash;
  }

  // Верификация
  Future<bool> verifyBio(String providedSyndrome) async {
    final function = _contract.function('verifyBio');
    try {
      await _client.sendTransaction(
        _credentials,
        Transaction.callContract(
          contract: _contract,
          function: function,
          parameters: [BigInt.parse(providedSyndrome)],
        ),
      );
      return true;
    } catch (e) {
      return false;
    }
  }
}
```

### Сетевые параметры
- **Блокчейн**: EVM-совместимая сеть (Ethereum, Polygon, Arbitrum и т.д.)
- **Gas оптимизация**: Используем события для логирования вместо хранения всей истории
- **Конфиденциальность**: Хранимы только хеши, не сами синдромы напрямую

---

## Полный поток данных

### Сценарий 1: Первая регистрация

```
Пользователь открывает приложение
  ↓
[Frontend] Запрос доступа к камере
  ↓
[Edge AI] MTCNN детектирует лицо
  ↓
[Edge AI] FaceNet создает embedding (128-мер вектор)
  ↓
[Fuzzy Extractor] Повтор N раз, создание helper data
  ↓
[Fuzzy Extractor] Reed-Solomon encode → публичный синдром + приватный ключ
  ↓
[IPFS] Загрузка зашифрованного helper data → CID
  ↓
[Blockchain] Публикация синдрома + IPFS CID
  ↓
✓ Пользователь зарегистрирован
```

### Сценарий 2: Вход в систему

```
Пользователь сканирует лицо
  ↓
[Edge AI] MTCNN детектирует, FaceNet создает embedding
  ↓
[Blockchain] Загрузить публичный синдром пользователя
  ↓
[Fuzzy Extractor] Reed-Solomon decode (новый embedding + синдром)
  ↓
Если коррекция ошибок удалась:
  → Восстановлен приватный ключ
  ↓
[Blockchain] Отправить транзакцию verifyBio(syndrome)
  ↓
✓ Пользователь аутентифицирован
```

### Сценарий 3: Восстановление доступа

```
Потерян телефон → установлено приложение на новом
  ↓
[Frontend] Восстановление: введите адрес wallet
  ↓
[IPFS] Загрузить helper data по CID из blockchain
  ↓
[Frontend] Сканируем лицо (биометрия может немного отличаться)
  ↓
[Fuzzy Extractor] Reed-Solomon decode с коррекцией ошибок
  ↓
✓ Ключ восстановлен, полный доступ к аккаунту
```

---

## Безопасность и приватность

### ✓ Что защищено
| Компонент | Защита |
|-----------|--------|
| **Лицо** | Никогда не покидает телефон |
| **Embedding** | Локально обрабатывается, не хранится |
| **Синдром** | Публичный хеш в blockchain, нельзя восстановить лицо |
| **IPFS данные** | Зашифрованы приватным ключом |
| **Ключи** | Хранятся в Secure Enclave (iOS) / Keystore (Android) |

### ✗ Угрозы и вектора атак
| Угроза | Защита |
|--------|--------|
| Перехват фото по сети | Нет передачи фото — только вычисления |
| Brute-force синдрома | Blockchain хеш необратим (one-way) |
| Кража IPFS данных | Зашифрованы, ключ восстанавливается только через Fuzzy Extractor |
| Замена лица (spoofing) | Liveness detection (в разработке) |
| Потеря телефона | IPFS резервная копия + Fuzzy Extractor восстановление |

---

## Развертывание

### Требования к среде

#### Frontend
- Flutter SDK ≥ 3.11
- Android SDK ≥ 21
- Xcode ≥ 14

#### Edge AI
- TensorFlow Lite модели в `assets/models/`
- XNNPACK delegate (встроен в TFLite)

#### IPFS
- IPFS daemon (локальный узел или Infura gateway)
- Порт 5001 (API) и 8080 (Gateway)

#### Blockchain
- Мобильная Web3 библиотека (`web3dart`)
- RPC endpoint (Infura, Alchemy или собственный)
- Deployed контракт на EVM-сети

### Шаги установки

```bash
# 1. Клонировать репозиторий
git clone https://github.com/yourusername/biovault_id.git
cd biovault_id

# 2. Установить зависимости Flutter
flutter pub get

# 3. Запустить на Android
flutter run -d <device_id>

# 4. Запустить на iOS
flutter run -d <device_id>
```

---

## Roadmap

- [ ] Фаза 1: Edge AI (FaceNet + MTCNN)
- [ ] Фаза 2: Fuzzy Extractor (Reed-Solomon)
- [ ] Фаза 3: IPFS интеграция
- [ ] Фаза 4: Blockchain контракт
- [ ] Фаза 5: Liveness detection
- [ ] Фаза 6: Multi-signature recovery
- [ ] Фаза 7: Mainnet deployment

---

## Ссылки

- [TensorFlow Lite](https://www.tensorflow.org/lite)
- [FaceNet Paper](https://arxiv.org/abs/1503.03832)
- [Reed-Solomon Codes](https://en.wikipedia.org/wiki/Reed%E2%80%93Solomon_error_correction)
- [IPFS Documentation](https://docs.ipfs.io/)
- [Solidity Smart Contracts](https://docs.soliditylang.org/)
- [web3dart Library](https://pub.dev/packages/web3dart)

---

**Версия**: 1.0  
**Последнее обновление**: May 8, 2026  
**Статус**: In Development
