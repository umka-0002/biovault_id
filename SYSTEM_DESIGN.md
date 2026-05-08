# BioVault ID — System Design & Data Flow

## System Overview Diagram

```
╔════════════════════════════════════════════════════════════════════════════╗
║                          BioVault ID Ecosystem                            ║
╚════════════════════════════════════════════════════════════════════════════╝

┌──────────────────────────────────────────────────────────────────────────┐
│  USER DEVICE (iOS/Android)                                              │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │  Flutter App (BioVault ID)                                       │   │
│  │                                                                   │   │
│  │  ┌─────────────────────────────────────────────────────────────┐ │   │
│  │  │ UI Layer (Screens)                                          │ │   │
│  │  │ ├─ CameraScreen (video capture + MTCNN)                    │ │   │
│  │  │ ├─ EnrollmentScreen (multi-frame registration)             │ │   │
│  │  │ ├─ VerificationScreen (single-frame verification)          │ │   │
│  │  │ └─ ProfileScreen (user data & history)                     │ │   │
│  │  └─────────────────────────────────────────────────────────────┘ │   │
│  │              ▲          ▲           ▲          ▲                   │   │
│  │              │          │           │          │                   │   │
│  │  ┌───────────┴──────────┴───────────┴──────────┴────────────────┐ │   │
│  │  │ Service Layer                                                │ │   │
│  │  ├─ FaceRecognitionService (TFLite inference)                  │ │   │
│  │  ├─ FuzzyExtractorService (Reed-Solomon crypto)               │ │   │
│  │  ├─ IPFSService (encrypted backup storage)                    │ │   │
│  │  ├─ BlockchainService (smart contract interaction)            │ │   │
│  │  └─ BiometricAuthService (orchestration)                      │ │   │
│  │  └─────────────────────────────────────────────────────────────┘ │   │
│  └──────────────────────────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────────────────────────┐   │
│  │ Hardware/System Access                                          │   │
│  │ ├─ Camera (video stream)                                       │   │
│  │ ├─ Secure Enclave / Keystore (private keys)                   │   │
│  │ └─ Local Storage (user preferences)                           │   │
│  └──────────────────────────────────────────────────────────────────┘   │
└──────────────────────────────────────────────────────────────────────────┘
                    │
    ┌───────────────┼───────────────┬────────────────────┐
    │               │               │                    │
    ▼               ▼               ▼                    ▼

┌─────────────┐ ┌────────────┐ ┌─────────────┐ ┌──────────────────┐
│  TensorFlow │ │ Reed-      │ │ IPFS        │ │ Ethereum/EVM     │
│  Lite       │ │ Solomon    │ │ Network     │ │ Blockchain       │
│  Models     │ │ Encoder    │ │             │ │                  │
│  (Local)    │ │ (Local)    │ │ (Distributed)│ │ Smart Contract  │
└─────────────┘ └────────────┘ └─────────────┘ └──────────────────┘
```

---

## Data Flow: Complete Lifecycle

### 1. Registration Flow (Enrollment)

