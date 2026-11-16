import 'package:aerosense_app/data/models/assistant_message.dart';

/// Seam between the assistant repository and the generative SDK.
///
/// Kept SDK-free so the repository's error mapping, model fallback and
/// history capping can be tested with a fake client and no network. The only
/// production implementation lives in
/// `data/repositories/firebase_ai_assistant_repository.dart`.
abstract class AssistantAiClient {
  /// Sends one question and returns the model's plain-text answer.
  ///
  /// Returns null when the provider answered without text. Implementations
  /// throw on failure; classification happens in the repository.
  Future<String?> generateAnswer({
    required String model,
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  });
}
