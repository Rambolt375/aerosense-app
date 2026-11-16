import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/repositories/assistant_repository.dart';
import 'package:aerosense_app/data/repositories/fake_assistant_repository.dart';
import 'package:aerosense_app/data/repositories/gemini_rest_assistant_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_failure.dart';
import 'package:aerosense_app/features/assistant/assistant_models.dart';
import 'package:aerosense_app/features/assistant/assistant_prompt.dart';
import 'package:aerosense_app/features/assistant/rate_limiter.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

/// Gemini API key supplied at build time.
///
/// Overridable in tests; production reads the compile-time define from
/// `env.json` (web) or `env.android.json` (Android). It is never read from a
/// committed file at runtime.
final geminiApiKeyProvider = Provider<String>((ref) => AppConfig.geminiApiKey);

/// Whether the "Ask AeroSense" action and route are exposed.
///
/// True only in Demo Mode (scripted answers, no network) or when a build-time
/// key is present **and** a user is signed in. Web and Android use the same
/// rule. Without a key the action stays hidden; "Summarize" is unaffected.
final assistantEnabledProvider = Provider<bool>((ref) {
  if (ref.watch(demoModeProvider)) return true;
  if (ref.watch(geminiApiKeyProvider).isEmpty) return false;
  return ref.watch(currentUserUidProvider) != null;
});

/// Assistant repository.
///
/// Demo Mode answers are scripted from the same summary the deterministic
/// sheet shows, with no network. Outside Demo Mode the direct Gemini REST
/// repository is only created once [assistantEnabledProvider] is true, so no
/// request can be sent without a key or without a signed-in user.
final assistantRepositoryProvider = Provider<AssistantRepository?>((ref) {
  if (ref.watch(demoModeProvider)) {
    return FakeAssistantRepository(
      summaryInput: () => ref.read(summaryInputProvider),
    );
  }
  if (!ref.watch(assistantEnabledProvider)) return null;
  return GeminiRestAssistantRepository(apiKey: ref.watch(geminiApiKeyProvider));
});

/// One limiter per app session so the per-uid window survives reopening the
/// screen. Not auto-disposed: the budget must not reset on navigation.
final assistantRateLimiterProvider = Provider<SlidingWindowRateLimiter>((ref) {
  return SlidingWindowRateLimiter(clock: ref.watch(clockProvider));
});

/// One-request timeout, overridable in tests.
final assistantTimeoutProvider = Provider<Duration>(
  (ref) => AppConfig.assistantTimeout,
);

/// In-memory assistant conversation. Auto-disposed with the screen: nothing is
/// stored, nothing is logged, and reopening starts a fresh (empty) transcript.
class AssistantChatNotifier extends Notifier<AssistantChatState> {
  @override
  AssistantChatState build() => const AssistantChatState();

  /// Asks [question], enforcing the client limiter before any network call.
  Future<void> ask(String question) async {
    final trimmed = question.trim();
    if (trimmed.isEmpty) return;

    final current = state;
    if (current.isThinking) return;

    final repository = ref.read(assistantRepositoryProvider);
    if (repository == null) {
      state = AssistantChatState(
        status: AssistantStatus.error,
        messages: current.messages,
        errorMessage: AppStrings.assistantUnavailableBody,
        lastQuestion: trimmed,
      );
      return;
    }

    final summaryInput = ref.read(summaryInputProvider);
    if (summaryInput == null) {
      state = AssistantChatState(
        status: AssistantStatus.error,
        messages: current.messages,
        errorMessage: AppStrings.summaryNoDataBody,
        lastQuestion: trimmed,
      );
      return;
    }

    final uid =
        ref.read(currentUserUidProvider) ??
        SlidingWindowRateLimiter.anonymousUid;
    final decision = ref.read(assistantRateLimiterProvider).tryAcquire(uid);
    if (!decision.isAllowed) {
      state = AssistantChatState(
        status: AssistantStatus.rateLimited,
        messages: current.messages,
        retryAfter: decision.retryAfter,
        lastQuestion: trimmed,
      );
      return;
    }

    final history = List<AssistantMessage>.unmodifiable(current.messages);
    state = AssistantChatState(
      status: AssistantStatus.thinking,
      messages: current.messages,
      lastQuestion: trimmed,
    );

    final request = buildAssistantRequest(
      input: summaryInput,
      languageHint: ref.read(summaryLanguageProvider),
      history: history,
      question: trimmed,
    );

    try {
      final answer = await repository
          .ask(
            systemInstruction: request.systemInstruction,
            history: request.history,
            question: request.question,
          )
          .timeout(ref.read(assistantTimeoutProvider));

      // The screen may have been closed mid-request; auto-dispose owns cleanup.
      if (!ref.mounted) return;

      final messages = <AssistantMessage>[
        ...history,
        AssistantMessage(role: AssistantRole.visitor, text: request.question),
        AssistantMessage(role: AssistantRole.assistant, text: answer.trim()),
      ];
      state = AssistantChatState(
        status: AssistantStatus.answered,
        messages: _keepNewest(messages),
        lastQuestion: trimmed,
      );
    } catch (error) {
      if (!ref.mounted) return;
      // No automatic retry: the visible "Try again" action re-enters the
      // limiter and is the only way to send another request. Questions and
      // answers are never logged, in any build.
      state = AssistantChatState(
        status: AssistantStatus.error,
        messages: history,
        errorMessage: error is AssistantException
            ? assistantFailureMessage(error.failure)
            : AppStrings.assistantErrorBody,
        lastQuestion: trimmed,
      );
    }
  }

  /// Repeats the last question. Goes through [ask] so the limiter still applies.
  Future<void> retry() async {
    final question = state.lastQuestion;
    if (question == null) return;
    await ask(question);
  }

  static List<AssistantMessage> _keepNewest(List<AssistantMessage> messages) {
    if (messages.length <= AppConfig.assistantMaxMessages) {
      return List<AssistantMessage>.unmodifiable(messages);
    }
    return List<AssistantMessage>.unmodifiable(
      messages.sublist(messages.length - AppConfig.assistantMaxMessages),
    );
  }
}

/// The transcript lives only in memory and dies with the route.
final assistantChatProvider =
    NotifierProvider<AssistantChatNotifier, AssistantChatState>(
      AssistantChatNotifier.new,
      isAutoDispose: true,
    );
