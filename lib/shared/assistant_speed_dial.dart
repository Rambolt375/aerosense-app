import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';
import 'package:aerosense_app/features/summary/widgets/summary_sheet.dart';

/// Space reserved at the end of shell scroll views for the floating actions.
const assistantSpeedDialContentInset = 96.0;

/// Expandable entry point for the deterministic summary and optional assistant.
///
/// This belongs to the shell instead of a tab, ensuring every shell screen has
/// one consistent entry point and that it is absent from full-screen routes.
class AssistantSpeedDial extends ConsumerStatefulWidget {
  const AssistantSpeedDial({super.key});

  @override
  ConsumerState<AssistantSpeedDial> createState() => _AssistantSpeedDialState();
}

class _AssistantSpeedDialState extends ConsumerState<AssistantSpeedDial> {
  bool _isExpanded = false;
  final FocusNode _focusNode = FocusNode(debugLabel: 'assistant-speed-dial');

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  void _collapse() {
    if (_isExpanded) setState(() => _isExpanded = false);
  }

  void _onMainPressed(bool assistantAvailable) {
    if (!assistantAvailable) {
      _openSummary();
      return;
    }
    setState(() => _isExpanded = !_isExpanded);
    _focusNode.requestFocus();
  }

  void _openSummary() {
    _collapse();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const SummarySheet(),
    );
  }

  void _openAssistant() {
    _collapse();
    context.push('/assistant');
  }

  @override
  Widget build(BuildContext context) {
    final assistantAvailable = ref.watch(assistantEnabledProvider);
    final isDemo = ref.watch(demoModeProvider);
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final duration = disableAnimations
        ? Duration.zero
        : const Duration(milliseconds: 250);
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !_isExpanded,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _collapse();
      },
      child: TapRegion(
        onTapOutside: (_) => _collapse(),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Focus(
            focusNode: _focusNode,
            onKeyEvent: (_, event) {
              if (event is KeyDownEvent &&
                  event.logicalKey == LogicalKeyboardKey.escape) {
                _collapse();
                return KeyEventResult.handled;
              }
              return KeyEventResult.ignored;
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                AnimatedSize(
                  duration: duration,
                  curve: Curves.easeOut,
                  alignment: Alignment.bottomCenter,
                  child: _isExpanded
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(2),
                              child: _ActionButton(
                                icon: Icons.summarize_outlined,
                                label: AppStrings.summarize,
                                onPressed: _openSummary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FocusTraversalOrder(
                              order: const NumericFocusOrder(3),
                              child: _ActionButton(
                                icon: Icons.forum_outlined,
                                label: isDemo
                                    ? AppStrings.askAeroSenseScripted
                                    : AppStrings.askAeroSense,
                                onPressed: _openAssistant,
                              ),
                            ),
                            const SizedBox(height: 12),
                          ],
                        )
                      : const SizedBox.shrink(),
                ),
                FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FloatingActionButton(
                    tooltip: AppStrings.assistantMenu,
                    elevation: 0,
                    focusElevation: 0,
                    hoverElevation: 0,
                    backgroundColor: colorScheme.secondaryContainer,
                    foregroundColor: colorScheme.onSecondaryContainer,
                    shape: CircleBorder(
                      side: BorderSide(color: colorScheme.outline, width: 1),
                    ),
                    onPressed: () => _onMainPressed(assistantAvailable),
                    child: Icon(
                      _isExpanded ? Icons.close : Icons.auto_awesome_outlined,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FloatingActionButton.extended(
      heroTag: label,
      elevation: 0,
      focusElevation: 0,
      hoverElevation: 0,
      backgroundColor: colorScheme.secondaryContainer,
      foregroundColor: colorScheme.onSecondaryContainer,
      shape: StadiumBorder(
        side: BorderSide(color: colorScheme.outline, width: 1),
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
