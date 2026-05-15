import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart';
import 'package:web3dart/web3dart.dart';

class BlockchainService {
  late final Web3Client? _client;
  late final EthPrivateKey? _credentials;
  DeployedContract? _contract;
  EthereumAddress? _contractAddress;
  
  bool _isTestMode = false;
  final Map<String, Map<String, dynamic>> _mockStorage = {};

  BlockchainService({bool testMode = true}) : _isTestMode = testMode;

  Future<void> initialize({
    String? rpcUrl,
    String? privateKey,
    String? contractAddress,
  }) async {
    if (_isTestMode) {
      print("BlockchainService initialized in TEST MODE");
      return;
    }
    
    if (rpcUrl != null && privateKey != null) {
      _client = Web3Client(rpcUrl, Client());
      _credentials = EthPrivateKey.fromHex(privateKey);
      if (contractAddress != null) {
        await setContractAddress(contractAddress);
      }
    }
  }
  
  // ... rest of the existing methods but with test mode checks ...

  Future<String?> registerBio(String syndrome, String cid) async {
    if (_isTestMode) {
      final mockAddress = "0x71C7656EC7ab88b098defB751B7401B5f6d8976F"; // Demo address
      _mockStorage[mockAddress] = {
        'syndrome': syndrome,
        'cid': cid,
        'lastVerification': BigInt.from(DateTime.now().millisecondsSinceEpoch ~/ 1000),
        'totalVerifications': BigInt.zero,
      };
      print("Mock Blockchain: Registered bio for $mockAddress");
      return "0x_mock_tx_hash_${DateTime.now().millisecondsSinceEpoch}";
    }
    // Real implementation follows...
    if (_contract == null) return null;
    final registerFunction = _contract!.function('registerBio');

    final tx = Transaction.callContract(
      contract: _contract!,
      function: registerFunction,
      parameters: [syndrome, cid],
      from: _credentials!.address,
    );

    final hash = await _client!.sendTransaction(
      _credentials!,
      tx,
      fetchChainIdFromNetworkId: true,
    );

    return hash;
  }

  Future<String?> verifyBio(String syndrome) async {
    if (_isTestMode) {
      print("Mock Blockchain: Verified syndrome $syndrome");
      return "0x_mock_verify_hash_${DateTime.now().millisecondsSinceEpoch}";
    }
    if (_contract == null) return null;
    final verifyFunction = _contract!.function('verifyBio');

    final tx = Transaction.callContract(
      contract: _contract!,
      function: verifyFunction,
      parameters: [syndrome],
      from: _credentials!.address,
    );

    final hash = await _client!.sendTransaction(
      _credentials!,
      tx,
      fetchChainIdFromNetworkId: true,
    );

    return hash;
  }

  Future<Map<String, dynamic>?> getUserData(String userAddress) async {
    if (_isTestMode) {
      return _mockStorage[userAddress];
    }
    if (_contract == null) return null;
    final getUserFunction = _contract!.function('getUserData');
    final result = await _client!.call(
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

  void dispose() {
    if (!_isTestMode) {
      _client?.dispose();
    }
  }
  
  // Keep original helper methods below...
  Uint8List hexToBytes(String hex) {
    final normalized = hex.replaceAll('0x', '').replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
    final bytes = <int>[];
    for (var i = 0; i < normalized.length; i += 2) {
      final byte = normalized.substring(i, i + 2);
      bytes.add(int.parse(byte, radix: 16));
    }
    return Uint8List.fromList(bytes);
  }

  Future<void> setContractAddress(String contractAddress) async {
    _contractAddress = EthereumAddress.fromHex(contractAddress);
    _contract = DeployedContract(
      ContractAbi.fromJson(_contractAbi, 'BioVaultID'),
      _contractAddress!,
    );
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
