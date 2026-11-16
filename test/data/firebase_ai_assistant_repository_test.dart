import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/repositories/assistant_ai_client.dart';
import 'package:aerosense_app/data/repositories/firebase_ai_assistant_repository.dart';
import 'package:aerosense_app/features/assistant/assistant_failure.dart';

/// Fake AI client: no Firebase, no network, records every call.
class _FakeAiClient implements AssistantAiClient {
  _FakeAiClient(this._handler);

  final Future<String?> Function(String model, List<AssistantMessage> history)
  _handler;

  final List<String> models = [];
  final List<String> instructions = [];
  final List<String> questions = [];
  final List<List<AssistantMessage>> histories = [];

  @override
  Future<String?> generateAnswer({
    required String model,
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) {
    models.add(model);
    instructions.add(systemInstruction);
    questions.add(question);
    histories.add(List<AssistantMessage>.of(history));
    return _handler(model, history);
  }
}

AssistantMessage _visitor(String text) =>
    AssistantMessage(role: AssistantRole.visitor, text: text);

AssistantMessage _assistant(String text) =>
    AssistantMessage(role: AssistantRole.assistant, text: text);

Future<String> _ask(
  FirebaseAiAssistantRepository repository, {
  List<AssistantMessage> history = const [],
  String question = 'Is the room OK?',
}) {
  return repository.ask(
    systemInstruction: 'SYSTEM',
    history: history,
    question: question,
  );
}

void main() {
  test('returns the model answer trimmed', () async {
    final client = _FakeAiClient((_, _) async => '  The room is in Caution.  ');
    final repository = FirebaseAiAssistantRepository(client: client);

    expect(await _ask(repository), 'The room is in Caution.');
    expect(client.models, [AppConfig.assistantModel]);
    expect(client.questions, ['Is the room OK?']);
    expect(client.instructions.single, 'SYSTEM');
  });

  test('sends only the last four messages as history', () async {
    final client = _FakeAiClient((_, _) async => 'ok');
    final repository = FirebaseAiAssistantRepository(client: client);

    final history = [
      for (var i = 0; i < 6; i++)
        i.isEven ? _visitor('question $i') : _assistant('answer $i'),
    ];

    await _ask(repository, history: history);

    final sent = client.histories.single;
    expect(sent.length, AppConfig.assistantMaxMessages);
    expect(sent.map((m) => m.text), [
      'question 2',
      'answer 3',
      'question 4',
      'answer 5',
    ]);
  });

  group('error mapping', () {
    Future<AssistantFailure> failureFor(
      Future<String?> Function() handler,
    ) async {
      final client = _FakeAiClient((_, _) => handler());
      final repository = FirebaseAiAssistantRepository(client: client);
      try {
        await _ask(repository);
      } on AssistantException catch (error) {
        return error.failure;
      }
      fail('expected an AssistantException');
    }

    test('quota exceeded', () async {
      expect(
        await failureFor(
          () async => throw Exception('Quota exceeded for quota'),
        ),
        AssistantFailure.quota,
      );
    });

    test('403 / service not enabled', () async {
      expect(
        await failureFor(
          () async => throw Exception(
            'PERMISSION_DENIED: To access this model, you must enforce '
            'Firebase App Check.',
          ),
        ),
        AssistantFailure.serviceUnavailable,
      );
    });

    test('timeout', () async {
      expect(
        await failureFor(() async => throw TimeoutException('20s')),
        AssistantFailure.network,
      );
    });

    test('no network', () async {
      expect(
        await failureFor(
          () async => throw Exception('ClientException: Failed to fetch'),
        ),
        AssistantFailure.network,
      );
    });

    test('blocked answer', () async {
      expect(
        await failureFor(
          () async => throw Exception('Candidate was blocked due to SAFETY'),
        ),
        AssistantFailure.blocked,
      );
    });

    test('empty answer', () async {
      expect(await failureFor(() async => null), AssistantFailure.empty);
      expect(await failureFor(() async => '   '), AssistantFailure.empty);
    });

    test('the repository enforces its own timeout', () async {
      final client = _FakeAiClient((_, _) => Completer<String?>().future);
      final repository = FirebaseAiAssistantRepository(
        client: client,
        timeout: const Duration(milliseconds: 10),
      );

      await expectLater(
        _ask(repository),
        throwsA(
          isA<AssistantException>().having(
            (e) => e.failure,
            'failure',
            AssistantFailure.network,
          ),
        ),
      );
    });
  });

  group('model fallback', () {
    test('a retired model falls back once to the fallback constant', () async {
      final client = _FakeAiClient((model, _) async {
        if (model == AppConfig.assistantModel) {
          throw Exception('[404] model is not found');
        }
        return 'Fallback answer.';
      });
      final repository = FirebaseAiAssistantRepository(client: client);

      expect(await _ask(repository), 'Fallback answer.');
      expect(client.models, [
        AppConfig.assistantModel,
        AppConfig.assistantFallbackModel,
      ]);
    });

    test('a failing fallback surfaces its own failure', () async {
      final client = _FakeAiClient((_, _) async {
        throw Exception('[404] model is not found');
      });
      final repository = FirebaseAiAssistantRepository(client: client);

      await expectLater(
        _ask(repository),
        throwsA(
          isA<AssistantException>().having(
            (e) => e.failure,
            'failure',
            AssistantFailure.modelUnavailable,
          ),
        ),
      );
      expect(client.models.length, 2);
    });

    test('quota and network failures never fall back', () async {
      for (final error in <Object>[
        Exception('Quota exceeded for quota'),
        TimeoutException('20s'),
      ]) {
        final client = _FakeAiClient((_, _) async => throw error);
        final repository = FirebaseAiAssistantRepository(client: client);

        await expectLater(_ask(repository), throwsA(isA<AssistantException>()));
        expect(client.models, [AppConfig.assistantModel]);
      }
    });
  });

  test(
    'no questions, answers or instruction are put on the wire twice',
    () async {
      final client = _FakeAiClient((_, _) async => 'answer');
      final repository = FirebaseAiAssistantRepository(client: client);

      await _ask(repository, question: 'What is the temperature?');

      // One question, one request: the repository never auto-retries.
      expect(client.models.length, 1);
      expect(client.questions.single, 'What is the temperature?');
    },
  );
}
