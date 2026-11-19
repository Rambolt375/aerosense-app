import 'package:aerosense_app/features/summary/summary_models.dart';

/// Copy for the Ask AeroSense screen, in one place and in both languages.
///
/// The pinned line under the composer is deliberately one short sentence; the
/// full previous wording (including the privacy sentence and, in Demo Mode, the
/// scripted-answers note) lives in the "About this assistant" sheet so it is
/// still available without cluttering the screen.
class AssistantCopy {
  const AssistantCopy(this.language);

  final SummaryLanguage language;

  bool get _isId => language == SummaryLanguage.id;

  /// One short line under the composer.
  String get disclaimerShort => _isId
      ? 'AI bisa salah. Peringatan perangkat yang menentukan. '
            'Pertanyaan dikirim ke Google Gemini.'
      : 'AI can be wrong. The device alert decides. '
            'Questions go to Google Gemini.';

  /// Tooltip and sheet title for the info button.
  String get aboutTitle =>
      _isId ? 'Tentang asisten ini' : 'About this assistant';

  /// Full previous disclaimer wording, kept verbatim in the info sheet.
  String get disclaimerFull => _isId
      ? 'Dihasilkan AI, bisa salah. Peringatan perangkat adalah acuan.'
      : 'AI-generated, may be wrong. The device alert is authoritative.';

  /// Full privacy wording, kept verbatim in the info sheet.
  String get privacyFull => _isId
      ? 'Pertanyaan dikirim ke layanan Google Gemini. '
            'Jangan menuliskan informasi pribadi.'
      : "Questions are sent to Google's Gemini service. "
            "Don't type personal information.";

  /// Shown in the sheet only in Demo Mode.
  String get demoScriptedNote => _isId
      ? 'Mode Demo: jawaban sudah diprogram, bukan dari Gemini.'
      : 'Demo Mode: answers are scripted, not from Gemini.';

  /// One line explaining what the assistant may answer from.
  String get scopeNote => _isId
      ? 'Jawaban hanya memakai data yang dilaporkan perangkat. '
            'Perangkat tetap yang memutuskan keselamatan.'
      : 'Answers use only what the device reports. '
            'The device still decides safety.';
}
