import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/dashboard/fan_card_state.dart';
import 'package:aerosense_app/features/dashboard/manual_toggle_notifier.dart';

/// Fan status card with timed manual ventilation button.
///
/// Features (Phase 6a):
/// - Replaces the toggle switch with a "Ventilate for N min" action button.
/// - Countdown displayed when fan is running ("Fan running, M:SS left").
/// - Countdown text is isolated in its own widget so the 1 s timer does not rebuild FanCard.
/// - Semantics announces ventilation start and end once, without repeating every second.
/// - Sentence case headers: "Fan on" / "Fan off".
class FanCard extends ConsumerStatefulWidget {
  const FanCard({super.key});

  @override
  ConsumerState<FanCard> createState() => _FanCardState();
}

class _FanCardState extends ConsumerState<FanCard> {
  FanCardUiState? _previousUiState;

  @override
  Widget build(BuildContext context) {
    // Listen for error messages and display them via SnackBar
    ref.listen<String?>(
      manualVentilationProvider.select((s) => s.errorMessage),
      (previous, next) {
        if (next != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(next), duration: const Duration(seconds: 4)),
          );
          ref.read(manualVentilationProvider.notifier).clearErrorMessage();
        }
      },
    );

    final systemState = ref.watch(systemStateProvider);
    final connected = ref.watch(connectedProvider);
    final deviceStatus = ref.watch(deviceStatusProvider);
    final ventilationState = ref.watch(manualVentilationProvider);
    final manualDuration = ref.watch(manualDurationProvider);

    return systemState.when(
      data: (state) {
        final appConnected = connected.asData?.value ?? false;
        final deviceOffline = deviceStatus.isOffline;
        final now = DateTime.now();

        // Target end time calculation & clamping
        DateTime? targetEndsAt;
        if (state.manualEndsAt != null) {
          targetEndsAt = clampManualEndsAt(
            manualEndsAt: state.manualEndsAt,
            now: now,
            knownDuration: manualDuration,
          );
        } else if (manualDuration != null &&
            ventilationState.observedRunStartedAt != null) {
          targetEndsAt = clampManualEndsAt(
            manualEndsAt: ventilationState.observedRunStartedAt!.add(
              manualDuration,
            ),
            now: now,
            knownDuration: manualDuration,
          );
        }

        final isWaitingForDevice = evaluateWaitingForDevice(
          manualToggle: state.manualToggle,
          endsAt: targetEndsAt,
          now: now,
        );

        final dangerLatchActive = evaluateDangerLatch(
          tier: state.tier,
          fanOn: state.fanOn,
          manualToggle: state.manualToggle,
          dangerObservedSinceSafe: ventilationState.dangerObservedSinceSafe,
          unlatchedCautionHeldDuration:
              ventilationState.unlatchedCautionHeldDuration,
        );

        final uiState = deriveFanCardUiState(
          tier: state.tier,
          fanOn: state.fanOn,
          manualToggle: state.manualToggle,
          appConnected: appConnected,
          deviceOffline: deviceOffline,
          isPending: ventilationState.isPending,
          dangerLatchActive: dangerLatchActive,
          isWaitingForDevice: isWaitingForDevice,
        );

        // Accessibility semantics: announce start and end once
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          if (_previousUiState != null && _previousUiState != uiState) {
            final view = View.of(context);
            if (_previousUiState != FanCardUiState.running &&
                uiState == FanCardUiState.running) {
              SemanticsService.sendAnnouncement(
                view,
                AppStrings.semanticsVentilationStarted,
                TextDirection.ltr,
              );
            } else if (_previousUiState == FanCardUiState.running &&
                uiState != FanCardUiState.running) {
              SemanticsService.sendAnnouncement(
                view,
                AppStrings.semanticsVentilationEnded,
                TextDirection.ltr,
              );
            }
          }
          _previousUiState = uiState;
        });

        return _FanCardContent(
          state: state,
          uiState: uiState,
          manualDuration: manualDuration,
          targetEndsAt: targetEndsAt,
          onVentilatePressed: () async {
            try {
              await ref
                  .read(manualVentilationProvider.notifier)
                  .startVentilation();
            } catch (_) {
              // Error handled by notifier and snackbar listener
            }
          },
        );
      },
      loading: () => const _FanCardSkeleton(),
      error: (_, _) => const _FanCardError(),
    );
  }
}

