import 'package:flutter/material.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/models/tier.dart';

/// Full-width tier status banner showing color, icon, title, and firmware message.
///
/// Visual structure per DESIGN.md §5: container color background, 1 px solid
/// border, tier icon + title + verbatim statusMessage. Danger tier icon pulses
/// subtly (opacity animation) unless animations are disabled.
class TierBanner extends StatefulWidget {
  const TierBanner({
    super.key,
    required this.tier,
    required this.statusMessage,
  });

  final Tier tier;
  final String statusMessage;

  @override
  State<TierBanner> createState() => _TierBannerState();
}

class _TierBannerState extends State<TierBanner>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _opacityAnimation = Tween<double>(begin: 1.0, end: 0.4).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateAnimation();
  }

  @override
  void didUpdateWidget(TierBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tier != widget.tier) {
      _updateAnimation();
    }
  }

  void _updateAnimation() {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.tier == Tier.danger && !disableAnimations) {
      _pulseController.repeat(reverse: true);
    } else {
      _pulseController.stop();
      _pulseController.value = 0;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColors = context.tierColors;

    final (icon, title) = _tierContent(widget.tier);
    final solidColor = tierColors.forTier(widget.tier).solid;
    final containerColor = tierColors.forTier(widget.tier).container;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: containerColor,
        border: Border.all(color: solidColor, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedBuilder(
                animation: _opacityAnimation,
                builder: (context, child) {
                  return Opacity(
                    opacity: widget.tier == Tier.danger
                        ? _opacityAnimation.value
                        : 1.0,
                    child: child,
                  );
                },
                child: Icon(icon, size: 24, color: solidColor),
              ),
              const SizedBox(width: 12),
              Text(
                title,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: solidColor,
                  fontVariations: [const FontVariation('wght', 600)],
                ),
              ),
            ],
          ),
          if (widget.statusMessage.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              widget.statusMessage,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface,
              ),
            ),
          ],
        ],
      ),
    );
  }

  (IconData, String) _tierContent(Tier tier) {
    switch (tier) {
      case Tier.safe:
        return (Icons.check_circle_outlined, 'Room is safe');
      case Tier.medium:
        return (Icons.warning_amber_outlined, 'Room is getting stuffy');
      case Tier.danger:
        return (Icons.error_outline, 'Hazardous air detected');
    }
  }
}
