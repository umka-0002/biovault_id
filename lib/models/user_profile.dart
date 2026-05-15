class UserProfile {
  final String userId;
  final String walletAddress;
  final String? syndrome;
  final String? ipfsCid;
  final DateTime registeredAt;

  UserProfile({
    required this.userId,
    required this.walletAddress,
    this.syndrome,
    this.ipfsCid,
    required this.registeredAt,
  });

  Map<String, dynamic> toJson() {
    return {
      'userId': userId,
      'walletAddress': walletAddress,
      'syndrome': syndrome,
      'ipfsCid': ipfsCid,
      'registeredAt': registeredAt.toIso8601String(),
    };
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      userId: json['userId'] as String,
      walletAddress: json['walletAddress'] as String,
      syndrome: json['syndrome'] as String?,
      ipfsCid: json['ipfsCid'] as String?,
      registeredAt: DateTime.parse(json['registeredAt'] as String),
    );
  }
}
