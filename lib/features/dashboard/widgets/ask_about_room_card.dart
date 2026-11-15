import 'package:flutter/material.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/features/summary/widgets/summary_sheet.dart';

/// Dashboard entry point for the deterministic summary.
///
/// The "Ask AeroSense" assistant action is added in slice 7b-2 behind
/// `AppConfig.assistantEnabled`, so this card never exposes a dead action.
class AskAboutRoomCard extends StatelessWidget {
  const AskAboutRoomCard({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              AppStrings.askAboutRoomTitle,
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
            OutlinedButton.icon(
              onPressed: () => _openSummary(context),
              icon: const Icon(Icons.summarize_outlined),
              label: const Text(AppStrings.summarize),
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
