import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/features/assistant/rate_limiter.dart';

class _TestClock {
  _TestClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

void main() {
  final start = DateTime(2026, 11, 15, 14, 0);

  test('defaults match the approved assistant limits', () {
    final limiter = SlidingWindowRateLimiter(clock: _TestClock(start).call);

    expect(limiter.maxQuestions, AppConfig.assistantMaxQuestionsPerWindow);
    expect(limiter.window, AppConfig.assistantRateWindow);
    expect(limiter.minSpacing, AppConfig.assistantMinQuestionSpacing);
    expect(limiter.maxQuestions, 6);
    expect(limiter.window, const Duration(minutes: 10));
    expect(limiter.minSpacing, const Duration(milliseconds: 1500));
  });

  test('allows six questions in ten minutes and rejects the seventh', () {
    final clock = _TestClock(start);
    final limiter = SlidingWindowRateLimiter(clock: clock.call);

    for (var i = 0; i < 6; i++) {
      final decision = limiter.tryAcquire('uid-1');
      expect(decision.isAllowed, isTrue, reason: 'attempt ${i + 1}');
      clock.advance(const Duration(seconds: 2));
    }

    // The loop advances past the sixth attempt, so the seventh lands at 12 s.
    final rejected = limiter.tryAcquire('uid-1');
    expect(rejected.isAllowed, isFalse);
    expect(rejected.outcome, RateLimitOutcome.windowExceeded);
    expect(
      rejected.retryAfter,
      const Duration(minutes: 10) - const Duration(seconds: 12),
    );
  });

  test('enforces a 1.5 second gap between questions', () {
    final clock = _TestClock(start);
    final limiter = SlidingWindowRateLimiter(clock: clock.call);

    expect(limiter.tryAcquire('uid-1').isAllowed, isTrue);

    final tooFast = limiter.tryAcquire('uid-1');
    expect(tooFast.isAllowed, isFalse);
    expect(tooFast.outcome, RateLimitOutcome.tooFast);
    expect(tooFast.retryAfter, const Duration(milliseconds: 1500));

    clock.advance(const Duration(milliseconds: 1499));
    final almost = limiter.tryAcquire('uid-1');
    expect(almost.isAllowed, isFalse);
    expect(almost.retryAfter, const Duration(milliseconds: 1));

    clock.advance(const Duration(milliseconds: 1));
    expect(limiter.tryAcquire('uid-1').isAllowed, isTrue);
  });

  test('rejected attempts do not consume quota', () {
    final clock = _TestClock(start);
    final limiter = SlidingWindowRateLimiter(clock: clock.call);

    expect(limiter.tryAcquire('uid-1').isAllowed, isTrue);
    expect(limiter.tryAcquire('uid-1').isAllowed, isFalse);

    var allowed = 1;
    for (var i = 0; i < 5; i++) {
      clock.advance(const Duration(seconds: 2));
      if (limiter.tryAcquire('uid-1').isAllowed) allowed++;
    }

    expect(allowed, 6);
    expect(limiter.tryAcquire('uid-1').isAllowed, isFalse);
  });

  test('counts each uid in its own window', () {
    final clock = _TestClock(start);
    final limiter = SlidingWindowRateLimiter(clock: clock.call);

    for (var i = 0; i < 6; i++) {
      limiter.tryAcquire('uid-1');
      clock.advance(const Duration(seconds: 2));
    }

    expect(limiter.tryAcquire('uid-1').isAllowed, isFalse);
    expect(limiter.tryAcquire('uid-2').isAllowed, isTrue);
  });

  test('frees quota once the oldest attempt leaves the window', () {
    final clock = _TestClock(start);
    final limiter = SlidingWindowRateLimiter(clock: clock.call);

    for (var i = 0; i < 6; i++) {
      limiter.tryAcquire('uid-1');
      clock.advance(const Duration(seconds: 2));
    }
    expect(limiter.tryAcquire('uid-1').isAllowed, isFalse);

    clock.advance(const Duration(minutes: 10));
    expect(limiter.tryAcquire('uid-1').isAllowed, isTrue);
  });

  test('anonymous callers share one bucket', () {
    final clock = _TestClock(start);
    final limiter = SlidingWindowRateLimiter(clock: clock.call);

    expect(
      limiter.tryAcquire(SlidingWindowRateLimiter.anonymousUid).isAllowed,
      isTrue,
    );
    final second = limiter.tryAcquire(SlidingWindowRateLimiter.anonymousUid);
    expect(second.isAllowed, isFalse);
    expect(second.outcome, RateLimitOutcome.tooFast);
  });
}
