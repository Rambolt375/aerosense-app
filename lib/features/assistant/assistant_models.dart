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
/// [pendingQuestion] is the visitor's in-flight question: it is rendered as a
/// bubble immediately, but it is deliberately **not** part of [messages] and
/// never enters the history sent to the repository.
class AssistantChatState {
  const AssistantChatState({
    this.status = AssistantStatus.idle,
    this.messages = const <AssistantMessage>[],
    this.errorMessage,
    this.retryAfter,
    this.lastQuestion,
    this.pendingQuestion,
  });

  final AssistantStatus status;
  final List<AssistantMessage> messages;

  /// Copy shown by the error block; null otherwise.
  final String? errorMessage;

  /// Wait time reported by the limiter; only set while rate limited.
  final Duration? retryAfter;

  /// Last attempted question, used by the "Try again" action.
  final String? lastQuestion;

  /// Visitor question currently in flight, or the one that failed.
  ///
  /// Rendered above the thinking bubble (and above the error card) so the
  /// visitor always sees what was asked, without duplicating it on retry.
  final String? pendingQuestion;

  bool get isThinking => status == AssistantStatus.thinking;

  /// The transcript as rendered: previous messages, then the in-flight or
  /// failed question when there is one.
  List<AssistantMessage> get visibleMessages {
    final question = pendingQuestion;
    if (question == null) return messages;
    return <AssistantMessage>[
      ...messages,
      AssistantMessage(role: AssistantRole.visitor, text: question),
    ];
  }
}
