# BioVault ID — Quick Reference

## 📚 Documentation Structure

This project contains comprehensive documentation across 4 main files:

| Document | Purpose | Audience |
|----------|---------|----------|
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | System overview & 5-layer architecture | Everyone |
| **[TECH_STACK.md](TECH_STACK.md)** | Technology choices & implementation details | Developers |
| **[SYSTEM_DESIGN.md](SYSTEM_DESIGN.md)** | Data flows, diagrams & security | Architects |
| **[IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)** | TODO list & deployment timeline | Project Managers |

---

## 🎯 The Five-Layer Architecture (TL;DR)

```
┌─────────────────────────────────────────────────────────┐
│ 1. FRONTEND (Flutter)                                   │
│    Crossplatform app on iOS/Android                    │
│    Only place where face data exists                   │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ 2. EDGE AI (TensorFlow Lite)                           │
│    MTCNN: detect face                                  │
│    FaceNet: create 128-dim embedding (fingerprint)     │
│    ✓ Runs locally, no network upload of images        │
└──────────────────┬──────────────────────────────────────┘
                   │
┌──────────────────▼──────────────────────────────────────┐
│ 3. FUZZY EXTRACTOR (Reed-Solomon)                      │
│    Problem: embeddings are "noisy"                     │
│    Solution: convert noisy vector → stable crypto key  │
│    Result: reproducible + secure                       │
└──────────────────┬──────────────────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
┌───────▼──────┐      ┌──────▼────────┐
│ 4. IPFS      │      │ 5. BLOCKCHAIN │
│ Encrypted    │      │ Solidity      │
│ backup data  │      │ smart contract│
└──────────────┘      └───────────────┘
```

---

## 🚀 Quick Start

### 1. Clone & Setup
```bash
git clone https://github.com/yourusername/biovault_id.git
cd biovault_id

# Install dependencies
flutter pub get

# Run
flutter run -d <device_id>
```

### 2. Check Status
- ✅ **Phase 1** (Edge AI): FaceNet working
- 🔄 **Phase 2** (Fuzzy Extractor): In development
- ⏳ **Phase 3-5**: Planned

---

## 📖 How to Use These Docs

### For Developers
1. Read [ARCHITECTURE.md](ARCHITECTURE.md) for overview
2. Check [TECH_STACK.md](TECH_STACK.md) for implementation guide
3. Reference [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md) for data flows
4. Follow [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md) for TODOs

