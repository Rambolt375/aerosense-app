import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/forecast/preventive_decision.dart';
import 'package:aerosense_app/features/forecast/preventive_providers.dart';

/// Pre-ventilation operational status card on the Forecast screen (PRD §FR-7).
///
/// Displays:
/// - Operational status pill (Off, Armed, Running, Unavailable).
/// - Current status explanation / planned run time.
/// - Team-only "Run pre-ventilation now (demo)" button with disabled reasons.
///
/// Uses `.select()` so telemetry ticks do not cause repaints unless
/// operational state or relevant gates change.
class PreVentilationCard extends ConsumerWidget {
  const PreVentilationCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final tierColors = context.tierColors;
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    // Granular selectors to prevent unnecessary repaints
    final uiState = ref.watch(
      preventiveDecisionProvider.select((d) => d.uiState),
    );
    final reason = ref.watch(
      preventiveDecisionProvider.select((d) => d.reason),
    );
    final nextPeak = ref.watch(
      preventiveDecisionProvider.select((d) => d.nextPeakTime),
    );
    final nextPlannedRun = ref.watch(
      preventiveDecisionProvider.select((d) => d.nextPlannedRunTime),
    );
    final isTeam = ref.watch(isTeamAccountProvider);

    // Gate selectors for demo button disabled state
    final allowPreventive = ref.watch(
      forecastPreferencesProvider.select(
        (p) => p.asData?.value.allowPreventive ?? false,
      ),
    );
    final isTriggerActive = ref.watch(
      forecastPreferencesProvider.select(
        (p) => p.asData?.value.preventiveTrigger ?? false,
      ),
    );
    final isOffline = ref.watch(
      deviceStatusProvider.select((s) => s.isOffline),
    );
    final isDanger = ref.watch(
      systemStateProvider.select((s) => s.asData?.value.tier == Tier.danger),
    );
    final isFanOn = ref.watch(
      systemStateProvider.select((s) => s.asData?.value.fanOn ?? false),
    );
    final isManualToggle = ref.watch(
      systemStateProvider.select((s) => s.asData?.value.manualToggle ?? false),
    );
    final isPending = ref.watch(
      runPreVentilationNotifierProvider.select((s) => s.isPending),
    );

    // SnackBar listener for manual run feedback and errors
    ref.listen<RunPreVentilationState>(runPreVentilationNotifierProvider, (
      previous,
      next,
    ) {
      if (next.errorMessage != null) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(next.errorMessage!),
          ),
        );
        ref.read(runPreVentilationNotifierProvider.notifier).clearMessages();
      } else if (next.feedbackMessage != null) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text(next.feedbackMessage!),
          ),
        );
        ref.read(runPreVentilationNotifierProvider.notifier).clearMessages();
      }
    });

    // Determine disabled reason for demo run button
    String? disabledReason;
    if (!allowPreventive) {
      disabledReason = 'Disabled in Settings';
    } else if (isOffline) {
      disabledReason = 'Device is offline';
    } else if (isDanger) {
      disabledReason = 'Safety override active: fan is locked ON';
    } else if (isTriggerActive || isManualToggle || isFanOn) {
      disabledReason = 'Ventilation cycle is already in progress';
    } else if (isPending) {
      disabledReason = 'Sending request...';
    }

    final canRunDemo = disabledReason == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Title and Status Pill
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Text('Pre-Ventilation', style: textTheme.titleMedium),
                _buildStatusPill(context, uiState, tierColors),
              ],
            ),
            const SizedBox(height: 8),

            // Operational status description
            _buildDescription(
              context,
              uiState: uiState,
              reason: reason,
              nextPlannedRun: nextPlannedRun,
              nextPeak: nextPeak,
            ),

            // Team-only "Run pre-ventilation now (demo)" section
            if (isTeam) ...[
              const Divider(height: 24),
              OutlinedButton(
                onPressed: canRunDemo
                    ? () {
                        ref
                            .read(runPreVentilationNotifierProvider.notifier)
                            .runNow();
                      }
                    : null,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isPending)
                      const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      const Icon(Icons.play_arrow_outlined, size: 18),
                    const SizedBox(width: 8),
                    const Flexible(
                      child: Text('Run pre-ventilation now (demo)'),
                    ),
                  ],
                ),
              ),
              if (disabledReason != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Button unavailable: $disabledReason',
                  style: textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusPill(
    BuildContext context,
    PreventiveUiState state,
    TierColors tierColors,
  ) {
    final theme = Theme.of(context);
    final Color background;
    final Color foreground;
    final String label;

    switch (state) {
      case PreventiveUiState.off:
        background = theme.colorScheme.surfaceContainerHighest;
        foreground = theme.colorScheme.onSurfaceVariant;
        label = 'Off';
        break;
      case PreventiveUiState.armed:
        background = theme.colorScheme.primaryContainer;
        foreground = theme.colorScheme.onPrimaryContainer;
        label = 'Armed';
        break;
      case PreventiveUiState.running:
        background = tierColors.safeContainer;
        foreground = tierColors.safe;
        label = 'Running';
        break;
      case PreventiveUiState.unavailable:
        background = tierColors.mediumContainer;
        foreground = tierColors.medium;
        label = 'Unavailable';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelMedium?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildDescription(
    BuildContext context, {
    required PreventiveUiState uiState,
    required String? reason,
    required DateTime? nextPlannedRun,
    required DateTime? nextPeak,
  }) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final colorScheme = theme.colorScheme;
    final timeFormat = DateFormat('HH:mm');

    switch (uiState) {
      case PreventiveUiState.off:
        return Text(
          'Automated pre-ventilation is turned off in Settings.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
      case PreventiveUiState.armed:
        final runStr = nextPlannedRun != null
            ? timeFormat.format(nextPlannedRun.toLocal())
            : '--:--';
        final peakStr = nextPeak != null
            ? timeFormat.format(nextPeak.toLocal())
            : '--:--';
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Next run planned for $runStr (ahead of $peakStr predicted peak).',
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (reason != null) ...[
              const SizedBox(height: 4),
              Text(
                reason,
                style: textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        );
      case PreventiveUiState.running:
        return Text(
          'Pre-ventilation cycle is running (fixed duration).',
          style: textTheme.bodyMedium?.copyWith(
            color: context.tierColors.safe,
            fontWeight: FontWeight.w500,
          ),
        );
      case PreventiveUiState.unavailable:
        return Text(
          reason != null
              ? 'Unavailable: $reason'
              : 'Pre-ventilation is unavailable.',
          style: textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        );
    }
  }
}
