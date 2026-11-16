/// Who authored one assistant chat message.
enum AssistantRole { visitor, assistant }

/// One in-memory message of the Ask AeroSense conversation.
///
/// Deliberately free of Firebase types so the repository interface and the
/// prompt builder stay independent of any provider SDK.
class AssistantMessage {
  const AssistantMessage({required this.role, required this.text});

  final AssistantRole role;
  final String text;
}
