import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/summary/widgets/summary_sheet.dart';

/// Dashboard entry point for the deterministic summary and Ask AeroSense.
///
/// The assistant action is only shown when [AppConfig.assistantEnabled] is true
/// (slice 7b-3) or in Demo Mode, so the card never exposes a dead action. The
/// fan button on the dashboard remains the single primary action.
class AskAboutRoomCard extends ConsumerWidget {
  const AskAboutRoomCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final assistantAvailable =
        AppConfig.assistantEnabled || ref.watch(demoModeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              assistantAvailable
                  ? AppStrings.askAboutRoomTitle
                  : AppStrings.roomSummaryTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              AppStrings.askAboutRoomBody,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: () => _openSummary(context),
                  icon: const Icon(Icons.summarize_outlined),
                  label: const Text(AppStrings.summarize),
                ),
                if (assistantAvailable)
                  OutlinedButton.icon(
                    onPressed: () => context.push('/assistant'),
                    icon: const Icon(Icons.forum_outlined),
                    label: const Text(AppStrings.askAeroSense),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openSummary(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) => const SummarySheet(),
    );
  }
}
