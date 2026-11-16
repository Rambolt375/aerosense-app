import 'package:aerosense_app/data/models/assistant_message.dart';

/// Contract for the Ask AeroSense assistant.
///
/// No Firebase (or other provider SDK) types cross this boundary: the screen
/// and providers only ever see plain strings and [AssistantMessage]s. Slice
/// 7b-3 adds the live Firebase AI Logic implementation behind this interface.
abstract class AssistantRepository {
  /// Asks [question] about the room.
  ///
  /// [systemInstruction] carries the approved rules plus the deterministic
  /// summary as data. [history] is the previous conversation (already capped by
  /// the caller). The visitor's own text travels only in [question].
  ///
  /// Throws on network, quota or provider errors; the caller shows the
  /// deterministic summary instead and never retries automatically.
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  });
}
