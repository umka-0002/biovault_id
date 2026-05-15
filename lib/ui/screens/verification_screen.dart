import 'package:flutter/material.dart';

class VerificationScreen extends StatelessWidget {
  const VerificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verification')),
      body: const Center(
        child: Text(
          'Verification screen placeholder\nTODO: capture face, verify with FuzzyExtractor, query blockchain, show result',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
