import 'dart:async';

import 'package:aerosense_app/core/strings.dart';

/// Why an assistant request failed, reduced to the cases the screen treats
/// differently.
///
/// Provider-neutral on purpose: nothing here imports a Firebase SDK, so the
/// screen, the chat notifier and the tests never learn about `firebase_ai`.
enum AssistantFailure {
  /// Project or per-user question budget is spent.
  quota,

  /// App Check rejected, the API is disabled, or the key is invalid (403).
  serviceUnavailable,

  /// The configured model is gone; the only case worth one fallback model.
  modelUnavailable,

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
/// deterministic summary instead: there is no automatic retry.
class AssistantException implements Exception {
  const AssistantException(this.failure);

  final AssistantFailure failure;

  @override
  String toString() => 'AssistantException($failure)';
}

/// Classifies any thrown object into a neutral [AssistantFailure].
///
/// Firebase AI Logic exceptions expose the server message through
/// `toString()`, so message matching covers `QuotaExceeded`,
/// `ServiceApiNotEnabled`, `InvalidApiKey`, `ServerException` and plain
/// `FirebaseAIException` without importing the SDK.
AssistantFailure classifyAssistantFailure(Object error) {
  if (error is AssistantException) return error.failure;
  if (error is TimeoutException) return AssistantFailure.network;

  final message = error.toString().toLowerCase();
  if (message.contains('quota') || message.contains('resource_exhausted')) {
    return AssistantFailure.quota;
  }
  if (message.contains('permission_denied') ||
      message.contains('403') ||
      message.contains('unauthenticated') ||
      message.contains('api key') ||
      message.contains('api_key_invalid') ||
      message.contains('not enabled') ||
      message.contains('enable firebase ai logic') ||
      message.contains('location is not supported')) {
    return AssistantFailure.serviceUnavailable;
  }
  if (message.contains('not found') ||
      message.contains('unsupported model') ||
      message.contains('no such model') ||
      message.contains('is not supported') ||
      message.contains('404')) {
    return AssistantFailure.modelUnavailable;
  }
  if (message.contains('blocked') ||
      message.contains('safety') ||
      message.contains('recitation')) {
    return AssistantFailure.blocked;
  }
  if (message.contains('network') ||
      message.contains('failed to fetch') ||
      message.contains('clientexception') ||
      message.contains('socket') ||
      message.contains('connection') ||
      message.contains('offline') ||
      message.contains('timed out') ||
      message.contains('timeout') ||
      message.contains('unavailable')) {
    return AssistantFailure.network;
  }
  return AssistantFailure.unknown;
}

/// Friendly, non-technical copy for each failure.
///
/// Every message ends by pointing at the deterministic summary that the screen
/// renders underneath, so a failure never leaves the visitor with nothing.
String assistantFailureMessage(AssistantFailure failure) {
  return switch (failure) {
    AssistantFailure.quota => AppStrings.assistantFailureQuota,
    AssistantFailure.serviceUnavailable ||
    AssistantFailure.modelUnavailable => AppStrings.assistantFailureService,
    AssistantFailure.network => AppStrings.assistantFailureNetwork,
    AssistantFailure.blocked => AppStrings.assistantFailureBlocked,
    AssistantFailure.empty => AppStrings.assistantFailureEmpty,
    AssistantFailure.unknown => AppStrings.assistantFailureUnknown,
  };
}