```
┌─────────────────────────────────────────────────────────────────┐
│                    ENROLLMENT PROCESS                           │
└─────────────────────────────────────────────────────────────────┘

START
  │
  ├─ User opens app
  │
  ├─ User navigates to EnrollmentScreen
  │
  ├─ App requests camera permission
  │
  ├─ [Loop: Capture N frames of face]
  │  ├─ Get video frame from camera
  │  │
  │  ├─ [Edge AI] MTCNN Detection
  │  │  ├─ Input: Raw video frame (480×640 or higher)
  │  │  ├─ Process: Face detection + key points
  │  │  └─ Output: Face region coordinates
  │  │
  │  ├─ [Edge AI] Extract face region
  │  │  ├─ Input: Frame + coordinates
  │  │  └─ Output: Face crop (160×160)
  │  │
  │  ├─ [Edge AI] FaceNet Embedding
  │  │  ├─ Input: Face crop (normalized)
  │  │  ├─ Process: Neural network inference
  │  │  └─ Output: 128-dim vector (embedding)
  │  │
  │  ├─ Store embedding in memory
  │  │
  │  └─ [Progress] N=5? → Continue loop or exit
  │
  ├─ [Crypto] Fuzzy Extractor Enrollment
  │  ├─ Input: Multiple embeddings (N=5)
  │  │
  │  ├─ Step 1: Quantization
  │  │  ├─ Normalize: [-1, 1] → [0, 255]
  │  │  └─ Result: 5 × 256-byte sequences
  │  │
  │  ├─ Step 2: Reed-Solomon Encoding
  │  │  ├─ Average quantized embeddings
  │  │  ├─ Apply RS(256, 128) code
  │  │  └─ Generate: Public Syndrome + Private Key
  │  │
  │  └─ Output: 
  │     ├─ Public Syndrome (publishable)
  │     └─ Private Key K (keep secret)
  │
  ├─ [Storage] Encrypt & Upload to IPFS
  │  ├─ Data: {embedding_avg, metadata, version}
  │  │
  │  ├─ Step 1: Encrypt with Private Key K
  │  │  └─ Algorithm: AES-256-GCM
  │  │
  │  ├─ Step 2: Upload encrypted blob
  │  │  ├─ POST /api/v0/add (HTTP to IPFS)
  │  │  └─ Receive: CID (Content Identifier)
  │  │
  │  └─ Output: IPFS CID (publicly known)
  │
  ├─ [Blockchain] Publish to Smart Contract
  │  ├─ Data to publish:
  │  │  ├─ Public Syndrome (bytes32)
  │  │  ├─ IPFS CID (string)
  │  │  └─ User Address (address)
  │  │
  │  ├─ Step 1: Sign transaction with Private Key
  │  │
  │  ├─ Step 2: Send registerBio() transaction
  │  │  ├─ Function: registerBio(syndrome, ipfsCID)
  │  │  ├─ Gas cost: ~100k-200k gas
  │  │  └─ Network: Ethereum / Polygon / etc.
  │  │
  │  ├─ Step 3: Wait for confirmation (≈15 seconds)
  │  │
  │  └─ Output: Transaction Hash (txHash)
  │
  ├─ [Storage] Store locally (Secure Enclave/Keystore)
  │  ├─ Private Key K → Encrypted keystore
  │  └─ No other sensitive data on device
  │
  ├─ [UI] Show success
  │  └─ "✓ Registration complete!"
  │
  └─ END
```

### 2. Verification Flow (Authentication)

```
┌─────────────────────────────────────────────────────────────────┐
│                    VERIFICATION PROCESS                         │
└─────────────────────────────────────────────────────────────────┘

START
  │
  ├─ User navigates to VerificationScreen
  │
  ├─ App requests camera permission
  │
  ├─ User aligns face with camera
  │
  ├─ Capture single frame
  │
  ├─ [Edge AI] Process face
  │  ├─ MTCNN Detection
  │  ├─ Face crop & normalization
  │  ├─ FaceNet Embedding
  │  └─ Output: 128-dim vector
  │
  ├─ [Crypto] Fuzzy Extractor Verification
  │  ├─ Load Public Syndrome from Blockchain
  │  │
  │  ├─ Load Private Key from Secure Storage
  │  │
  │  ├─ Quantize new embedding
  │  │
  │  ├─ Apply Reed-Solomon Decode
  │  │  ├─ Input: new embedding + public syndrome
  │  │  ├─ Algorithm: Berlekamp-Massey
  │  │  ├─ Tolerance: up to 64 symbol errors
  │  │  └─ Output: recovered key (if successful)
  │  │
  │  ├─ Compare recovered key with stored key K
  │  │  ├─ If match → Verification successful ✓
  │  │  └─ If mismatch → Verification failed ✗
  │  │
  │  └─ Decision point:
  │     ├─ [YES] → Continue to blockchain verification
  │     └─ [NO] → Show error, end
  │
  ├─ [Blockchain] Verify on smart contract
  │  ├─ Load Public Syndrome from blockchain
  │  │
  │  ├─ Step 1: Call verifyBio(syndrome)
  │  │  ├─ Contract checks: syndrome in blockchain?
  │  │  ├─ If yes → Emit VerificationSuccess event
  │  │  └─ If no → Revert transaction
  │  │
  │  ├─ Step 2: Wait for tx confirmation
  │  │
  │  └─ Update counter: lastVerification + verificationCount++
  │
  ├─ [UI] Show result
  │  ├─ If success:
  │  │  └─ "✓ Identity verified!"
  │  │  └─ Show verification time + count
  │  │
  │  └─ If failure:
  │     └─ "✗ Face not recognized"
  │
  └─ END
```

