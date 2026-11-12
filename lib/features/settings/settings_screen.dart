import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/repositories/providers.dart';

/// Settings screen providing the runtime Demo Mode switch and simulation triggers.
///
/// Thresholds display, forecast parameters, and Firebase sign-out arrive in Phase 6.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDemo = ref.watch(demoModeProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // Demo Mode Switch Card
              Card(
                child: SwitchListTile(
                  title: Text('Demo Mode', style: theme.textTheme.titleMedium),
                  subtitle: Text(
                    'Simulate firmware and historical telemetry without live Firebase.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  value: isDemo,
                  onChanged: (value) {
                    ref.read(demoModeProvider.notifier).setDemo(value);
                  },
                ),
              ),

              // Simulation Controls (visible only when Demo Mode is active)
              if (isDemo) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Simulation Scenarios',
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Trigger scripted sensor events to test safety overrides and tier transitions on stage.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Smoke Spike Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.cloud_outlined),
                          label: const Text('Simulate Kitchen Smoke'),
                          onPressed: () {
                            ref
                                .read(fakeSystemRepositoryProvider)
                                .simulateKitchenSmoke();
                          },
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 12.0,
                          ),
                          child: Text(
                            'Spikes air quality into Danger tier (> 2000), activating the auto-fan safety override, then recovers.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                        // Heat Spike Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.thermostat_outlined),
                          label: const Text('Simulate Heat Spike'),
                          onPressed: () {
                            ref
                                .read(fakeSystemRepositoryProvider)
                                .simulateHeatSpike();
                          },
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 12.0,
                          ),
                          child: Text(
                            'Ramps temperature through Caution (>= ${Thresholds.tempSafeMax} °C) into Danger tier (>= ${Thresholds.tempDangerMin} °C), then recovers.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                        // Sensor Unplugged Button
                        OutlinedButton.icon(
                          icon: const Icon(Icons.link_off_outlined),
                          label: const Text('Simulate Sensor Unplugged'),
                          onPressed: () {
                            ref
                                .read(fakeSystemRepositoryProvider)
                                .simulateSensorUnplugged();
                          },
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 12.0,
                          ),
                          child: Text(
                            'Nulls temperature and humidity for a while, displaying "--" in the dashboard, then recovers.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),

                        // Reset Button
                        TextButton.icon(
                          icon: const Icon(Icons.restart_alt),
                          label: const Text('Reset to Baseline'),
                          onPressed: () {
                            ref
                                .read(fakeSystemRepositoryProvider)
                                .resetToBaseline();
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Text(
                  'Hardware thresholds and configuration will be displayed in Phase 6.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
