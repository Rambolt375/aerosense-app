import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/repositories/assistant_repository.dart';
import 'package:aerosense_app/features/assistant/assistant_failure.dart';

/// The only production file that talks to Gemini.
///
/// Uses the public Gemini REST API directly so the same code runs on web and
/// Android. The restricted free-tier key travels only in the
/// `x-goog-api-key` header; it is never put in the URL, the body or a log.
///
/// The app never writes through the assistant: the model gets one plain-text
/// question and returns one plain-text answer, with no tools and no function
/// calling. The firmware remains the only authority on the fan and the tier.
class GeminiRestAssistantRepository implements AssistantRepository {
  GeminiRestAssistantRepository({
    http.Client? client,
    String? apiKey,
    this.model = AppConfig.assistantModel,
    Duration? timeout,
    Duration? retryDelay,
  }) : _client = client ?? http.Client(),
       _apiKey = apiKey ?? AppConfig.geminiApiKey,
       _timeout = timeout ?? AppConfig.assistantTimeout,
       _retryDelay = retryDelay ?? AppConfig.assistantRetryDelay;

  final http.Client _client;
  final String _apiKey;
  final Duration _timeout;
  final Duration _retryDelay;

  /// The only model this app calls. See [AppConfig.assistantModel].
  final String model;

  static const String _baseUrl =
      'https://generativelanguage.googleapis.com/v1beta';

  /// Finish reasons that mean the provider withheld the answer.
  static const Set<String> _blockedFinishReasons = {
    'SAFETY',
    'RECITATION',
    'LANGUAGE',
    'BLOCKLIST',
    'PROHIBITED_CONTENT',
    'SPII',
    'IMAGE_SAFETY',
    'IMAGE_PROHIBITED_CONTENT',
  };

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    if (_apiKey.isEmpty) {
      // Gating hides the assistant without a key; this guards direct calls.
      throw const AssistantException(AssistantFailure.serviceUnavailable);
    }

    final body = _buildBody(
      systemInstruction: systemInstruction,
      history: history,
      question: question,
    );

    try {
      return await _send(body);
    } on _RetryableFailure catch (failure) {
      // One retry only, on the same model, for a transient overload.
      await Future<void>.delayed(_retryDelay);
      try {
        return await _send(body);
      } on _RetryableFailure {
        throw AssistantException(failure.failure);
      }
    }
  }

  Uri get _endpoint => Uri.parse('$_baseUrl/models/$model:generateContent');

  Future<String> _send(Map<String, Object?> body) async {
    final http.Response response;
    try {
      response = await _client
          .post(
            _endpoint,
            headers: {
              'Content-Type': 'application/json',
              // The key is deliberately header-only. Never add it to the URL
              // or the body, and never log this request.
              'x-goog-api-key': _apiKey,
            },
            body: jsonEncode(body),
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw const AssistantException(AssistantFailure.network);
    } on http.ClientException {
      throw const AssistantException(AssistantFailure.network);
    }

    final status = response.statusCode;
    if (status >= 200 && status < 300) {
      return _parseAnswer(response.body);
    }

    final failure = _classifyHttpFailure(status, response.body);
    if (failure.retryable) throw _RetryableFailure(failure.failure);
    throw AssistantException(failure.failure);
  }

  Map<String, Object?> _buildBody({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) {
    final recent = history.length <= AppConfig.assistantMaxMessages
        ? history
        : history.sublist(history.length - AppConfig.assistantMaxMessages);

    return {
      // Data only: the visitor's question is never part of this text.
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': [
        for (final message in recent)
          {
            'role': message.role == AssistantRole.visitor ? 'user' : 'model',
            'parts': [
              {'text': message.text},
            ],
          },
        {
          'role': 'user',
          'parts': [
            {'text': question},
          ],
        },
      ],
      'generationConfig': {
        'maxOutputTokens': AppConfig.assistantMaxOutputTokens,
        'temperature': AppConfig.assistantTemperature,
      },
    };
  }

  String _parseAnswer(String rawBody) {
    final Object? decoded;
    try {
      decoded = jsonDecode(rawBody);
    } on FormatException {
      throw const AssistantException(AssistantFailure.unknown);
    }
    if (decoded is! Map<String, dynamic>) {
      throw const AssistantException(AssistantFailure.unknown);
    }

    final promptFeedback = decoded['promptFeedback'];
    if (promptFeedback is Map) {
      final blockReason = promptFeedback['blockReason'];
      if (blockReason is String &&
          blockReason.isNotEmpty &&
          blockReason != 'BLOCK_REASON_UNSPECIFIED') {
        throw const AssistantException(AssistantFailure.blocked);
      }
    }

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AssistantException(AssistantFailure.empty);
    }
    final candidate = candidates.first;
    if (candidate is! Map) {
      throw const AssistantException(AssistantFailure.empty);
    }

    final finishReason = candidate['finishReason'];
    if (finishReason is String &&
        _blockedFinishReasons.contains(finishReason)) {
      throw const AssistantException(AssistantFailure.blocked);
    }

    final content = candidate['content'];
    final parts = content is Map ? content['parts'] : null;
    final answer = StringBuffer();
    if (parts is List) {
      for (final part in parts) {
        if (part is! Map) continue;
        // Thoughts can carry a thoughtSignature; they are not the answer.
        if (part['thought'] == true) continue;
        final text = part['text'];
        if (text is String) answer.write(text);
      }
    }

    final text = answer.toString().trim();
    if (text.isNotEmpty) {
      // A MAX_TOKENS response with partial text is still useful.
      return text;
    }
    throw const AssistantException(AssistantFailure.empty);
  }

  _HttpFailure _classifyHttpFailure(int status, String rawBody) {
    final error = _errorMap(rawBody);
    final apiStatus = error?['status'];
    final message = error?['message'];
    final isOverloaded =
        (apiStatus is String && apiStatus == 'UNAVAILABLE') ||
        (message is String && message.toLowerCase().contains('overload'));

    if (status == 429) {
      return const _HttpFailure(AssistantFailure.busy);
    }
    if (status == 503 || isOverloaded) {
      return const _HttpFailure(
        AssistantFailure.busyAfterRetry,
        retryable: true,
      );
    }
    if (status == 400 || status == 401 || status == 403 || status == 404) {
      return const _HttpFailure(AssistantFailure.serviceUnavailable);
    }
    return const _HttpFailure(AssistantFailure.unknown);
  }

  Map<String, dynamic>? _errorMap(String rawBody) {
    try {
      final decoded = jsonDecode(rawBody);
      if (decoded is Map<String, dynamic>) {
        final error = decoded['error'];
        if (error is Map<String, dynamic>) return error;
      }
    } on FormatException {
      // Plain-text error bodies are classified by status alone.
    }
    return null;
  }
}

/// Internal marker for a failure that is worth exactly one retry.
class _RetryableFailure implements Exception {
  const _RetryableFailure(this.failure);

  final AssistantFailure failure;
}

class _HttpFailure {
  const _HttpFailure(this.failure, {this.retryable = false});

  final AssistantFailure failure;
  final bool retryable;
}
