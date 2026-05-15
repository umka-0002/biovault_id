import 'dart:math';

/// Запись о доступе к зашифрованным данным
class AccessGrant {
  final String dataId;
  final String userId;
  final String encryptionKey; // Хранится в контракте
  final DateTime grantedAt;
  DateTime? revokedAt;
  AccessStatus status;

  AccessGrant({
    required this.dataId,
    required this.userId,
    required this.encryptionKey,
    required this.grantedAt,
    this.status = AccessStatus.granted,
  });

  /// Отозвать доступ (уничтожить ключ)
  void revoke() {
    revokedAt = DateTime.now();
    status = AccessStatus.revoked;
  }

  /// Проверить, активен ли доступ
  bool isActive() => status == AccessStatus.granted;

  /// Получить статус как строку
  String getStatusText() {
    switch (status) {
      case AccessStatus.granted:
        return '✅ Active';
      case AccessStatus.revoked:
        return '❌ Revoked';
      case AccessStatus.expired:
        return '⏰ Expired';
    }
  }

  /// Получить краткий ID данных
  String getDataIdShort() =>
      dataId.length > 16 ? '${dataId.substring(0, 16)}...' : dataId;

  /// Получить краткий ключ
  String getKeyShort() =>
      encryptionKey.length > 16
          ? '${encryptionKey.substring(0, 16)}...'
          : encryptionKey;
}

/// Статус разрешения доступа
enum AccessStatus { granted, revoked, expired }

/// DataRevokeService — управление правами доступа с криптографическим удалением
/// Реализует схему: данные -> шифрование -> ключ -> отзыв -> шум
class DataRevokeService {
  /// Хранилище активных разрешений доступа
  final Map<String, AccessGrant> _activeGrants = {};
  final List<AccessGrant> _revokedGrants = [];

  /// Получить все активные разрешения
  List<AccessGrant> getActiveGrants() => _activeGrants.values.toList();

  /// Получить все отозванные разрешения (история)
  List<AccessGrant> getRevokedGrants() => _revokedGrants.toList();

  /// Создать новое разрешение доступа (имитация шифрования данных)
  AccessGrant createAccessGrant({
    required String dataId,
    required String userId,
    String? encryptionKey,
  }) {
    final key = encryptionKey ?? _generateEncryptionKey();
    final grant = AccessGrant(
      dataId: dataId,
      userId: userId,
      encryptionKey: key,
      grantedAt: DateTime.now(),
    );
    _activeGrants[dataId] = grant;
    return grant;
  }

  /// Отозвать доступ (криптографическое удаление ключа)
  AccessGrant? revokeAccess(String dataId) {
    final grant = _activeGrants.remove(dataId);
    if (grant != null) {
      grant.revoke();
      _revokedGrants.add(grant);
      return grant;
    }
    return null;
  }

  /// Проверить, активен ли доступ к данным
  bool canAccess(String dataId) {
    return _activeGrants[dataId]?.isActive() ?? false;
  }

  /// Получить ключ расшифровки (только если доступ активен)
  String? getDecryptionKey(String dataId) {
    if (canAccess(dataId)) {
      return _activeGrants[dataId]!.encryptionKey;
    }
    return null;
  }

  /// Очистить все разрешения и историю (для тестирования)
  void clearAll() {
    _activeGrants.clear();
    _revokedGrants.clear();
  }

  /// Сгенерировать случайный AES-256 ключ (для демонстрации)
  static String _generateEncryptionKey() {
    final random = List<int>.generate(32, (i) => Random().nextInt(256));
    return random.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  }

  /// Демонстрация: зашифрованные данные без ключа = шум
  static String demonstrateDataAsNoise() {
    const String originalData =
        'BioVault ID: User123 Face Embedding: [0.1, 0.5, ...]';
    const String encryptedData =
        'gH7kLp9mQ2rW5vX8yZ1aBcDeFgHiJkLmNoPqRsTuVwXyZ0aBcDeFgHiJkLmNoPq';
    const String encryptionKey = 'AES256KEY_12345678901234567890AB';

    return '''
📋 ДЕМОНСТРАЦИЯ: Биометрические данные как шум в блокчейне
════════════════════════════════════════════════════════

1️⃣ ИСХОДНЫЕ ДАННЫЕ (конфиденциальны):
   $originalData

2️⃣ ЗАШИФРОВАННЫЕ ДАННЫЕ (в блокчейне):
   $encryptedData
   
3️⃣ КЛЮЧ РАСШИФРОВКИ (в смарт-контракте):
   $encryptionKey ✅ АКТИВЕН
   
════════════════════════════════════════════════════════
⚠️ ОТЗЫВ ДОСТУПА (revoke permission)
════════════════════════════════════════════════════════

❌ ЧТО ПРОИСХОДИТ:
   • Смарт-контракт вызывает: delete encryptionKeys[dataId]
   • Ключ НАВСЕГДА удален из блокчейна
   • Операция необратима (криптографически)
   • Историю удаления нельзя изменить

🎯 РЕЗУЛЬТАТ:
   Зашифрованные данные: $encryptedData
   Ключ: [УДАЛЕН] ❌
   
   💥 Данные стали БЕСПОЛЕЗНЫМ ШУМОМ
   
🔒 ГАРАНТИЯ КОНФИДЕНЦИАЛЬНОСТИ:
   • Даже если кто-то украдет зашифрованные данные из блокчейна
   • Без ключа их невозможно расшифровать
   • Попытка перебрать ключи: 2^256 попыток (~невозможно)
    ''';
  }
}