### 3. Recovery Flow (Lost Device)

```
┌─────────────────────────────────────────────────────────────────┐
│                    RECOVERY PROCESS                             │
└─────────────────────────────────────────────────────────────────┘

PRECONDITIONS:
  • User lost original phone
  • Installed BioVault ID on new device
  • Still has the same face! ✓

START
  │
  ├─ User navigates to recovery option
  │
  ├─ User enters recovery info
  │  ├─ Wallet address (from blockchain explorer)
  │  └─ (Optional) backup phrase / recovery key
  │
  ├─ [Blockchain] Load user data
  │  ├─ Query: getUserData(walletAddress)
  │  │
  │  ├─ Retrieve:
  │  │  ├─ Public Syndrome
  │  │  ├─ IPFS CID
  │  │  └─ Enrollment timestamp
  │  │
  │  └─ Validate: User registered? → Yes/No
  │
  ├─ [If NO] → Error: User not registered → END
  │
  ├─ [If YES] → Continue recovery
  │
  ├─ User scans face (may be slightly different now)
  │
  ├─ [Edge AI] Generate embedding
  │
  ├─ [Crypto] Fuzzy Extractor with recovery
  │  ├─ Load public syndrome from blockchain
  │  │
  │  ├─ Apply Reed-Solomon decode
  │  │  ├─ Tolerance: ±64 symbols of error
  │  │  ├─ Accounts for time + expression changes
  │  │  └─ Recover private key K
  │  │
  │  ├─ Verify: key recovered successfully?
  │  │  ├─ If YES → Private key reconstructed ✓
  │  │  └─ If NO → Face too different → END
  │  │
  │  └─ Output: Private Key K
  │
  ├─ [Storage] IPFS Recovery
  │  ├─ Load IPFS CID from blockchain
  │  │
  │  ├─ Download encrypted blob from IPFS
  │  │
  │  ├─ Decrypt with recovered key K
  │  │  ├─ Algorithm: AES-256-GCM
  │  │  └─ Output: enrollment data, backup keys
  │  │
  │  └─ Validate: Checksum matches?
  │
  ├─ [Storage] Store locally on new device
  │  ├─ Private Key K → Secure Enclave/Keystore
  │  └─ User preferences → Local storage
  │
  ├─ [UI] Show success
  │  └─ "✓ Account recovered successfully!"
  │
  └─ END
```

---

## Data Structures

### 1. Face Embedding

```dart
class FaceEmbedding {
  final List<double> vector;           // 128-dim vector
  final int timestamp;                 // Capture time
  final String sourceFaceImage;        // Base64 (optional)
  final Map<String, double> metadata;  // quality, brightness, etc.

  FaceEmbedding({
    required this.vector,
    required this.timestamp,
    this.sourceFaceImage = '',
    this.metadata = const {},
  });

  // Distance to another embedding (Euclidean)
  double distanceTo(FaceEmbedding other) {
    double sum = 0.0;
    for (int i = 0; i < vector.length; i++) {
      final diff = vector[i] - other.vector[i];
      sum += diff * diff;
    }
    return sqrt(sum);
  }
}
```

### 2. Fuzzy Key