class _FanCardContent extends StatelessWidget {
  const _FanCardContent({
    required this.state,
    required this.uiState,
    required this.manualDuration,
    required this.targetEndsAt,
    required this.onVentilatePressed,
  });

  final SystemState state;
  final FanCardUiState uiState;
  final Duration? manualDuration;
  final DateTime? targetEndsAt;
  final VoidCallback onVentilatePressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final isButtonEnabled = isFanButtonEnabled(uiState);
    final helperText = fanCardHelperText(
      state: uiState,
      manualDuration: manualDuration,
    );

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
          Row(
            children: [
              Icon(Icons.toys_outlined, size: 20, color: colorScheme.primary),
              const SizedBox(width: 8),
              Text(
                'Ventilation system',
                style: theme.textTheme.labelSmall?.copyWith(
                  letterSpacing: 1,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (uiState == FanCardUiState.pending)
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
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: .45),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(
                  state.fanOn
                      ? Icons.toys_outlined
                      : Icons.power_settings_new_outlined,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        state.fanOn ? AppStrings.fanOn : AppStrings.fanOff,
                        style: theme.textTheme.titleMedium,
                      ),
                      Text(
                        'Firmware safety rules remain in control.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                _FanStatePill(active: state.fanOn),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Primary action button
          SizedBox(
            width: double.infinity,
            child: FilledButton.tonal(
              onPressed: isButtonEnabled ? onVentilatePressed : null,
              child: _buildButtonContent(context),
            ),
          ),
          const SizedBox(height: 8),

          // Helper text
          Text(
            helperText,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildButtonContent(BuildContext context) {
    if (uiState == FanCardUiState.running) {
      return VentilationCountdownText(
        endsAt: targetEndsAt,
        fallbackText: 'Fan running',
      );
    }

    final label = fanButtonLabel(
      state: uiState,
      manualDuration: manualDuration,
    );
    return Text(label);
  }
}

class _FanStatePill extends StatelessWidget {
  const _FanStatePill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final color = active
        ? context.tierColors.safe
        : Theme.of(context).colorScheme.onSurfaceVariant;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(
        active ? 'Running' : 'Standby',
        style: Theme.of(context).textTheme.labelSmall
            ?.copyWith(color: color, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Standalone countdown widget that rebuilds ONLY itself every second.
///
/// Keeps the parent [FanCard] from incurring full widget rebuilds.
class VentilationCountdownText extends StatefulWidget {
  const VentilationCountdownText({
    super.key,
    required this.endsAt,
    required this.fallbackText,
  });

  final DateTime? endsAt;
  final String fallbackText;

  @override
  State<VentilationCountdownText> createState() =>
      _VentilationCountdownTextState();
}

class _VentilationCountdownTextState extends State<VentilationCountdownText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startTimerIfNeeded();
  }

  @override
  void didUpdateWidget(VentilationCountdownText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _startTimerIfNeeded();
    }
  }

  void _startTimerIfNeeded() {
    _timer?.cancel();
    _timer = null;
    if (widget.endsAt != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (!mounted) return;
        final now = DateTime.now();
        if (widget.endsAt!.difference(now) <= Duration.zero) {
          _timer?.cancel();
          _timer = null;
        }
        setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.endsAt == null) {
      return Text(widget.fallbackText);
    }

    final now = DateTime.now();
    final remaining = widget.endsAt!.difference(now);
    if (remaining <= Duration.zero) {
      return Text(AppStrings.fanRunningWithCountdown('0:00'));
    }

    return Text(AppStrings.fanRunningWithCountdown(formatCountdown(remaining)));
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
            width: 100,
            height: 20,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            height: 40,
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
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
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        'Unable to load fan status',
        style: theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error),
      ),
    );
  }
}
