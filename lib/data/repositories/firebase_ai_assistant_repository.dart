import 'dart:async';

import 'package:firebase_ai/firebase_ai.dart';
import 'package:flutter/foundation.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/repositories/assistant_ai_client.dart';
import 'package:aerosense_app/data/repositories/assistant_repository.dart';
import 'package:aerosense_app/features/assistant/assistant_failure.dart';

/// Live Ask AeroSense repository backed by Firebase AI Logic.
///
/// This is the only production file that imports `firebase_ai`. Requests go
/// through the Firebase project (no API key in the app) and are protected by
/// App Check, which is why the screen is gated on an active App Check status.
///
/// The app never writes through the assistant: the model gets one plain-text
/// question and returns one plain-text answer, with no tools and no function
/// calling. The firmware remains the only authority on the fan and the tier.
class FirebaseAiAssistantRepository implements AssistantRepository {
  FirebaseAiAssistantRepository({
    AssistantAiClient? client,
    Duration? timeout,
    this.model = AppConfig.assistantModel,
    this.fallbackModel = AppConfig.assistantFallbackModel,
  }) : _client = client ?? FirebaseAiClient(),
       _timeout = timeout ?? AppConfig.assistantTimeout;

  final AssistantAiClient _client;
  final Duration _timeout;

  /// Primary stable model.
  final String model;

  /// One-line fallback, used only when the primary model no longer exists.
  final String fallbackModel;

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    final recent = _keepNewest(history);

    try {
      return await _answerWith(
        model: model,
        systemInstruction: systemInstruction,
        history: recent,
        question: question,
      );
    } on AssistantException {
      rethrow;
    } catch (error) {
      final failure = classifyAssistantFailure(error);
      if (failure != AssistantFailure.modelUnavailable) {
        // No retry on quota, network or blocked: a second request would spend
        // quota on a failure that retrying cannot fix.
        if (kDebugMode) debugPrint('Assistant request failed: $failure');
        throw AssistantException(failure);
      }
      if (kDebugMode) debugPrint('Assistant model $model unavailable.');
    }

    // The named model is retired: try the documented fallback exactly once,
    // then give up and let the screen show the deterministic summary.
    try {
      return await _answerWith(
        model: fallbackModel,
        systemInstruction: systemInstruction,
        history: recent,
        question: question,
      );
    } catch (error) {
      final failure = classifyAssistantFailure(error);
      if (kDebugMode) debugPrint('Assistant fallback failed: $failure');
      throw AssistantException(failure);
    }
  }

  Future<String> _answerWith({
    required String model,
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    final answer = await _client
        .generateAnswer(
          model: model,
          systemInstruction: systemInstruction,
          history: history,
          question: question,
        )
        .timeout(_timeout);

    final text = answer?.trim() ?? '';
    if (text.isEmpty) throw const AssistantException(AssistantFailure.empty);
    return text;
  }

  static List<AssistantMessage> _keepNewest(List<AssistantMessage> messages) {
    if (messages.length <= AppConfig.assistantMaxMessages) return messages;
    return messages.sublist(messages.length - AppConfig.assistantMaxMessages);
  }
}

/// Firebase AI Logic implementation of [AssistantAiClient].
///
/// `FirebaseAI.googleAI()` selects the Gemini Developer API backend, matching
/// the Firebase console setup for this project. The model is created per
/// request because the system instruction is per-request data.
class FirebaseAiClient implements AssistantAiClient {
  FirebaseAiClient();

  @override
  Future<String?> generateAnswer({
    required String model,
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    final generationConfig = GenerationConfig(
      maxOutputTokens: AppConfig.assistantMaxOutputTokens,
      temperature: AppConfig.assistantTemperature,
      // gemini-3.x always thinks; LOW keeps latency and cost down and is
      // supported by both the primary and the fallback model.
      thinkingConfig: ThinkingConfig.withThinkingLevel(ThinkingLevel.low),
    );

    final generativeModel = FirebaseAI.googleAI().generativeModel(
      model: model,
      systemInstruction: Content.system(systemInstruction),
      generationConfig: generationConfig,
    );

    final chat = generativeModel.startChat(history: _toContents(history));
    final response = await chat.sendMessage(Content.text(question));

    // `text` throws when the prompt or candidate was blocked; the repository
    // classifies that as AssistantFailure.blocked.
    return response.text;
  }

  static List<Content> _toContents(List<AssistantMessage> messages) {
    return [
      for (final message in messages)
        message.role == AssistantRole.visitor
            ? Content.text(message.text)
            : Content.model([TextPart(message.text)]),
    ];
  }
}
