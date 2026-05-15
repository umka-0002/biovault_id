import 'package:flutter/material.dart';

class CameraScreen extends StatelessWidget {
  const CameraScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: const Center(
        child: Text(
          'Camera screen placeholder\nTODO: integrate camera plugin, face detection, and capture flow',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
