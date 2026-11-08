import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/manual_toggle_notifier.dart';

/// Fan status card with manual toggle switch.
///
/// Toggle behavior (PRD FR-4):
/// - Safe: enabled, "Manual override is on. The fan is running." when on
/// - Medium: enabled, prominent decision moment
/// - Danger: disabled/locked, reflects fanOn state, no writes
/// - Offline: disabled with explanation
class FanCard extends ConsumerWidget {
  const FanCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemState = ref.watch(systemStateProvider);
    final connected = ref.watch(connectedProvider);
    final toggleState = ref.watch(manualToggleProvider);

    return systemState.when(
      data: (state) => _FanCardContent(
        state: state,
        connected: connected.asData?.value ?? false,
        toggleState: toggleState,
        onToggleChanged: (value) async {
          try {
            await ref.read(manualToggleProvider.notifier).setToggle(value);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Failed to update fan toggle. Check connection.',
                  ),
                  duration: Duration(seconds: 3),
                ),
              );
            }
          }
        },
      ),
      loading: () => const _FanCardSkeleton(),
      error: (_, _) => const _FanCardError(),
    );
  }
}

class _FanCardContent extends StatelessWidget {
  const _FanCardContent({
    required this.state,
    required this.connected,
    required this.toggleState,
    required this.onToggleChanged,
  });

  final SystemState state;
  final bool connected;
  final ManualToggleState toggleState;
  final Future<void> Function(bool) onToggleChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isOffline = !connected;
    final isDanger = state.tier == Tier.danger;
    final isEnabled = !isOffline && !isDanger;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row: fan icon + status
          Row(
            children: [
              // Flutter's Icons lacks Material Symbols' mode_fan;
              // toys_outlined is the standard 4-blade fan pinwheel in MaterialIcons.
              Icon(
                state.fanOn ? Icons.toys_outlined : Icons.mode_fan_off_outlined,
                size: 24,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Text(
                state.fanOn ? 'Fan On' : 'Fan Off',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: colorScheme.onSurface,
                  fontVariations: [const FontVariation('wght', 600)],
                ),
              ),
              const Spacer(),
              if (toggleState.isPending)
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: colorScheme.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          // Toggle switch
          Row(
            children: [
              Text(
                'Manual control',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface,
                ),
              ),
              const Spacer(),
              Switch(
                value: isDanger ? state.fanOn : toggleState.value,
                onChanged: isEnabled ? (v) => onToggleChanged(v) : null,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Helper text
          Text(
            _helperText(state.tier, toggleState.value, isOffline),
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  String _helperText(Tier tier, bool manualToggle, bool isOffline) {
    if (isOffline) {
      return 'App is offline. Fan control unavailable.';
    }
    switch (tier) {
      case Tier.safe:
        return manualToggle
            ? 'Manual override is on. The fan is running.'
            : 'Manual toggle forces the fan on.';
      case Tier.medium:
        return 'Room is stuffy. The fan stays off unless you turn it on.';
      case Tier.danger:
        return 'Safety override active. The fan is forced on and manual control is bypassed.';
    }
  }
}

class _FanCardSkeleton extends StatelessWidget {
  const _FanCardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      height: 140,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 120,
            height: 20,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            height: 16,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ],
      ),
    );
  }
}

class _FanCardError extends StatelessWidget {
  const _FanCardError();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: colorScheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Failed to load fan status.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}
