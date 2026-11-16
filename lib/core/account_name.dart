import 'package:flutter/widgets.dart';

/// Maximum length of an account display name, in grapheme clusters.
const int displayNameMaxLength = 40;

/// Whitespace runs that collapse into a single space.
final RegExp _whitespaceRun = RegExp(r'[\s\u00A0]+');

/// C0 and C1 control characters, plus the byte-order mark.
final RegExp _controlCharacters = RegExp(r'[\u0000-\u001F\u007F-\u009F\uFEFF]');

/// Cleans a user-entered display name, or returns null when it is not usable.
///
/// Order matters: whitespace runs become a single space first (so a stray tab
/// or newline reads as a word separator), then remaining control characters are
/// dropped outright, then the result is trimmed. Length is measured on grapheme
/// clusters so an emoji or a flag counts as one character instead of several.
String? normalizeDisplayName(String? raw) {
  if (raw == null) return null;
  final collapsed = raw.replaceAll(_whitespaceRun, ' ');
  final stripped = collapsed.replaceAll(_controlCharacters, '');
  final trimmed = stripped.trim();
  if (trimmed.isEmpty) return null;
  if (trimmed.characters.length > displayNameMaxLength) return null;
  return trimmed;
}

/// Single-character avatar fallback: the name, then the email local part, then
/// "?".
///
/// One grapheme cluster is used (not one UTF-16 code unit) so an emoji or a flag
/// is never cut in half and rendered as a replacement box. Uppercasing is a
/// no-op for emoji.
String accountInitial({String? displayName, String? email}) {
  final name = normalizeDisplayName(displayName);
  if (name != null) return _firstCharacterUpper(name);

  final localPart = _emailLocalPart(email);
  if (localPart.isNotEmpty) return _firstCharacterUpper(localPart);

  return '?';
}

String _firstCharacterUpper(String value) {
  final characters = value.characters;
  if (characters.isEmpty) return '?';
  return characters.first.toUpperCase();
}

String _emailLocalPart(String? email) {
  final trimmed = (email ?? '').trim();
  if (trimmed.isEmpty) return '';
  final at = trimmed.indexOf('@');
  return at <= 0 ? (at == 0 ? '' : trimmed) : trimmed.substring(0, at);
}
