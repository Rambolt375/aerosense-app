import 'package:flutter/material.dart';

/// Historical telemetry charts screen placeholder for Phase 0.
/// 24h charts with threshold bands arrive in Phase 3.
class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('History')),
      body: Center(
        child: Text(
          'History Charts (Phase 3)',
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
