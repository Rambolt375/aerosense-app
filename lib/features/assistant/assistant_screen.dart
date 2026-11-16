import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_models.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

/// Full-screen Ask AeroSense route.
///
/// Deliberately outside the navigation shell: no fifth tab. The disclaimer and
/// the privacy line are pinned; the transcript scrolls. Nothing is stored.
class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(assistantChatProvider);
    final language = ref.watch(summaryLanguageProvider);
    final isDemo = ref.watch(demoModeProvider);
    final summary = ref.watch(summaryResultProvider);
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 16.0 : 24.0;
    final notifier = ref.read(assistantChatProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.askAeroSense)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.fromLTRB(padding, 8, padding, 16),
                    children: [
                      if (isDemo) ...[
                        Text(
                          AppStrings.assistantDemoScripted,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                      Align(
                        alignment: Alignment.centerLeft,
                        child: SegmentedButton<SummaryLanguage>(
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
                      ),
                      const SizedBox(height: 12),
                      if (state.status == AssistantStatus.idle &&
                          state.messages.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            AppStrings.assistantIntro,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      _SuggestedChips(
                        language: language,
                        enabled: !state.isThinking,
                        onSelected: notifier.ask,
                      ),
                      const SizedBox(height: 12),
                      for (final message in state.messages)
                        _MessageBubble(message: message),
                      if (state.isThinking) const _ThinkingIndicator(),
                      if (state.status == AssistantStatus.rateLimited)
                        _FallbackBlock(
                          icon: Icons.timer_outlined,
                          title: AppStrings.assistantRateLimitedTitle,
                          body: AppStrings.assistantRateLimitedBody(
                            formatWait(state.retryAfter),
                          ),
                          summary: summary,
                          onRetry: notifier.retry,
                        ),
                      if (state.status == AssistantStatus.error)
                        _FallbackBlock(
                          icon: Icons.cloud_off_outlined,
                          title: AppStrings.assistantErrorTitle,
                          body:
                              state.errorMessage ??
                              AppStrings.assistantErrorBody,
                          summary: summary,
                          onRetry: notifier.retry,
                        ),
                    ],
                  ),
                ),
                _Composer(
                  padding: padding,
                  enabled: !state.isThinking,
                  onSend: notifier.ask,
                ),
                _PinnedFooter(padding: padding),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Short, human wait label for the rate-limit block.
  static String formatWait(Duration? duration) {
    if (duration == null || duration <= Duration.zero) {
      return 'a moment';
    }
    final seconds = duration.inSeconds;
    if (seconds < 60) {
      return seconds == 1 ? '1 second' : '$seconds seconds';
    }
    final minutes = (seconds / 60).ceil();
    return minutes == 1 ? '1 minute' : '$minutes minutes';
  }
}

class _SuggestedChips extends StatelessWidget {
  const _SuggestedChips({
    required this.language,
    required this.enabled,
    required this.onSelected,
  });

  final SummaryLanguage language;
  final bool enabled;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final chips = language == SummaryLanguage.id
        ? AppStrings.assistantChipsIndonesian
        : AppStrings.assistantChipsEnglish;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final chip in chips)
          ActionChip(
            label: Text(chip),
            onPressed: enabled ? () => onSelected(chip) : null,
          ),
      ],
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({required this.message});

  final AssistantMessage message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isVisitor = message.role == AssistantRole.visitor;

    return Align(
      alignment: isVisitor ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 560),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: isVisitor
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          border: Border.all(color: theme.colorScheme.outline, width: 1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          message.text,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: isVisitor
                ? theme.colorScheme.onPrimaryContainer
                : theme.colorScheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _ThinkingIndicator extends StatelessWidget {
  const _ThinkingIndicator();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text(
            AppStrings.assistantThinking,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _FallbackBlock extends StatelessWidget {
  const _FallbackBlock({
    required this.icon,
    required this.title,
    required this.body,
    required this.summary,
    required this.onRetry,
  });

  final IconData icon;
  final String title;
  final String body;
  final SummaryResult? summary;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      margin: const EdgeInsets.only(top: 4, bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        border: Border.all(color: colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: 8),
              Expanded(child: Text(title, style: theme.textTheme.titleMedium)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text(AppStrings.assistantTryAgain),
          ),
          const Divider(height: 24),
          Text(
            AppStrings.assistantSummaryFallback,
            style: theme.textTheme.titleSmall,
          ),
          const SizedBox(height: 4),
          Text(
            summary?.plainText ?? AppStrings.summaryNoDataBody,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatefulWidget {
  const _Composer({
    required this.padding,
    required this.enabled,
    required this.onSend,
  });

  final double padding;
  final bool enabled;
  final ValueChanged<String> onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && _controller.text.trim().isNotEmpty;

  void _handleSend() {
    if (!_canSend) return;
    widget.onSend(_controller.text.trim());
    _controller.clear();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(widget.padding, 4, widget.padding, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _controller,
              minLines: 1,
              maxLines: 3,
              maxLength: AppConfig.assistantMaxInputChars,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _handleSend(),
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(
                hintText: AppStrings.assistantInputHint,
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: _canSend ? _handleSend : null,
            child: const Text(AppStrings.assistantSend),
          ),
        ],
      ),
    );
  }
}

class _PinnedFooter extends StatelessWidget {
  const _PinnedFooter({required this.padding});

  final double padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(padding, 12, padding, 12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outline, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            AppStrings.assistantDisclaimer,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            AppStrings.assistantPrivacy,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
