import 'package:flutter/material.dart';
import 'package:aerosense_app/core/theme.dart';

/// Connection status chip showing app-to-Firebase connection state.
///
/// Per DESIGN.md §5: Height 28, surfaceAlt background, label text, 20-24 dp outlined icon.
class ConnectionChip extends StatelessWidget {
  const ConnectionChip({super.key, required this.isConnected, this.label});

  final bool isConnected;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = context.appColors;

    final displayLabel = label ?? (isConnected ? 'Online' : 'Offline');
    final icon = isConnected ? Icons.wifi : Icons.wifi_off;

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: appColors.surfaceAlt,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outline, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 6),
          Text(displayLabel, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}
