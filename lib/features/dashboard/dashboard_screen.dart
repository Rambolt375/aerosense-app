import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/dashboard/widgets/fan_card.dart';
import 'package:aerosense_app/features/dashboard/widgets/metric_grid.dart';
import 'package:aerosense_app/features/dashboard/widgets/tier_banner.dart';
import 'package:aerosense_app/shared/connection_chip.dart';

/// Live dashboard screen with metric tiles, tier banner, and fan control.
///
/// Subscribes to systemStateProvider, connectedProvider, and deviceStatusProvider.
/// Shows loading skeletons during initial load and an error card with Retry on stream failure.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final systemState = ref.watch(systemStateProvider);
    final connected = ref.watch(connectedProvider);
    final deviceStatus = ref.watch(deviceStatusProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Dashboard'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: connected.when(
              data: (c) => ConnectionChip(isConnected: c),
              loading: () => const ConnectionChip(isConnected: false),
              error: (_, _) => const ConnectionChip(isConnected: false),
            ),
          ),
        ],
      ),
      body: systemState.when(
        skipLoadingOnReload: true,
        data: (state) =>
            _DashboardContent(state: state, deviceStatus: deviceStatus),
        loading: () => const _DashboardSkeleton(),
        error: (error, _) => _DashboardError(
          error: error,
          onRetry: () => ref.invalidate(systemStateProvider),
        ),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.state, required this.deviceStatus});

  final SystemState state;
  final DeviceStatus deviceStatus;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final padding = width < 600 ? 16.0 : 24.0;
    final isDeviceOffline = deviceStatus.isOffline;

    Widget content = ListView(
      padding: EdgeInsets.all(padding),
      children: [
        // Live tier banner or Device Offline notice
        if (isDeviceOffline)
          _buildOfflineBanner(context, theme)
        else
          TierBanner(tier: state.tier, statusMessage: state.statusMessage),
        const SizedBox(height: 24),

        // Metric tiles (dimmed when device is offline)
        Opacity(
          opacity: isDeviceOffline ? 0.45 : 1.0,
          child: MetricGrid(
            temperature: state.temperature,
            humidity: state.humidity,
            airQuality: state.airQuality,
          ),
        ),
        const SizedBox(height: 24),

        // Fan card
        const FanCard(),
        if (kDebugMode) ...[
          const SizedBox(height: 24),
          Center(
            child: TextButton.icon(
              icon: const Icon(Icons.bug_report_outlined),
              label: const Text('Debug: Raw /system'),
              onPressed: () => context.push('/debug'),
            ),
          ),
        ],
      ],
    );

    // Desktop: center with max width 1200
    if (isDesktop) {
      content = Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1200),
          child: content,
        ),
      );
    }

    return content;
  }

  Widget _buildOfflineBanner(BuildContext context, ThemeData theme) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        border: Border.all(color: theme.colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.cloud_off_outlined,
            size: 24,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Device offline',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontVariations: [const FontVariation('wght', 600)],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  deviceStatus.message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DashboardSkeleton extends StatelessWidget {
  const _DashboardSkeleton();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 16.0 : 24.0;

    return ListView(
      padding: EdgeInsets.all(padding),
      children: [
        // Tier banner skeleton
        Container(
          height: 80,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        const SizedBox(height: 24),
        // Metric tiles skeleton
        GridView.count(
          crossAxisCount: width < 600 ? 1 : (width < 900 ? 2 : 3),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 1.4,
          children: List.generate(
            3,
            (_) => Container(
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Fan card skeleton
        Container(
          height: 140,
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ],
    );
  }
}

class _DashboardError extends StatelessWidget {
  const _DashboardError({required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        margin: const EdgeInsets.all(24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.outline, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: colorScheme.error),
            const SizedBox(height: 16),
            Text(
              'Failed to load dashboard',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              'Check your connection and try again.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
