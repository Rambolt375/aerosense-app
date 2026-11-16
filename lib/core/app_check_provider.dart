import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/app_check.dart';

/// App Check activation state for the session.
///
/// Starts as [AppCheckStatus.notConfigured] so any widget built before
/// activation finishes (including every widget test) keeps the live assistant
/// hidden instead of exposing an unprotected path.
class AppCheckNotifier extends Notifier<AppCheckStatus> {
  @override
  AppCheckStatus build() => AppCheckStatus.notConfigured;

  /// Runs activation exactly once and publishes the result.
  Future<void> activate() async {
    if (state == AppCheckStatus.active) return;
    state = await activateAppCheck();
  }
}

final appCheckStatusProvider =
    NotifierProvider<AppCheckNotifier, AppCheckStatus>(AppCheckNotifier.new);
