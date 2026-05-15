import 'dart:math';

import 'package:flutter/material.dart';
import 'package:biovault_id/models/fuzzy_key.dart';
import 'package:biovault_id/services/biometric_auth_service.dart';
import 'package:biovault_id/services/data_revoke_service.dart';


void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'BioVault ID',
      theme: ThemeData.from(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const MyHomePage(title: 'BioVault ID Demo'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final BiometricAuthService _authService = BiometricAuthService();
  final DataRevokeService _revokeService = DataRevokeService();
  FuzzyKey? _fuzzyKey;
  String _status = 'Ready';
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _authService.dispose();
    super.dispose();
  }

  Future<void> _simulateEnroll() async {
    setState(() {
      _isBusy = true;
      _status = 'Enrollment started...';
    });

    final embedding = List<double>.generate(128, (i) => sin(i / 10.0));
    final fuzzyKey = await _authService.enrollFromEmbedding(embedding);

    setState(() {
      _fuzzyKey = fuzzyKey;
      _isBusy = false;
      _status = 'Enrolled successfully';
    });

    // Автоматически создать первое разрешение доступа после enrollment
    if (_fuzzyKey != null) {
      final grant = _revokeService.createAccessGrant(
        dataId: fuzzyKey.publicSyndrome.substring(0, 32),
        userId: 'user@example.com',
      );
      setState(() {
        _status = 'Enrolled & Access grant created: ${grant.getDataIdShort()}';
      });
    }
  }

  Future<void> _simulateVerify({required bool sameEmbedding}) async {
    if (_fuzzyKey == null) {
      setState(() {
        _status = 'Please enroll first';
      });
      return;
    }

    setState(() {
      _isBusy = true;
      _status = 'Verification started...';
    });

    final originalEmbedding = List<double>.generate(128, (i) => sin(i / 10.0));
    final embedding = sameEmbedding
        ? originalEmbedding
        : originalEmbedding.map((value) => (value + 0.2).clamp(-1.0, 1.0)).toList();

    final result = await _authService.verifyFromEmbedding(
      embedding,
      _fuzzyKey!.publicSyndrome,
    );

    setState(() {
      _isBusy = false;
      _status = result.success
          ? 'Verification success: recoveredKey ${result.recoveredKey?.substring(0, 10)}...'
          : 'Verification failed: ${result.errorMessage}';
    });
  }

  void _createAccessGrant() {
    if (_fuzzyKey == null) {
      setState(() {
        _status = 'Please enroll first';
      });
      return;
    }

    final dataId = _fuzzyKey!.publicSyndrome.substring(0, 32);
    final grant = _revokeService.createAccessGrant(
      dataId: '$dataId${_revokeService.getActiveGrants().length}',
      userId: 'app:user${_revokeService.getActiveGrants().length}',
    );

    setState(() {
      _status = 'New access grant created: ${grant.getDataIdShort()}';
    });
  }

  void _revokeAccessGrant(String dataId) {
    final revoked = _revokeService.revokeAccess(dataId);
    setState(() {
      _status = revoked != null
          ? '❌ Access revoked at ${revoked.revokedAt!.toLocal()}'
          : 'Failed to revoke access';
    });
  }

  Widget _buildKeyCard() {
    if (_fuzzyKey == null) {
      return const Text('No enrolled fuzzy key yet.');
    }

    return Card(
      margin: const EdgeInsets.only(top: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Enrolled FuzzyKey', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('Syndrome: ${_fuzzyKey!.publicSyndrome.substring(0, 40)}...'),
            const SizedBox(height: 8),
            Text('PrivateKey: ${_fuzzyKey!.privateKey.substring(0, 40)}...'),
            const SizedBox(height: 8),
            Text('Enrollment: ${_fuzzyKey!.enrollmentTime.toIso8601String()}'),
          ],
        ),
      ),
    );
  }

  Widget _buildActiveGrantsList() {
    final grants = _revokeService.getActiveGrants();
    if (grants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No active access grants. Create one to get started.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: grants.length,
      itemBuilder: (context, index) {
        final grant = grants[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: ListTile(
            title: Text('Data: ${grant.getDataIdShort()}'),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('User: ${grant.userId}'),
                Text('Key: ${grant.getKeyShort()}'),
                Text('Granted: ${grant.grantedAt.toLocal()}'),
              ],
            ),
            trailing: ElevatedButton.icon(
              icon: const Icon(Icons.delete),
              label: const Text('Revoke'),
              onPressed: () => _revokeAccessGrant(grant.dataId),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildRevokedGrantsList() {
    final grants = _revokeService.getRevokedGrants();
    if (grants.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Text('No revoked access grants yet.'),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: grants.length,
      itemBuilder: (context, index) {
        final grant = grants[index];
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: Colors.grey[200],
          child: ListTile(
            title: Text('Data: ${grant.getDataIdShort()}', 
                style: const TextStyle(decoration: TextDecoration.lineThrough)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('User: ${grant.userId}'),
                Text('Revoked: ${grant.revokedAt!.toLocal()}'),
                const Text('🔐 Key permanently deleted - data is cryptographically unrecoverable'),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '🔐 Biometric', icon: Icon(Icons.fingerprint)),
            Tab(text: '🔑 Access Revocation', icon: Icon(Icons.security)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildBiometricTab(),
          _buildRevocationTab(),
        ],
      ),
    );
  }

  Widget _buildBiometricTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Status: $_status', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _isBusy ? null : _simulateEnroll,
            child: const Text('Enroll sample biometric'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isBusy ? null : () => _simulateVerify(sameEmbedding: true),
            child: const Text('Verify same biometric'),
          ),
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: _isBusy ? null : () => _simulateVerify(sameEmbedding: false),
            child: const Text('Verify different biometric'),
          ),
          _buildKeyCard(),
          const SizedBox(height: 16),
          const Text('Note:', style: TextStyle(fontWeight: FontWeight.bold)),
          const Text(
            'This demo UI uses BiometricAuthService to connect FaceRecognitionService and FuzzyExtractorService. Replace the sample embedding flow with enrollFromImage / verifyFromImage once face image data is available.',
          ),
        ],
      ),
    );
  }

  Widget _buildRevocationTab() {
    final activeGrants = _revokeService.getActiveGrants();
    final revokedGrants = _revokeService.getRevokedGrants();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Status: $_status', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Create new access grant'),
                  onPressed: _createAccessGrant,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Active Access Grants (${activeGrants.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          _buildActiveGrantsList(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 8),
            child: Text(
              'Revocation History (${revokedGrants.length})',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
          ),
          _buildRevokedGrantsList(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              color: Colors.blue[50],
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🔒 Data Revocation Mechanism',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'When you revoke an access grant:\n'
                      '1. The encryption key is deleted from the smart contract\n'
                      '2. Encrypted data in IPFS remains immutable\n'
                      '3. Without the key, data becomes cryptographically useless\n'
                      '4. This ensures GDPR "right to be forgotten" compliance',
                      style: TextStyle(fontSize: 12),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: const Text('Data Deletion Demo'),
                            content: SingleChildScrollView(
                              child: Text(DataRevokeService.demonstrateDataAsNoise()),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text('Close'),
                              ),
                            ],
                          ),
                        );
                      },
                      child: const Text('View demonstration'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
