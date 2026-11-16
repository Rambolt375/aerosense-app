import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/features/assistant/assistant_failure.dart';

void main() {
  test('every failure has the approved, non-technical copy', () {
    expect(
      assistantFailureMessage(AssistantFailure.serviceUnavailable),
      "The assistant isn't set up right now.",
    );
    expect(
      assistantFailureMessage(AssistantFailure.busy),
      'The assistant is busy right now.',
    );
    expect(
      assistantFailureMessage(AssistantFailure.busyAfterRetry),
      'The assistant is busy right now. Try again in a minute.',
    );
    expect(assistantFailureMessage(AssistantFailure.network), 'No connection.');
    expect(
      assistantFailureMessage(AssistantFailure.blocked),
      "I couldn't answer that.",
    );
    expect(
      assistantFailureMessage(AssistantFailure.empty),
      "I couldn't answer that.",
    );
    expect(
      assistantFailureMessage(AssistantFailure.unknown),
      "I couldn't answer that.",
    );
  });

  test('no message leaks technical details', () {
    for (final failure in AssistantFailure.values) {
      final message = assistantFailureMessage(failure).toLowerCase();
      expect(message, isNotEmpty, reason: failure.name);
      expect(message, isNot(contains('exception')), reason: failure.name);
      expect(message, isNot(contains('http')), reason: failure.name);
      expect(
        message,
        isNot(contains('generativelanguage')),
        reason: failure.name,
      );
      expect(message, isNot(contains('api key')), reason: failure.name);
      expect(message, isNot(contains('null')), reason: failure.name);
    }
  });

  test('the friendly copy is centralised in AppStrings', () {
    expect(
      assistantFailureMessage(AssistantFailure.serviceUnavailable),
      AppStrings.assistantFailureSetup,
    );
    expect(
      assistantFailureMessage(AssistantFailure.busy),
      AppStrings.assistantFailureBusy,
    );
    expect(
      assistantFailureMessage(AssistantFailure.busyAfterRetry),
      AppStrings.assistantFailureBusyAfterRetry,
    );
    expect(
      assistantFailureMessage(AssistantFailure.network),
      AppStrings.assistantFailureNoConnection,
    );
    expect(
      assistantFailureMessage(AssistantFailure.blocked),
      AppStrings.assistantFailureNoAnswer,
    );
  });
}