```dart
class FuzzyKey {
  final String publicSyndrome;         // bytes32 (hex string)
  final String privateKey;             // 256-bit key (hex)
  final DateTime enrollmentTime;       // When generated
  final String version;                // "1.0"

  FuzzyKey({
    required this.publicSyndrome,
    required this.privateKey,
    required this.enrollmentTime,
    this.version = '1.0',
  });

  // Serialization
  Map<String, dynamic> toJson() => {
    'publicSyndrome': publicSyndrome,
    'enrollmentTime': enrollmentTime.toIso8601String(),
    'version': version,
  };
}
```

### 3. Biometric Registration

```dart
class BiometricRegistration {
  final String userId;                 // Wallet address
  final String publicSyndrome;         // From blockchain
  final String ipfsCID;                // From IPFS
  final DateTime enrollmentTime;       // Blockchain timestamp
  final int verificationCount;         // How many times verified
  final DateTime lastVerification;     // Last successful check

  BiometricRegistration({
    required this.userId,
    required this.publicSyndrome,
    required this.ipfsCID,
    required this.enrollmentTime,
    required this.verificationCount,
    required this.lastVerification,
  });

  // From blockchain query
  factory BiometricRegistration.fromBlockchain(
    String userId,
    Map<String, dynamic> blockchainData,
  ) => BiometricRegistration(
    userId: userId,
    publicSyndrome: blockchainData['syndrome'] as String,
    ipfsCID: blockchainData['ipfsCID'] as String,
    enrollmentTime: DateTime.fromMillisecondsSinceEpoch(
      (blockchainData['enrollmentTime'] as int) * 1000,
    ),
    verificationCount: blockchainData['verificationCount'] as int,
    lastVerification: DateTime.fromMillisecondsSinceEpoch(
      (blockchainData['lastVerification'] as int) * 1000,
    ),
  );
}
```

---

## Network Communication Patterns

### 1. IPFS HTTP API

```
REQUEST:
  POST http://localhost:5001/api/v0/add
  Content-Type: multipart/form-data
  
  file: <encrypted binary data>

RESPONSE:
  {
    "Name": "biometric_backup",
    "Hash": "QmX...abc",  ← This is the CID
    "Size": "1024"
  }

---

REQUEST:
  GET http://localhost:8080/ipfs/QmX...abc

RESPONSE:
  <encrypted binary data>
```

### 2. Blockchain RPC

```
REQUEST (JSON-RPC 2.0):
  {
    "jsonrpc": "2.0",
    "method": "eth_sendTransaction",
    "params": [{
      "from": "0x742d35Cc6634C0532925a3b844Bc9e7595f...",
      "to": "0xBioVaultIDContractAddress...",
      "data": "0x...encoded function call...",
      "gas": "0x186a0",  // 100000 gas
      "gasPrice": "0x...current gas price..."
    }],
    "id": 1
  }

RESPONSE:
  {
    "jsonrpc": "2.0",
    "result": "0x...transaction hash...",
    "id": 1
  }
```

---

## Error Handling Strategy

### FaceRecognitionService

```dart
enum FaceRecognitionError {
  modelNotLoaded,        // Model initialization failed
  noFaceDetected,        // MTCNN didn't find a face
  multipleFacesDetected, // More than one face in frame
  poorImageQuality,      // Image too dark/blurry
  inferenceFailed,       // TFLite inference error
}

// Usage
try {
  final embedding = faceService.predict(image);
} on FaceRecognitionError catch (e) {
  switch (e) {
    case FaceRecognitionError.noFaceDetected:
      showError("Please align your face with the camera");
      break;
    case FaceRecognitionError.poorImageQuality:
      showError("Better lighting needed");
      break;
    default:
      showError("Recognition failed");
  }
}
```

### FuzzyExtractorService

```dart
enum FuzzyExtractorError {
  quantizationFailed,    // Embedding quantization error
  encodingFailed,        // Reed-Solomon encoding failed
  tooManyErrors,         // Decoding: >64 symbol errors
  keyRecoveryFailed,     // Private key recovery failed
  thresholdNotMet,       // Quality threshold not reached
}
```

