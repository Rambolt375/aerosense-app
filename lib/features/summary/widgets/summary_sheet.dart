import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

/// Scrollable bottom-sheet content for the deterministic summary.
///
/// Works without network or Firebase AI. The language selector only changes
/// the summary content; the sheet chrome stays English.
class SummarySheet extends ConsumerWidget {
  const SummarySheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final result = ref.watch(summaryResultProvider);
    final language = ref.watch(summaryLanguageProvider);
    final maxHeight = MediaQuery.sizeOf(context).height * 0.9;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 640),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          AppStrings.summaryTitle,
                          style: theme.textTheme.titleLarge,
                        ),
                      ),
                      if (result != null)
                        TextButton.icon(
                          onPressed: () => _copy(context, result.plainText),
                          icon: const Icon(Icons.copy_all_outlined, size: 18),
                          label: const Text(AppStrings.summaryCopy),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<SummaryLanguage>(
                    segments: const [
                      ButtonSegment(
                        value: SummaryLanguage.en,
                        label: Text(AppStrings.languageEnglish),
                      ),
                      ButtonSegment(
                        value: SummaryLanguage.id,
                        label: Text(AppStrings.languageIndonesia),
                      ),
                    ],
                    selected: {language},
                    onSelectionChanged: (selection) {
                      ref
                          .read(summaryLanguageProvider.notifier)
                          .select(selection.first);
                    },
                  ),
                  const SizedBox(height: 20),
                  if (result == null)
                    _NoData(theme: theme)
                  else
                    Text(result.plainText, style: theme.textTheme.bodyMedium),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainerHighest,
                      border: Border.all(
                        color: theme.colorScheme.outline,
                        width: 1,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      AppStrings.summaryDisclaimer,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _copy(BuildContext context, String text) {
    unawaited(Clipboard.setData(ClipboardData(text: text)));
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(const SnackBar(content: Text(AppStrings.summaryCopied)));
  }
}

class _NoData extends StatelessWidget {
  const _NoData({required this.theme});

  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.query_stats_outlined,
          size: 40,
          color: theme.colorScheme.onSurfaceVariant,
        ),
        const SizedBox(height: 12),
        Text(AppStrings.summaryNoDataTitle, style: theme.textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(
          AppStrings.summaryNoDataBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