### For Project Managers
1. Start with [ARCHITECTURE.md](ARCHITECTURE.md#five-levels-of-architecture) overview
2. Check [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md#deployment-timeline) for timeline
3. Review [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md#team-skills-needed) for team needs

### For Security Auditors
1. Study [SYSTEM_DESIGN.md](SYSTEM_DESIGN.md#security-considerations) security section
2. Review smart contract in [TECH_STACK.md](TECH_STACK.md#smart-contract-solidity)
3. Check [TECH_STACK.md](TECH_STACK.md#security-checklist) checklist

---

## 🔑 Key Concepts

### Embedding
A 128-dimensional vector that represents a face. Two similar faces → similar vectors.
```
Your face → FaceNet neural network → [0.12, -0.45, 0.78, ...]
```

### Fuzzy Extractor
Algorithm that converts "noisy" embedding into "stable" cryptographic key.
```
Embedding 1: [0.12, -0.45, ...]  } Similar but
Embedding 2: [0.11, -0.46, ...]  } slightly different
              ↓ (Reed-Solomon)
         Stable Key: 0xAbCd...
```

### Reed-Solomon Codes
Error-correcting codes that can fix corrupted data.
```
You have 256 total symbols
128 are your data, 128 are "parity" (error correction)
Can fix up to 64 symbols of corruption
Perfect for biometric recovery!
```

### Syndrome
Public hash published on blockchain. Can't reconstruct face from it.
```
syndrome = hash(parity_symbols)
Blockchain stores: syndrome + IPFS_CID

✓ Public knowledge
✗ Face cannot be recovered from syndrome
```

### Smart Contract
Program running on Ethereum/Polygon that acts as "backend".
```
- Stores syndrome + IPFS CID for each user
- Verifies authentication transactions
- Cannot be hacked (immutable, decentralized)
- Anyone can verify: "Is this person registered?"
```

---

## 💾 Services Overview

### FaceRecognitionService ✅
- Loads FaceNet model
- Processes images
- Returns 128-dim embedding
**Status**: Implemented

### FuzzyExtractorService 🔄
- Enrolls user (multiple embeddings → key + syndrome)
- Verifies user (new embedding + syndrome → key)
- Uses Reed-Solomon error correction
**Status**: In progress

### IPFSService ⏳
- Uploads encrypted backup data
- Downloads and decrypts
- Provides recovery mechanism
**Status**: TODO

### BlockchainService ⏳
- Deploys smart contract
- Registers user (stores syndrome)
- Verifies user (checks syndrome)
- Retrieves user data
**Status**: TODO

### BiometricAuthService ⏳
- Orchestrates full authentication flow
- Handles liveness detection (future)
- Manages recovery scenarios
**Status**: TODO

---

## 📊 Architecture Decision Records

### Why TensorFlow Lite (not cloud API)?
✓ Privacy: Face never leaves phone  
✓ Offline: Works without internet  
✓ Speed: ~100ms per verification  
✗ No network costs  

### Why Reed-Solomon (not simple hashing)?
✓ Recoverable: Can fix embedding variations  
✓ Cryptographic: Secure synthesis of key  
✓ Scientific: Published research-based  
✗ Handles ±10% embedding changes  

### Why IPFS (not centralized server)?
✓ Decentralized: No single point of failure  
✓ Persistent: Data archived globally  
✓ Censorship-resistant  
✗ No KYC/compliance required  

### Why Blockchain (not centralized database)?
✓ Immutable: Can't change history  
✓ Transparent: Anyone can audit  
✓ No central authority needed  
✗ Decentralized consensus required  

---

## 🧪 Testing Checklist

- [ ] Unit tests for FaceNet inference
- [ ] Unit tests for Reed-Solomon codec
- [ ] Integration test: enrollment flow
- [ ] Integration test: verification flow
- [ ] Integration test: recovery flow
- [ ] Performance test: latency < 2s
- [ ] Security test: key never logged
- [ ] Testnet deployment on Sepolia
- [ ] Load test: 1000+ concurrent verifications

---

## 🔐 Security Principles

1. **No photos transmitted** — Only embeddings and hashes
2. **Private keys protected** — Secure Enclave / Android Keystore
3. **IPFS data encrypted** — AES-256-GCM with user key
4. **Blockchain immutable** — Can't change history
5. **Open source** — Anyone can audit
6. **Regular audits** — Security reviews every release

---

## 📞 Support

### Documentation
- [Flutter Docs](https://flutter.dev/docs)
- [TensorFlow Lite](https://www.tensorflow.org/lite)
- [Reed-Solomon Wikipedia](https://en.wikipedia.org/wiki/Reed%E2%80%93Solomon_error_correction)
- [IPFS Documentation](https://docs.ipfs.io/)
- [Solidity Guide](https://docs.soliditylang.org/)

### Research Papers
- **FaceNet**: [arxiv.org/abs/1503.03832](https://arxiv.org/abs/1503.03832)
- **Fuzzy Extractor**: [eprint.iacr.org/2014/507](https://eprint.iacr.org/2014/507)
- **IPFS**: [ipfs.io/papers](https://ipfs.io/papers)

---

## 📈 Project Status

```
Phase 1: Edge AI              ████████████████████ 100% ✅
Phase 2: Fuzzy Extractor     ████████░░░░░░░░░░░░  40% 🔄
Phase 3: IPFS                ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Phase 4: Blockchain          ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Phase 5: UI                  ░░░░░░░░░░░░░░░░░░░░   0% ⏳
Total Progress               ████████░░░░░░░░░░░░  20% 🚀
```

---

## 🎓 Learning Path

### Week 1: Understand the Vision
- [ ] Read [ARCHITECTURE.md](ARCHITECTURE.md)
- [ ] Understand 5-layer model
- [ ] Know: Why this is Web3, not just ML

### Week 2-3: Learn Technologies
- [ ] Flutter basics
- [ ] TensorFlow Lite inference
- [ ] Ethereum smart contracts
- [ ] IPFS concepts

### Week 4-5: Study Implementation
- [ ] Read [TECH_STACK.md](TECH_STACK.md)
- [ ] Study face embedding generation
- [ ] Reed-Solomon error correction
- [ ] Blockchain integration

### Week 6-8: Development
- [ ] Implement Fuzzy Extractor
- [ ] Build UI screens
- [ ] Deploy smart contract
- [ ] Integrate IPFS

### Week 9-10: Testing & Polish
- [ ] Run test suite
- [ ] Performance optimization
- [ ] Security audit
- [ ] Documentation

### Week 11+: Launch
- [ ] Testnet release
- [ ] Beta feedback
- [ ] Mainnet deployment

---

## 🤝 Contributing

1. Fork repository
2. Read [IMPLEMENTATION_ROADMAP.md](IMPLEMENTATION_ROADMAP.md)
3. Pick TODO from "Phase X"
4. Create feature branch
5. Implement with tests
6. Submit PR with description

---

## 📄 License

[Choose your license: MIT / Apache 2.0 / GPL-3.0]

---

**Last Updated**: May 8, 2026  
**Version**: 1.0  
**Status**: 🚀 In Active Development  

**Next Steps**:
1. Finish Fuzzy Extractor implementation
2. Build IPFS integration
3. Deploy smart contract
4. Complete UI
5. Security audit
