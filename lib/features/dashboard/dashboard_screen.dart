import 'package:flutter/material.dart';

/// Live dashboard screen placeholder for Phase 0.
/// Subscribed telemetry tiles and tier banner arrive in Phase 2.
class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: Center(
        child: Text(
          'Live Telemetry Dashboard (Phase 2)',
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
