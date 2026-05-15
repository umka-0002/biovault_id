import 'dart:convert';

/// Метаданные регистрации биометрического ключа
class EnrollmentMetadata {
  final DateTime enrollmentTime;
  final int framesCount;
  final double averageQuality;
  final String algorithmVersion;
  final Map<String, dynamic> additionalData;

  EnrollmentMetadata({
    required this.enrollmentTime,
    required this.framesCount,
    this.averageQuality = 0.0,
    this.algorithmVersion = '1.0.0',
    this.additionalData = const {},
  });

  Map<String, dynamic> toJson() => {
        'enrollmentTime': enrollmentTime.toIso8601String(),
        'framesCount': framesCount,
        'averageQuality': averageQuality,
        'algorithmVersion': algorithmVersion,
        'additionalData': additionalData,
      };

  String toBase64() {
    final jsonStr = jsonEncode(toJson());
    return base64Encode(utf8.encode(jsonStr));
  }

  factory EnrollmentMetadata.fromJson(Map<String, dynamic> json) =>
      EnrollmentMetadata(
        enrollmentTime: DateTime.parse(json['enrollmentTime'] as String),
        framesCount: json['framesCount'] as int,
        averageQuality: (json['averageQuality'] as num?)?.toDouble() ?? 0.0,
        algorithmVersion: json['algorithmVersion'] as String? ?? '1.0.0',
        additionalData:
            Map<String, dynamic>.from(json['additionalData'] as Map? ?? {}),
      );
}

/// Результат верификации биометрического ключа
class VerificationResult {
  final bool success;
  final String? recoveredKey;
  final int correctedErrors;
  final double embeddingDistance;
  final String? errorMessage;
  final int verificationTimeMs;

  VerificationResult({
    required this.success,
    this.recoveredKey,
    required this.correctedErrors,
    this.embeddingDistance = 0.0,
    this.errorMessage,
    required this.verificationTimeMs,
  });

  Map<String, dynamic> toJson() => {
        'success': success,
        'recoveredKey': recoveredKey,
        'correctedErrors': correctedErrors,
        'embeddingDistance': embeddingDistance,
        'errorMessage': errorMessage,
        'verificationTimeMs': verificationTimeMs,
      };

  factory VerificationResult.fromJson(Map<String, dynamic> json) =>
      VerificationResult(
        success: json['success'] as bool,
        recoveredKey: json['recoveredKey'] as String?,
        correctedErrors: json['correctedErrors'] as int,
        embeddingDistance: (json['embeddingDistance'] as num?)?.toDouble() ?? 0.0,
        errorMessage: json['errorMessage'] as String?,
        verificationTimeMs: json['verificationTimeMs'] as int,
      );
}

/// Fuzzy Key — результат работы Fuzzy Extractor
/// Содержит публичный синдром и приватный ключ
class FuzzyKey {
  final String publicSyndrome;
  final String privateKey;
  final DateTime enrollmentTime;
  final EnrollmentMetadata metadata;

  FuzzyKey({
    required this.publicSyndrome,
    required this.privateKey,
    required this.enrollmentTime,
    required this.metadata,
  });

  Map<String, dynamic> toJson() => {
        'publicSyndrome': publicSyndrome,
        'privateKey': privateKey,
        'enrollmentTime': enrollmentTime.toIso8601String(),
        'metadata': metadata.toJson(),
      };

  factory FuzzyKey.fromJson(Map<String, dynamic> json) => FuzzyKey(
        publicSyndrome: json['publicSyndrome'] as String,
        privateKey: json['privateKey'] as String,
        enrollmentTime: DateTime.parse(json['enrollmentTime'] as String),
        metadata:
            EnrollmentMetadata.fromJson(json['metadata'] as Map<String, dynamic>),
      );

  String toBase64() {
    final jsonStr = jsonEncode(toJson());
    return base64Encode(utf8.encode(jsonStr));
  }

  factory FuzzyKey.fromBase64(String base64Str) {
    final jsonStr = utf8.decode(base64Decode(base64Str));
    final jsonMap = jsonDecode(jsonStr) as Map<String, dynamic>;
    return FuzzyKey.fromJson(jsonMap);
  }
}
