import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: Text(
          'Settings (Lock removed).\n\nYou can add future settings here (backup/export/theme, etc.).',
        ),
      ),
    );
  }
}
