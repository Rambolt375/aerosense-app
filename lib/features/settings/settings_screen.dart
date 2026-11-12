import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/repositories/providers.dart';

/// Settings screen providing read-only hardware thresholds, forecast parameters,
/// theme selection, Demo Mode controls, and account management.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDemo = ref.watch(demoModeProvider);
    final currentThemeMode = ref.watch(themeModeProvider);

    // TODO(confirm): Hook to /config when firmware owner defines the configuration schema.
    final sourceLabel = isDemo
        ? 'Demo preset'
        : 'Source: built-in (firmware defaults)';

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              // ---------------------------------------------------------------
              // Appearance (Theme Mode)
              // ---------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Appearance', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 4),
                      Text(
                        'Select preferred interface theme.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: SegmentedButton<ThemeMode>(
                          segments: const [
                            ButtonSegment(
                              value: ThemeMode.system,
                              icon: Icon(Icons.brightness_auto_outlined),
                              label: Text('System'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.light,
                              icon: Icon(Icons.light_mode_outlined),
                              label: Text('Light'),
                            ),
                            ButtonSegment(
                              value: ThemeMode.dark,
                              icon: Icon(Icons.dark_mode_outlined),
                              label: Text('Dark'),
                            ),
                          ],
                          selected: {currentThemeMode},
                          onSelectionChanged: (newSelection) {
                            ref
                                .read(themeModeProvider.notifier)
                                .setThemeMode(newSelection.first);
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Demo Mode Switch Card
              // ---------------------------------------------------------------
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

              // ---------------------------------------------------------------
              // "Run the demo" Section (visible only when Demo Mode is active)
              // ---------------------------------------------------------------
              if (isDemo) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Run the demo',
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
                            'Spikes air quality into Danger tier (>= ${Thresholds.airQualityDangerMin.toInt()}), activating the auto-fan safety override, then recovers.',
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
                            'Simulates sensor unplugged where the sensor stops reporting, displaying "--" in the dashboard, then recovers.',
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
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.only(
                            left: 8.0,
                            bottom: 4.0,
                          ),
                          child: Text(
                            'Cancels active overrides and restores clean, Safe 24-hour diurnal telemetry.',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Safety Thresholds Card (Read-Only)
              // ---------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          Text(
                            'Safety Thresholds',
                            style: theme.textTheme.titleMedium,
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              sourceLabel,
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'The ESP32 firmware is the sole authority for safety thresholds and fan actuation. These values are read-only.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 24),

                      // Temperature rows
                      _buildThresholdSection(
                        context,
                        title: 'Temperature',
                        rows: [
                          _ThresholdRow(
                            label: 'Safe',
                            value: '< ${Thresholds.tempCautionMin} °C',
                            color: context.tierColors.safe,
                          ),
                          _ThresholdRow(
                            label: 'Caution',
                            value: '>= ${Thresholds.tempCautionMin} °C',
                            color: context.tierColors.medium,
                          ),
                          _ThresholdRow(
                            label: 'Danger',
                            value: '>= ${Thresholds.tempDangerMin} °C',
                            color: context.tierColors.danger,
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Air Quality rows
                      _buildThresholdSection(
                        context,
                        title: 'Air Quality (raw 12-bit ADC, 0–4095)',
                        rows: [
                          _ThresholdRow(
                            label: 'Safe',
                            value:
                                '< ${Thresholds.airQualityCautionMin.toInt()}',
                            color: context.tierColors.safe,
                          ),
                          _ThresholdRow(
                            label: 'Caution',
                            value:
                                '>= ${Thresholds.airQualityCautionMin.toInt()}',
                            color: context.tierColors.medium,
                          ),
                          _ThresholdRow(
                            label: 'Danger',
                            value:
                                '>= ${Thresholds.airQualityDangerMin.toInt()}',
                            color: context.tierColors.danger,
                          ),
                          _ThresholdRow(
                            label: 'Recovery level',
                            value: '< ${Thresholds.airQualityRecovery.toInt()}',
                            color: context.tierColors.safe,
                          ),
                        ],
                      ),

                      const Divider(height: 24),

                      // Relative Humidity rows
                      _buildThresholdSection(
                        context,
                        title: 'Relative Humidity',
                        subtitle: 'Not yet confirmed in the firmware',
                        rows: [
                          _ThresholdRow(
                            label: 'Safe',
                            value:
                                '< ${Thresholds.humidityCautionMin.toInt()} %',
                            color: context.tierColors.safe,
                          ),
                          _ThresholdRow(
                            label: 'Caution',
                            value:
                                '>= ${Thresholds.humidityCautionMin.toInt()} %',
                            color: context.tierColors.medium,
                          ),
                          _ThresholdRow(
                            label: 'Danger',
                            value:
                                '>= ${Thresholds.humidityDangerMin.toInt()} %',
                            color: context.tierColors.danger,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Diurnal Forecast Parameters Card (Read-Only)
              // ---------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Forecast Parameters',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Diurnal sinusoidal fitter and residual gate parameters (FR-6).',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Divider(height: 24),
                      _buildParamRow(
                        context,
                        'Confidence multiplier (k)',
                        '${AppConfig.forecastSigmaMultiplier}',
                      ),
                      _buildParamRow(
                        context,
                        'Minimum history span',
                        '${AppConfig.minForecastSpanHours} hours',
                      ),
                      _buildParamRow(
                        context,
                        'Minimum hourly bins',
                        '${AppConfig.minHourlyBins} / 24 bins',
                      ),
                      _buildParamRow(
                        context,
                        'Sensor noise floor (Temp)',
                        '±${AppConfig.minTempTolerance} °C (DHT22)',
                      ),
                      _buildParamRow(
                        context,
                        'Sensor noise floor (Air Quality)',
                        '${AppConfig.minAqTolerance.toInt()} ADC index',
                      ),
                      _buildParamRow(
                        context,
                        'Hysteresis gate count',
                        '${AppConfig.forecastHysteresisSamples} samples',
                      ),
                      _buildParamRow(
                        context,
                        'Pattern detection threshold (R²)',
                        '>= ${AppConfig.minR2Pattern}',
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ---------------------------------------------------------------
              // Account & About App Card
              // ---------------------------------------------------------------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        'Application & Session',
                        style: theme.textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Version', style: theme.textTheme.bodyMedium),
                          Text(
                            AppConfig.appVersion,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Database Region',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            'asia-southeast1',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                        onPressed: () async {
                          final shouldSignOut = await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: const Text('Sign out'),
                              content: const Text(
                                'Are you sure you want to sign out of AeroSense?',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.of(ctx).pop(false),
                                  child: const Text('Cancel'),
                                ),
                                FilledButton(
                                  onPressed: () => Navigator.of(ctx).pop(true),
                                  child: const Text('Sign out'),
                                ),
                              ],
                            ),
                          );

                          if (shouldSignOut == true) {
                            await ref.read(authRepositoryProvider).signOut();
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildThresholdSection(
    BuildContext context, {
    required String title,
    String? subtitle,
    required List<_ThresholdRow> rows,
  }) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: theme.textTheme.titleSmall),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: theme.textTheme.bodySmall?.copyWith(
              color: context.tierColors.medium,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
        const SizedBox(height: 8),
        for (final row in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: row.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(row.label, style: theme.textTheme.bodyMedium),
                  ],
                ),
                Text(
                  row.value,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildParamRow(BuildContext context, String label, String value) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(child: Text(label, style: theme.textTheme.bodyMedium)),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _ThresholdRow {
  const _ThresholdRow({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;
}
