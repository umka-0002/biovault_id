class BlockchainTransaction {
  final String txHash;
  final int? blockNumber;
  final bool success;
  final DateTime createdAt;

  BlockchainTransaction({
    required this.txHash,
    this.blockNumber,
    required this.success,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}
