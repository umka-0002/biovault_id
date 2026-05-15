import 'package:flutter/material.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: const Center(
        child: Text(
          'Profile screen placeholder\nTODO: show user profile, verification history, key recovery and access revoke actions',
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
