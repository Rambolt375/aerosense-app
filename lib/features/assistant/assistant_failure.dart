import 'package:aerosense_app/core/strings.dart';

/// Why an assistant request failed, reduced to the cases the screen treats
/// differently.
///
/// Provider-neutral on purpose: nothing here imports an HTTP or Firebase SDK,
/// so the screen, the chat notifier and the tests never learn about the
/// transport.
enum AssistantFailure {
  /// 400/403: missing or rejected build-time key, disabled API, or a bad
  /// request. The build is misconfigured, so a retry cannot help.
  serviceUnavailable,

  /// 429: the free-tier quota is spent. No retry.
  busy,

  /// 503 / overloaded after the single automatic retry.
  busyAfterRetry,

  /// Offline, unreachable, or past the 20 s timeout.
  network,

  /// Safety filters or the provider blocked the answer.
  blocked,

  /// The provider returned no text at all.
  empty,

  /// Anything unclassified.
  unknown,
}

/// Failure raised by an [AssistantRepository] implementation.
///
/// The screen shows [assistantFailureMessage] for [failure] and keeps the
/// deterministic summary instead: there is no automatic retry beyond the one
/// documented 503 retry inside the repository.
class AssistantException implements Exception {
  const AssistantException(this.failure);

  final AssistantFailure failure;

  @override
  String toString() => 'AssistantException($failure)';
}

/// Friendly, non-technical copy for each failure.
///
/// The screen renders the deterministic summary underneath, so a failure never
/// leaves the visitor with nothing.
String assistantFailureMessage(AssistantFailure failure) {
  return switch (failure) {
    AssistantFailure.serviceUnavailable => AppStrings.assistantFailureSetup,
    AssistantFailure.busy => AppStrings.assistantFailureBusy,
    AssistantFailure.busyAfterRetry =>
      AppStrings.assistantFailureBusyAfterRetry,
    AssistantFailure.network => AppStrings.assistantFailureNoConnection,
    AssistantFailure.blocked ||
    AssistantFailure.empty => AppStrings.assistantFailureNoAnswer,
    AssistantFailure.unknown => AppStrings.assistantFailureNoAnswer,
  };
}
