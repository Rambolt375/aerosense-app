import 'package:flutter/material.dart';

/// Diurnal forecast screen placeholder for Phase 0.
/// Fit + residual gate UI arrives in Phase 5.
class ForecastScreen extends StatelessWidget {
  const ForecastScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Forecast')),
      body: Center(
        child: Text(
          'Diurnal Forecast (Phase 5)',
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}
