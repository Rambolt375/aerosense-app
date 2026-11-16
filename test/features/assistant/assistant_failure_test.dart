import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/features/assistant/assistant_failure.dart';

void main() {
  group('classifyAssistantFailure', () {
    test('timeouts are network failures', () {
      expect(
        classifyAssistantFailure(TimeoutException('too slow')),
        AssistantFailure.network,
      );
    });

    test('quota messages are quota failures', () {
      expect(
        classifyAssistantFailure(
          Exception('You exceeded your current quota, please check your plan.'),
        ),
        AssistantFailure.quota,
      );
      expect(
        classifyAssistantFailure(Exception('8 RESOURCE_EXHAUSTED: quota')),
        AssistantFailure.quota,
      );
    });

    test('403 and disabled-API messages are service failures', () {
      expect(
        classifyAssistantFailure(
          Exception(
            'PERMISSION_DENIED: To access this model, you must enforce '
            'Firebase App Check.',
          ),
        ),
        AssistantFailure.serviceUnavailable,
      );
      expect(
        classifyAssistantFailure(Exception('[403] Forbidden')),
        AssistantFailure.serviceUnavailable,
      );
      expect(
        classifyAssistantFailure(
          Exception(
            'Enable Firebase AI Logic in your Firebase project by visiting the '
            'Firebase Console',
          ),
        ),
        AssistantFailure.serviceUnavailable,
      );
      expect(
        classifyAssistantFailure(
          Exception('API key not valid. Please pass a valid API key.'),
        ),
        AssistantFailure.serviceUnavailable,
      );
      expect(
        classifyAssistantFailure(
          Exception('User location is not supported for the API use.'),
        ),
        AssistantFailure.serviceUnavailable,
      );
    });

    test('retired or unknown models are model failures', () {
      expect(
        classifyAssistantFailure(
          Exception('[404] models/gemini-2.0-flash is not found'),
        ),
        AssistantFailure.modelUnavailable,
      );
      expect(
        classifyAssistantFailure(
          Exception('This model is not supported by Firebase AI Logic.'),
        ),
        AssistantFailure.modelUnavailable,
      );
    });

    test('blocked prompts and answers are blocked failures', () {
      expect(
        classifyAssistantFailure(
          Exception('Response was blocked due to SAFETY'),
        ),
        AssistantFailure.blocked,
      );
      expect(
        classifyAssistantFailure(
          Exception('Candidate was blocked due to recitation'),
        ),
        AssistantFailure.blocked,
      );
    });

    test('offline and transport errors are network failures', () {
      expect(
        classifyAssistantFailure(
          Exception('ClientException: Failed to fetch, uri=...'),
        ),
        AssistantFailure.network,
      );
      expect(
        classifyAssistantFailure(Exception('SocketException: offline')),
        AssistantFailure.network,
      );
    });

    test('an already-classified AssistantException is passed through', () {
      expect(
        classifyAssistantFailure(
          const AssistantException(AssistantFailure.blocked),
        ),
        AssistantFailure.blocked,
      );
    });

    test('everything else is unknown', () {
      expect(
        classifyAssistantFailure(Exception('something unexpected')),
        AssistantFailure.unknown,
      );
    });
  });

  group('assistantFailureMessage', () {
    test('every failure has friendly copy', () {
      for (final failure in AssistantFailure.values) {
        final message = assistantFailureMessage(failure);
        expect(message, isNotEmpty, reason: failure.name);
        expect(message.toLowerCase(), isNot(contains('exception')));
        expect(message.toLowerCase(), isNot(contains('null')));
      }
    });

    test('the case-specific copy is distinct per outcome', () {
      final distinct = {
        AssistantFailure.quota,
        AssistantFailure.serviceUnavailable,
        AssistantFailure.network,
        AssistantFailure.blocked,
        AssistantFailure.empty,
        AssistantFailure.unknown,
      }.map(assistantFailureMessage).toSet();

      expect(distinct.length, 6);
    });

    test('quota, network and blocked copy stay distinct', () {
      expect(
        assistantFailureMessage(AssistantFailure.quota),
        AppStrings.assistantFailureQuota,
      );
      expect(
        assistantFailureMessage(AssistantFailure.network),
        AppStrings.assistantFailureNetwork,
      );
      expect(
        assistantFailureMessage(AssistantFailure.blocked),
        AppStrings.assistantFailureBlocked,
      );
    });

    test('each failure points at the deterministic summary', () {
      for (final failure in AssistantFailure.values) {
        expect(
          assistantFailureMessage(failure).toLowerCase(),
          contains('room summary'),
          reason: failure.name,
        );
      }
    });
  });
}
