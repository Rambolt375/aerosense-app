import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_copy.dart';
import 'package:aerosense_app/features/assistant/assistant_models.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

/// Maximum width shared by the transcript and the composer on wide screens.
const double assistantContentMaxWidth = 840;

/// The character count above which the composer shows `n/300`.
const int assistantCounterVisibleAbove = 240;

/// Full-screen Ask AeroSense route.
///
/// Deliberately outside the navigation shell: no fifth tab. One short
/// disclaimer line sits under the composer; the full wording, including the
/// privacy sentence, lives in the "About this assistant" sheet. Nothing is
/// stored.
class AssistantScreen extends ConsumerWidget {
  const AssistantScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(assistantChatProvider);
    final language = ref.watch(summaryLanguageProvider);
    final isDemo = ref.watch(demoModeProvider);
    final summary = ref.watch(summaryResultProvider);
    final copy = AssistantCopy(language);
    final width = MediaQuery.sizeOf(context).width;
    final padding = width < 600 ? 16.0 : 24.0;
    final notifier = ref.read(assistantChatProvider.notifier);

    return Scaffold(
      appBar: AppBar(title: const Text(AppStrings.askAeroSense)),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: assistantContentMaxWidth,
            ),
            child: Column(
              children: [
                Expanded(
                  child: _Transcript(
                    signature: Object.hash(
                      state.messages.length,
                      state.pendingQuestion,
                      state.isThinking,
                      state.status,
                      language,
                    ),
                    padding: EdgeInsets.fromLTRB(padding, 8, padding, 16),
                    children: [
                      if (isDemo) ...[
                        Text(
                          copy.demoScriptedNote,
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
                      // The in-flight question is rendered as a visitor bubble
                      // here before any answer exists.
                      for (final message in state.visibleMessages)
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
                _Footer(padding: padding, copy: copy, isDemo: isDemo),
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

/// Scrollable transcript that keeps the newest message in view.
///
/// [signature] changes whenever a message is added, the thinking bubble appears
/// or disappears, or the language switches, which is exactly when the view
/// should follow the bottom. With `disableAnimations` it jumps instead of
/// animating.
class _Transcript extends StatefulWidget {
  const _Transcript({
    required this.signature,
    required this.padding,
    required this.children,
  });

  final int signature;
  final EdgeInsets padding;
  final List<Widget> children;

  @override
  State<_Transcript> createState() => _TranscriptState();
}

class _TranscriptState extends State<_Transcript> {
  final ScrollController _controller = ScrollController();

  @override
  void didUpdateWidget(covariant _Transcript oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.signature != widget.signature) _scrollToNewest();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _scrollToNewest() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients) return;
      final position = _controller.position;
      final target = position.maxScrollExtent;
      if (position.pixels >= target) return;
      final disableAnimations =
          MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      if (disableAnimations) {
        _controller.jumpTo(target);
      } else {
        _controller.animateTo(
          target,
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: _controller,
      padding: widget.padding,
      children: widget.children,
    );
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

/// Full-width composer with an in-field Send button.
///
/// Enter sends and Shift+Enter inserts a newline on web and desktop. Both are
/// bound explicitly (rather than relying on `onSubmitted`) so the behaviour is
/// identical across platforms and testable.
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
  final FocusNode _focusNode = FocusNode(debugLabel: 'assistant-composer');

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  bool get _canSend => widget.enabled && _controller.text.trim().isNotEmpty;

  void _handleSend() {
    if (!_canSend) return;
    widget.onSend(_controller.text.trim());
    _controller.clear();
    setState(() {});
    // Keep the caret in the field so the visitor can ask again immediately.
    _focusNode.requestFocus();
  }

  /// Inserts a newline at the caret, honouring the character cap.
  void _insertNewline() {
    final value = _controller.value;
    final text = value.text;
    if (text.length >= AppConfig.assistantMaxInputChars) return;

    final selection = value.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final updated = text.replaceRange(start, end, '\n');
    _controller.value = TextEditingValue(
      text: updated,
      selection: TextSelection.collapsed(offset: start + 1),
    );
    setState(() {});
  }

  String? get _counterText {
    final length = _controller.text.characters.length;
    if (length <= assistantCounterVisibleAbove) return '';
    return '$length/${AppConfig.assistantMaxInputChars}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: EdgeInsets.fromLTRB(widget.padding, 4, widget.padding, 0),
      child: CallbackShortcuts(
        bindings: {
          const SingleActivator(LogicalKeyboardKey.enter): _handleSend,
          const SingleActivator(LogicalKeyboardKey.enter, shift: true):
              _insertNewline,
        },
        child: TextField(
          controller: _controller,
          focusNode: _focusNode,
          minLines: 1,
          maxLines: 4,
          maxLength: AppConfig.assistantMaxInputChars,
          textInputAction: TextInputAction.send,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            hintText: AppStrings.assistantInputHint,
            border: const OutlineInputBorder(),
            counterText: _counterText,
            suffixIcon: IconButton(
              onPressed: _canSend ? _handleSend : null,
              tooltip: AppStrings.assistantSend,
              icon: const Icon(Icons.arrow_upward),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                foregroundColor: theme.colorScheme.onPrimary,
                backgroundColor: _canSend
                    ? theme.colorScheme.primary
                    : theme.colorScheme.surfaceContainerHighest,
                disabledForegroundColor: theme.colorScheme.onSurfaceVariant,
                shape: const CircleBorder(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One short disclaimer line plus the info button for the full wording.
class _Footer extends StatelessWidget {
  const _Footer({
    required this.padding,
    required this.copy,
    required this.isDemo,
  });

  final double padding;
  final AssistantCopy copy;
  final bool isDemo;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.fromLTRB(padding, 0, padding, 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              copy.disclaimerShort,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          IconButton(
            onPressed: () =>
                _showAboutSheet(context, copy: copy, isDemo: isDemo),
            tooltip: copy.aboutTitle,
            icon: const Icon(Icons.info_outline, size: 20),
            style: IconButton.styleFrom(
              minimumSize: const Size(48, 48),
              foregroundColor: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }

  void _showAboutSheet(
    BuildContext context, {
    required AssistantCopy copy,
    required bool isDemo,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final theme = Theme.of(sheetContext);
        final colorScheme = theme.colorScheme;
        return ConstrainedBox(
          key: const Key('assistant-about-sheet'),
          constraints: const BoxConstraints(maxWidth: 640),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(copy.aboutTitle, style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Text(copy.disclaimerFull, style: theme.textTheme.bodyMedium),
                const SizedBox(height: 8),
                Text(
                  copy.privacyFull,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  copy.scopeNote,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                if (isDemo) ...[
                  const SizedBox(height: 12),
                  Text(
                    copy.demoScriptedNote,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
