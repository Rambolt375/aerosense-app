import 'package:flutter/foundation.dart';
import 'package:aerosense_app/core/account_name.dart';

/// Where the signed-in account comes from. Drives the provider chip only;
/// security authority stays with the Firebase rules.
enum AccountProviderKind { google, team, demo }

/// Plain read-only view of the signed-in account.
///
/// Deliberately free of Firebase types so the UI never imports `firebase_auth`;
/// the data layer maps a `User` onto this model.
@immutable
class AccountInfo {
  const AccountInfo({
    required this.displayName,
    required this.email,
    required this.kind,
    this.photoUrl,
    this.isDemo = false,
  });

  /// Raw profile name; may be empty when the account has never set one.
  final String displayName;

  /// Read-only email, empty when the provider did not share one.
  final String email;

  /// Remote avatar image, or null.
  final String? photoUrl;

  final AccountProviderKind kind;

  /// Demo Mode accounts never persist a profile edit.
  final bool isDemo;

  /// Single-character avatar fallback (emoji-safe).
  String get initial => accountInitial(displayName: displayName, email: email);

  /// Human label for the current avatar/menu, never empty.
  String get displayLabel {
    if (displayName.trim().isNotEmpty) return displayName.trim();
    final at = email.indexOf('@');
    if (at > 0) return email.substring(0, at);
    if (email.isNotEmpty) return email;
    return 'Account';
  }
}