### BlockchainService

```dart
enum BlockchainError {
  notConnected,          // No network connection
  contractNotFound,      // Contract address invalid
  transactionFailed,     // Tx reverted
  gasFeeExceeded,        // Gas price too high
  userNotRegistered,     // Address not in contract
  verificationFailed,    // Syndrome mismatch
}
```

---

## Performance Optimization

### Caching Strategy

```dart
class CacheLayer {
  // Cache TFLite interpreter (expensive to load)
  static Interpreter? _interpreter;
  
  // Cache blockchain contract ABI
  static ContractAbi? _contractAbi;
  
  // Cache recent embeddings (for enrollment multi-frame)
  static List<FaceEmbedding> _embeddingBuffer = [];
  
  // Single instance (singleton pattern)
  static final CacheLayer _instance = CacheLayer._internal();
  
  factory CacheLayer() {
    return _instance;
  }
  
  CacheLayer._internal();
}
```

### Lazy Loading

```dart
// Delay model loading until first use
class LazyFaceRecognitionService {
  Interpreter? _interpreter;
  Future<void>? _loadingFuture;
  
  Future<Interpreter> _getInterpreter() async {
    if (_interpreter != null) return _interpreter!;
    
    _loadingFuture ??= _loadModel();
    await _loadingFuture;
    
    return _interpreter!;
  }
}
```

---

## Security Considerations

### 1. Private Key Storage

```dart
// iOS: Keychain via flutter_secure_storage
// Android: Android Keystore via flutter_secure_storage
// Web: localStorage (with considerations)

final secureStorage = FlutterSecureStorage();

// Write
await secureStorage.write(
  key: 'private_key_k',
  value: privateKey,
);

// Read
final key = await secureStorage.read(key: 'private_key_k');

// Delete (logout)
await secureStorage.delete(key: 'private_key_k');
```

### 2. Biometric Authentication

```dart
// Use device biometric (fingerprint/face) to unlock app
// → Then access private key from secure storage

class BiometricAuth {
  final LocalAuthentication _auth = LocalAuthentication();
  
  Future<bool> authenticate() async {
    return await _auth.authenticate(
      localizedReason: 'Authenticate to access your biometric profile',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
  }
}
```

### 3. Data Encryption

```dart
// AES-256-GCM for IPFS backup
// SHA-256 for key derivation
// HMAC-SHA256 for signatures

class CryptoUtils {
  // Encrypt data with private key
  static Uint8List encrypt(String data, String key) {
    // TODO: Implement AES-256-GCM
    // key → AES secret
    // data → plaintext
    // return ciphertext + nonce + auth tag
  }
  
  // Derive key from embedding
  static String deriveKey(List<int> embedding) {
    return sha256.convert(embedding).toString();
  }
}
```

---

## Monitoring & Logging

### Events to Log

```dart
enum BiometricsEvent {
  appOpened,
  enrollmentStarted,
  enrollmentCompleted,
  verificationAttempted,
  verificationSucceeded,
  verificationFailed,
  recoveryStarted,
  recoverySucceeded,
  recoveryFailed,
  blockchainTxSent,
  blockchainTxConfirmed,
  ipfsUploadStarted,
  ipfsUploadCompleted,
  errorOccurred,
}

class AnalyticsLogger {
  static void log(BiometricsEvent event, Map<String, dynamic> params) {
    // Log to Firebase Analytics / Mixpanel / custom backend
    // Include: timestamp, user_id (anonymous), event_type, duration, error_msg
    
    print('📊 Event: $event | Params: $params');
  }
}

// Usage
AnalyticsLogger.log(BiometricsEvent.verificationSucceeded, {
  'duration_ms': 1234,
  'embedding_distance': 0.05,
  'blockchain_tx_hash': '0x...',
});
```

---

**Version**: 1.0  
**Last Updated**: May 8, 2026  
**Status**: Design Documentation
