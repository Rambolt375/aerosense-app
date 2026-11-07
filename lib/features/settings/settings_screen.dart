import 'package:flutter/material.dart';

/// Settings screen placeholder for Phase 0.
/// Thresholds display, forecast parameters, and sign-out arrive in Phase 6.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: Text(
          'Settings & Thresholds (Phase 6)',
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
