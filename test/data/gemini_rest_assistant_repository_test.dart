import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/repositories/gemini_rest_assistant_repository.dart';
import 'package:aerosense_app/features/assistant/assistant_failure.dart';

const _apiKey = 'unit-test-key';
const _endpoint =
    'https://generativelanguage.googleapis.com/v1beta/models/'
    'gemini-3.5-flash-lite:generateContent';

AssistantMessage _visitor(String text) =>
    AssistantMessage(role: AssistantRole.visitor, text: text);

AssistantMessage _assistant(String text) =>
    AssistantMessage(role: AssistantRole.assistant, text: text);

MockClient _client(
  Future<http.Response> Function(http.Request request) handler,
) {
  return MockClient(handler);
}

GeminiRestAssistantRepository _repository(
  http.Client client, {
  String apiKey = _apiKey,
  Duration timeout = AppConfig.assistantTimeout,
  Duration retryDelay = Duration.zero,
}) {
  return GeminiRestAssistantRepository(
    client: client,
    apiKey: apiKey,
    timeout: timeout,
    retryDelay: retryDelay,
  );
}

String _answerResponse(
  List<Map<String, Object?>> parts, {
  String finishReason = 'STOP',
}) {
  return jsonEncode({
    'candidates': [
      {
        'content': {'parts': parts},
        'finishReason': finishReason,
      },
    ],
  });
}

Future<AssistantFailure> _failureFor(http.Response response) async {
  final repository = _repository(_client((_) async => response));
  try {
    await repository.ask(
      systemInstruction: 'SYSTEM',
      history: const [],
      question: 'Is the room OK?',
    );
  } on AssistantException catch (error) {
    return error.failure;
  }
  fail('expected an AssistantException');
}

