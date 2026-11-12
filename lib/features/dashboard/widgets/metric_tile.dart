import 'package:flutter/material.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/models/metric_tier.dart';
import 'package:aerosense_app/data/models/tier.dart';

/// Single metric display tile: icon, label, value+unit, individual tier badge.
///
/// Shows temperature (°C), humidity (%), or air quality (raw ADC index) with
/// tabular figures on the live value. Null/missing values render as "--".
/// Individual tier badge (dot + tier name) computed via [MetricTier] helpers.
class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.metricTier,
    this.caption,
  });

  final IconData icon;
  final String label;
  final double? value;
  final String unit;
  final Tier metricTier;
  final String? caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final tierColors = context.tierColors;

    final tierColor = tierColors.forTier(metricTier);
    final valueText = value != null ? value!.toStringAsFixed(1) : '--';

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
          // Header row: icon + label + tier badge
          Row(
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontVariations: [const FontVariation('wght', 500)],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _TierBadge(tier: metricTier, tierColor: tierColor),
            ],
          ),
          const SizedBox(height: 12),
          // Value row: large number + unit (scales down on high text zoom or narrow tiles)
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  valueText,
                  style: theme.textTheme.displaySmall?.copyWith(
                    fontSize: 44,
                    height: 48 / 44,
                    color: colorScheme.onSurface,
                    fontVariations: [const FontVariation('wght', 600)],
                    fontFeatures: [const FontFeature.tabularFigures()],
                  ),
                ),
                if (unit.isNotEmpty) ...[
                  const SizedBox(width: 4),
                  Text(
                    unit,
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontVariations: [const FontVariation('wght', 500)],
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (caption != null) ...[
            const SizedBox(height: 4),
            Text(
              caption!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Individual metric tier badge: colored dot + tier name (e.g. "Safe").
class _TierBadge extends StatelessWidget {
  const _TierBadge({required this.tier, required this.tierColor});

  final Tier tier;
  final TierColorPair tierColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: tierColor.container,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: tierColor.solid,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            _tierLabel(tier),
            style: theme.textTheme.labelSmall?.copyWith(
              color: tierColor.solid,
              fontVariations: [const FontVariation('wght', 500)],
            ),
          ),
        ],
      ),
    );
  }

  String _tierLabel(Tier tier) {
    switch (tier) {
      case Tier.safe:
        return 'Safe';
      case Tier.medium:
        return 'Medium';
      case Tier.danger:
        return 'Danger';
    }
  }
}
