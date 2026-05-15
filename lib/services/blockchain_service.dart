import 'dart:typed_data';

import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class BlockchainService {
  late final Web3Client _client;
  late final EthPrivateKey _credentials;
  DeployedContract? _contract;
  EthereumAddress? _contractAddress;

  BlockchainService();

  Future<void> initialize({
    required String rpcUrl,
    required String privateKey,
    String? contractAddress,
  }) async {
    _client = Web3Client(rpcUrl, Client());
    _credentials = EthPrivateKey.fromHex(privateKey);
    if (contractAddress != null) {
      await setContractAddress(contractAddress);
    }
  }

  Future<void> setContractAddress(String contractAddress) async {
    _contractAddress = EthereumAddress.fromHex(contractAddress);
    _contract = DeployedContract(
      ContractAbi.fromJson(_contractAbi, 'BioVaultID'),
      _contractAddress!,
    );
  }

  EthereumAddress get walletAddress => _credentials.address;

  Future<String> deployContract(String bytecode) async {
    final txHash = await _client.sendTransaction(
      _credentials,
      Transaction(
        data: hexToBytes(bytecode),
        maxGas: 6_000_000,
      ),
      fetchChainIdFromNetworkId: true,
    );

    final receipt = await _client.getTransactionReceipt(txHash);
    if (receipt == null || receipt.contractAddress == null) {
      throw Exception('Contract deployment did not return an address');
    }

    await setContractAddress(receipt.contractAddress!.hex);
    return receipt.contractAddress!.hex;
  }

  Future<String?> registerBio(String syndrome, String cid) async {
    if (_contract == null) return null;
    final registerFunction = _contract!.function('registerBio');

    final tx = Transaction.callContract(
      contract: _contract!,
      function: registerFunction,
      parameters: [syndrome, cid],
      from: _credentials.address,
    );

    final hash = await _client.sendTransaction(
      _credentials,
      tx,
      fetchChainIdFromNetworkId: true,
    );

    return hash;
  }

  Future<String?> verifyBio(String syndrome) async {
    if (_contract == null) return null;
    final verifyFunction = _contract!.function('verifyBio');

    final tx = Transaction.callContract(
      contract: _contract!,
      function: verifyFunction,
      parameters: [syndrome],
      from: _credentials.address,
    );

    final hash = await _client.sendTransaction(
      _credentials,
      tx,
      fetchChainIdFromNetworkId: true,
    );

    return hash;
  }

  Future<Map<String, dynamic>?> getUserData(String userAddress) async {
    if (_contract == null) return null;
    final getUserFunction = _contract!.function('getUserData');
    final result = await _client.call(
      contract: _contract!,
      function: getUserFunction,
      params: [EthereumAddress.fromHex(userAddress)],
    );
    if (result.isEmpty) return null;
    return {
      'syndrome': result[0] as String,
      'cid': result[1] as String,
      'lastVerification': result[2] as BigInt,
      'totalVerifications': result[3] as BigInt,
    };
  }

  Uint8List hexToBytes(String hex) {
    final normalized = hex.replaceAll('0x', '').replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      final byte = normalized.substring(i, i + 2);
      bytes.add(int.parse(byte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  static const String _contractAbi = '''
[
  {
    "inputs": [
      {"internalType": "string", "name": "_syndrome", "type": "string"},
      {"internalType": "string", "name": "_ipfsCID", "type": "string"}
    ],
    "name": "registerBio",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "string", "name": "_providedSyndrome", "type": "string"}
    ],
    "name": "verifyBio",
    "outputs": [],
    "stateMutability": "nonpayable",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "_user", "type": "address"}
    ],
    "name": "getUserData",
    "outputs": [
      {"internalType": "string", "name": "syndrome", "type": "string"},
      {"internalType": "string", "name": "ipfs", "type": "string"},
      {"internalType": "uint256", "name": "lastVerification", "type": "uint256"},
      {"internalType": "uint256", "name": "totalVerifications", "type": "uint256"}
    ],
    "stateMutability": "view",
    "type": "function"
  }
]
''';
}
