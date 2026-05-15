class FaceEmbedding {
  final List<double> vector;
  final DateTime createdAt;

  FaceEmbedding({required this.vector, DateTime? createdAt})
      : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'vector': vector,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory FaceEmbedding.fromJson(Map<String, dynamic> json) {
    return FaceEmbedding(
      vector: List<double>.from(json['vector'] as List<dynamic>),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}
