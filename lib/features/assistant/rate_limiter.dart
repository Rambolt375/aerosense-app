import 'package:aerosense_app/core/config.dart';

/// Why a question was rejected by the client-side limiter.
enum RateLimitOutcome {
  /// The question may be sent.
  allowed,

  /// Another question was asked less than [SlidingWindowRateLimiter.minSpacing]
  /// ago.
  tooFast,

  /// The per-uid budget inside [SlidingWindowRateLimiter.window] is exhausted.
  windowExceeded,
}

/// Result of one limiter check.
class RateLimitDecision {
  const RateLimitDecision(this.outcome, [this.retryAfter = Duration.zero]);

  final RateLimitOutcome outcome;

  /// How long the caller should wait before asking again.
  final Duration retryAfter;

  bool get isAllowed => outcome == RateLimitOutcome.allowed;
}

/// In-memory sliding-window limiter for Ask AeroSense.
///
/// Six questions per ten minutes per signed-in uid plus a 1.5 s minimum gap.
/// The clock is injected so the window is deterministic in tests. This is an
/// advisory client limit; App Check and the project quota are the real ceiling.
class SlidingWindowRateLimiter {
  SlidingWindowRateLimiter({
    required this.clock,
    this.maxQuestions = AppConfig.assistantMaxQuestionsPerWindow,
    this.window = AppConfig.assistantRateWindow,
    this.minSpacing = AppConfig.assistantMinQuestionSpacing,
  });

  /// Bucket used while signed out (e.g. an unauthenticated demo session).
  static const String anonymousUid = 'anonymous';

  final DateTime Function() clock;
  final int maxQuestions;
  final Duration window;
  final Duration minSpacing;

  final Map<String, List<DateTime>> _attempts = <String, List<DateTime>>{};

  /// Checks the budget for [uid] and records the attempt when allowed.
  RateLimitDecision tryAcquire(String uid) {
    final now = clock();
    final attempts = _attempts[uid] ?? <DateTime>[];
    attempts.removeWhere((attempt) => now.difference(attempt) >= window);

    if (attempts.isNotEmpty) {
      final sinceLast = now.difference(attempts.last);
      if (sinceLast < minSpacing) {
        _attempts[uid] = attempts;
        return RateLimitDecision(
          RateLimitOutcome.tooFast,
          _nonNegative(minSpacing - sinceLast),
        );
      }
    }

    if (attempts.length >= maxQuestions) {
      _attempts[uid] = attempts;
      return RateLimitDecision(
        RateLimitOutcome.windowExceeded,
        _nonNegative(window - now.difference(attempts.first)),
      );
    }

    attempts.add(now);
    _attempts[uid] = attempts;
    return const RateLimitDecision(RateLimitOutcome.allowed);
  }

  static Duration _nonNegative(Duration duration) {
    return duration.isNegative ? Duration.zero : duration;
  }
}
