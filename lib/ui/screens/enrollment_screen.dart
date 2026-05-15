import 'package:flutter/material.dart';

class EnrollmentScreen extends StatelessWidget {
  const EnrollmentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Enrollment')),
      body: const Center(
        child: Text(
          'Enrollment screen placeholder\nTODO: capture multiple frames, run FuzzyExtractor, upload to IPFS, register on blockchain',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
