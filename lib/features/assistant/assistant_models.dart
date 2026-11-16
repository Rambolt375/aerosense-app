import 'package:aerosense_app/data/models/assistant_message.dart';

/// Visible state of the Ask AeroSense screen.
enum AssistantStatus {
  /// No question asked yet.
  idle,

  /// A request is in flight.
  thinking,

  /// At least one answer is in the transcript.
  answered,

  /// The client-side limiter rejected the question.
  rateLimited,

  /// The request failed (network, quota, timeout, no summary, no repository).
  error,
}

/// In-memory-only chat state.
///
/// [messages] keeps the newest [maxMessages] messages and is never persisted.
class AssistantChatState {
  const AssistantChatState({
    this.status = AssistantStatus.idle,
    this.messages = const <AssistantMessage>[],
    this.errorMessage,
    this.retryAfter,
    this.lastQuestion,
  });

  final AssistantStatus status;
  final List<AssistantMessage> messages;

  /// Copy shown by the error block; null otherwise.
  final String? errorMessage;

  /// Wait time reported by the limiter; only set while rate limited.
  final Duration? retryAfter;

  /// Last attempted question, used by the "Try again" action.
  final String? lastQuestion;

  bool get isThinking => status == AssistantStatus.thinking;
}
