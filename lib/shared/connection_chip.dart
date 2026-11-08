import 'package:flutter/material.dart';

/// Compact connection status pill showing app-to-Firebase RTDB state.
///
/// Displays "Online" (Wi-Fi icon) or "Offline" (Wi-Fi off icon) in a
/// 28 dp height chip styled per DESIGN.md §5.
class ConnectionChip extends StatelessWidget {
  const ConnectionChip({super.key, required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isConnected ? Icons.wifi : Icons.wifi_off,
            size: 16,
            color: colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 6),
          Text(
            isConnected ? 'Online' : 'Offline',
            style: theme.textTheme.labelMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
              fontVariations: [const FontVariation('wght', 500)],
            ),
          ),
        ],
      ),
    );
  }
}