void main() {
  group('model configuration', () {
    test('only the verified model constant is used', () {
      expect(AppConfig.assistantModel, 'gemini-3.5-flash-lite');
      expect(AppConfig.assistantMaxOutputTokens, 600);
      expect(AppConfig.assistantTimeout, const Duration(seconds: 20));
      expect(AppConfig.assistantRetryDelay, const Duration(milliseconds: 1500));
    });
  });

  group('request shape', () {
    test('posts to generateContent with the key only in the header', () async {
      late http.Request captured;
      final repository = _repository(
        _client((request) async {
          captured = request;
          return http.Response(
            _answerResponse([
              {'text': 'ok'},
            ]),
            200,
          );
        }),
      );

      expect(
        await repository.ask(
          systemInstruction: 'SYSTEM',
          history: const [],
          question: 'Is the room OK?',
        ),
        'ok',
      );

      expect(captured.method, 'POST');
      expect(captured.url.toString(), _endpoint);
      expect(captured.headers['x-goog-api-key'], _apiKey);
      expect(captured.url.queryParameters, isNot(contains('key')));
      expect(captured.url.toString(), isNot(contains(_apiKey)));
      expect(captured.body, isNot(contains(_apiKey)));
      expect(
        captured.headers.keys.map((key) => key.toLowerCase()),
        isNot(contains('authorization')),
      );
    });

    test('sends systemInstruction, contents and generationConfig', () async {
      late Map<String, dynamic> body;
      final repository = _repository(
        _client((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            _answerResponse([
              {'text': 'ok'},
            ]),
            200,
          );
        }),
      );

      await repository.ask(
        systemInstruction: 'APPROVED RULES',
        history: [
          _visitor('question 0'),
          _assistant('answer 1'),
          _visitor('question 2'),
          _assistant('answer 3'),
          _visitor('question 4'),
          _assistant('answer 5'),
        ],
        question: 'What is the temperature?',
      );

      final systemInstruction =
          body['systemInstruction'] as Map<String, dynamic>;
      final systemParts = systemInstruction['parts'] as List<dynamic>;
      final systemText =
          (systemParts.single as Map<String, dynamic>)['text'] as String;
      expect(systemText, 'APPROVED RULES');
      expect(systemText, isNot(contains('What is the temperature?')));

      final contents = body['contents'] as List<dynamic>;
      final turns = contents.cast<Map<String, dynamic>>();
      expect(turns.length, AppConfig.assistantMaxMessages + 1);
      expect(turns.map((turn) => turn['role']), [
        'user',
        'model',
        'user',
        'model',
        'user',
      ]);
      expect(
        turns.map((turn) => (turn['parts'] as List<dynamic>).single['text']),
        [
          'question 2',
          'answer 3',
          'question 4',
          'answer 5',
          'What is the temperature?',
        ],
      );

      final generationConfig = body['generationConfig'] as Map<String, dynamic>;
      expect(generationConfig, {'maxOutputTokens': 600, 'temperature': 0.3});
      expect(body.containsKey('thinkingConfig'), isFalse);
    });

    test('the question never enters the system instruction', () async {
      late Map<String, dynamic> body;
      final repository = _repository(
        _client((request) async {
          body = jsonDecode(request.body) as Map<String, dynamic>;
          return http.Response(
            _answerResponse([
              {'text': 'ok'},
            ]),
            200,
          );
        }),
      );

      await repository.ask(
        systemInstruction: 'APPROVED RULES',
        history: const [],
        question: 'What is my email address?',
      );

      expect(jsonEncode(body['systemInstruction']), isNot(contains('email')));
      expect(
        jsonEncode(body['contents']),
        contains('What is my email address?'),
      );
    });

    test('an empty key never reaches the network', () async {
      var calls = 0;
      final repository = _repository(
        _client((_) async {
          calls++;
          return http.Response(
            _answerResponse([
              {'text': 'ok'},
            ]),
            200,
          );
        }),
        apiKey: '',
      );

      await expectLater(
        repository.ask(
          systemInstruction: 'SYSTEM',
          history: const [],
          question: 'Is the room OK?',
        ),
        throwsA(
          isA<AssistantException>().having(
            (error) => error.failure,
            'failure',
            AssistantFailure.serviceUnavailable,
          ),
        ),
      );
      expect(calls, 0);
    });
  });

  group('response parsing tolerates extra fields', () {
    test(
      'joins every non-thought text part and ignores other fields',
      () async {
        final repository = _repository(
          _client(
            (_) async => http.Response(
              _answerResponse([
                {'text': 'The room ', 'thoughtSignature': 'opaque-signature'},
                {'text': 'ignored', 'thought': true, 'thoughtSignature': 'x'},
                {'text': 'is safe.', 'thought': false, 'someFutureField': 42},
                {
                  'inlineData': {'mimeType': 'text/plain', 'data': 'aa'},
                },
              ]),
              200,
            ),
          ),
        );

        expect(
          await repository.ask(
            systemInstruction: 'SYSTEM',
            history: const [],
            question: 'Is the room OK?',
          ),
          'The room is safe.',
        );
      },
    );

    test('returns partial text when finishReason is MAX_TOKENS', () async {
      final repository = _repository(
        _client(
          (_) async => http.Response(
            _answerResponse([
              {'text': 'The room is '},
            ], finishReason: 'MAX_TOKENS'),
            200,
          ),
        ),
      );

      expect(
        await repository.ask(
          systemInstruction: 'SYSTEM',
          history: const [],
          question: 'Is the room OK?',
        ),
        'The room is',
      );
    });

    test('MAX_TOKENS without text is an empty answer', () async {
      final repository = _repository(
        _client(
          (_) async => http.Response(
            jsonEncode({
              'candidates': [
                {
                  'content': {'parts': <Object?>[]},
                  'finishReason': 'MAX_TOKENS',
                },
              ],
            }),
            200,
          ),
        ),
      );

      await expectLater(
        repository.ask(
          systemInstruction: 'SYSTEM',
          history: const [],
          question: 'Is the room OK?',
        ),
        throwsA(
          isA<AssistantException>().having(
            (error) => error.failure,
            'failure',
            AssistantFailure.empty,
          ),
        ),
      );
    });

    test('promptFeedback.blockReason is a blocked answer', () async {
      expect(
        await _failureFor(
          http.Response(
            jsonEncode({
              'promptFeedback': {'blockReason': 'SAFETY'},
            }),
            200,
          ),
        ),
        AssistantFailure.blocked,
      );
    });

    test('missing and empty candidates are empty answers', () async {
      expect(
        await _failureFor(http.Response('{}', 200)),
        AssistantFailure.empty,
      );
      expect(
        await _failureFor(http.Response('{"candidates":[]}', 200)),
        AssistantFailure.empty,
      );
    });
  });

  group('error mapping', () {
    test('400 and 403 say the assistant is not set up', () async {
      for (final status in [400, 403]) {
        final failure = await _failureFor(
          http.Response('{"error":{"code":$status}}', status),
        );
        expect(failure, AssistantFailure.serviceUnavailable, reason: '$status');
        expect(
          assistantFailureMessage(failure),
          "The assistant isn't set up right now.",
        );
      }
    });

    test('429 is busy and is never retried', () async {
      var calls = 0;
      final repository = _repository(
        _client((_) async {
          calls++;
          return http.Response(
            '{"error":{"code":429,"status":"RESOURCE_EXHAUSTED"}}',
            429,
          );
        }),
      );

      await expectLater(
        repository.ask(
          systemInstruction: 'SYSTEM',
          history: const [],
          question: 'Is the room OK?',
        ),
        throwsA(
          isA<AssistantException>()
              .having(
                (error) => error.failure,
                'failure',
                AssistantFailure.busy,
              )
              .having(
                (_) => assistantFailureMessage(AssistantFailure.busy),
                'message',
                'The assistant is busy right now.',
              ),
        ),
      );
      expect(calls, 1);
    });

    test(
      '503 is retried once and then says to try again in a minute',
      () async {
        var calls = 0;
        final repository = _repository(
          _client((_) async {
            calls++;
            return http.Response(
              '{"error":{"code":503,"status":"UNAVAILABLE",'
              '"message":"The model is overloaded."}}',
              503,
            );
          }),
        );

        await expectLater(
          repository.ask(
            systemInstruction: 'SYSTEM',
            history: const [],
            question: 'Is the room OK?',
          ),
          throwsA(
            isA<AssistantException>()
                .having(
                  (error) => error.failure,
                  'failure',
                  AssistantFailure.busyAfterRetry,
                )
                .having(
                  (_) =>
                      assistantFailureMessage(AssistantFailure.busyAfterRetry),
                  'message',
                  'The assistant is busy right now. Try again in a minute.',
                ),
          ),
        );
        expect(calls, 2);
      },
    );

    test(
      'a 503 followed by success returns the answer after one retry',
      () async {
        var calls = 0;
        final repository = _repository(
          _client((_) async {
            calls++;
            if (calls == 1) {
              return http.Response(
                '{"error":{"code":503,"status":"UNAVAILABLE"}}',
                503,
              );
            }
            return http.Response(
              _answerResponse([
                {'text': 'recovered'},
              ]),
              200,
            );
          }),
        );

        expect(
          await repository.ask(
            systemInstruction: 'SYSTEM',
            history: const [],
            question: 'Is the room OK?',
          ),
          'recovered',
        );
        expect(calls, 2);
      },
    );

    test('an overloaded error body is retried without a 503 status', () async {
      var calls = 0;
      final repository = _repository(
        _client((_) async {
          calls++;
          if (calls == 1) {
            return http.Response(
              '{"error":{"code":500,"message":"The service is overloaded."}}',
              500,
            );
          }
          return http.Response(
            _answerResponse([
              {'text': 'recovered'},
            ]),
            200,
          );
        }),
      );

      expect(
        await repository.ask(
          systemInstruction: 'SYSTEM',
          history: const [],
          question: 'Is the room OK?',
        ),
        'recovered',
      );
      expect(calls, 2);
    });

    test(
      'a timeout or a transport error says there is no connection',
      () async {
        final timeoutRepository = _repository(
          _client((_) => Completer<http.Response>().future),
          timeout: const Duration(milliseconds: 10),
        );
        await expectLater(
          timeoutRepository.ask(
            systemInstruction: 'SYSTEM',
            history: const [],
            question: 'Is the room OK?',
          ),
          throwsA(
            isA<AssistantException>()
                .having(
                  (error) => error.failure,
                  'failure',
                  AssistantFailure.network,
                )
                .having(
                  (_) => assistantFailureMessage(AssistantFailure.network),
                  'message',
                  'No connection.',
                ),
          ),
        );

        final offlineRepository = _repository(
          _client((_) async {
            throw http.ClientException('Failed to fetch');
          }),
        );
        await expectLater(
          offlineRepository.ask(
            systemInstruction: 'SYSTEM',
            history: const [],
            question: 'Is the room OK?',
          ),
          throwsA(
            isA<AssistantException>().having(
              (error) => error.failure,
              'failure',
              AssistantFailure.network,
            ),
          ),
        );
      },
    );

    test('blocked and empty answers share one friendly message', () {
      expect(
        assistantFailureMessage(AssistantFailure.blocked),
        "I couldn't answer that.",
      );
      expect(
        assistantFailureMessage(AssistantFailure.empty),
        "I couldn't answer that.",
      );
    });

    test('errors never expose the key or the request URL', () async {
      final repository = _repository(
        _client((_) async => http.Response('not json', 500)),
      );

      try {
        await repository.ask(
          systemInstruction: 'SYSTEM',
          history: const [],
          question: 'Is the room OK?',
        );
        fail('expected an AssistantException');
      } on AssistantException catch (error) {
        expect(error.toString(), isNot(contains(_apiKey)));
        expect(error.toString(), isNot(contains('generativelanguage')));
        expect(error.toString(), isNot(contains('https://')));
      }
    });
  });

  group('friendly copy', () {
    test('every failure maps to the approved copy', () {
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
      expect(
        assistantFailureMessage(AssistantFailure.empty),
        AppStrings.assistantFailureNoAnswer,
      );
    });
  });
}
