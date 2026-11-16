import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/data/models/account_info.dart';
import 'package:aerosense_app/data/models/forecast_preferences.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/firebase_auth_repository.dart';
import 'package:aerosense_app/data/repositories/firebase_history_repository.dart';
import 'package:aerosense_app/data/repositories/firebase_system_repository.dart';
import 'package:aerosense_app/data/repositories/history_repository.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';

// ---------------------------------------------------------------------------
// Demo Mode provider
// ---------------------------------------------------------------------------

/// Compile-time demo flag. Set with --dart-define=DEMO=true.
const bool kDemoDefault = bool.fromEnvironment('DEMO', defaultValue: false);

/// State notifier managing runtime Demo Mode.
class DemoModeNotifier extends Notifier<bool> {
  @override
  bool build() => kDemoDefault;

  /// Toggles demo mode on or off.
  void toggle() => state = !state;

  /// Sets demo mode explicitly.
  void setDemo(bool value) => state = value;
}

/// Dynamic demo mode provider.
final demoModeProvider = NotifierProvider<DemoModeNotifier, bool>(
  DemoModeNotifier.new,
);

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

/// Dedicated [FakeSystemRepository] provider for Demo Mode.
///
/// Watches [demoModeProvider] so all timers and controllers are cancelled and
/// disposed via [FakeSystemRepository.dispose] whenever demo mode is toggled off.
final fakeSystemRepositoryProvider = Provider<FakeSystemRepository>((ref) {
  ref.watch(demoModeProvider);
  final repo = FakeSystemRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  return isDemo
      ? ref.watch(fakeAuthRepositoryProvider)
      : FirebaseAuthRepository();
});

/// Dedicated [FakeAuthRepository] provider for Demo Mode.
///
/// Watches [demoModeProvider] so the change stream is closed whenever demo mode
/// is toggled off, and the in-memory profile edit is discarded.
final fakeAuthRepositoryProvider = Provider<FakeAuthRepository>((ref) {
  ref.watch(demoModeProvider);
  final repo = FakeAuthRepository();
  ref.onDispose(repo.dispose);
  return repo;
});

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  return isDemo
      ? ref.watch(fakeSystemRepositoryProvider)
      : FirebaseSystemRepository();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) {
    final repo = FakeHistoryRepository();
    ref.onDispose(repo.dispose);
    return repo;
  }
  return FirebaseHistoryRepository();
});

// ---------------------------------------------------------------------------
// Auth providers
// ---------------------------------------------------------------------------

/// Stream of the signed-in [User]. Emits null when signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

/// Stream of the signed-in [User] that also emits on profile changes.
final userChangesProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).userChanges();
});

/// Plain account view for the avatar and the profile screen.
///
/// Built from [AuthRepository.userChanges] and mapped to a fresh [AccountInfo]
/// per event, so a rename repaints the avatar even when the auth layer re-emits
/// the same user instance.
final accountProvider = StreamProvider<AccountInfo?>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  return ref
      .watch(authRepositoryProvider)
      .userChanges()
      .map(
        (user) =>
            user == null ? null : _accountInfoFromUser(user, isDemo: isDemo),
      );
});

AccountInfo _accountInfoFromUser(User user, {required bool isDemo}) {
  var isGoogle = false;
  try {
    isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
  } catch (_) {}

  final photo = user.photoURL;
  return AccountInfo(
    displayName: user.displayName ?? '',
    email: user.email ?? '',
    photoUrl: photo == null || photo.isEmpty ? null : photo,
    kind: isDemo
        ? AccountProviderKind.demo
        : (isGoogle ? AccountProviderKind.google : AccountProviderKind.team),
    isDemo: isDemo,
  );
}

/// Signed-in account id, exposed as a plain string so UI/providers do not need
/// Firebase types. Used only for the Ask AeroSense client rate-limit bucket.
final currentUserUidProvider = Provider<String?>((ref) {
  final user = ref.watch(authStateProvider).asData?.value;
  return user?.uid;
});

/// Whether the current authenticated session is a team member account.
///
/// NOTE on Security Authority:
/// This UI gate is cosmetic (hiding administrative controls and pre-ventilation switches).
/// The Firebase Realtime Database Security Rules (`database.rules.json`) are the real
/// authority (enforcing write operations strictly by specific team account UIDs).
final isTeamAccountProvider = Provider<bool>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  if (isDemo) return true; // Demo mode permits full evaluation of team controls

  final user = ref.watch(authStateProvider).asData?.value;
  if (user == null) return false;

  bool isGoogle = false;
  try {
    isGoogle = user.providerData.any((p) => p.providerId == 'google.com');
  } catch (_) {}

  // Email/password team members only (Google sign-in is treated as booth visitor)
  return !isGoogle;
});

// ---------------------------------------------------------------------------
// System telemetry providers
// ---------------------------------------------------------------------------

/// Parsed live system state from `/system`.
final systemStateProvider = StreamProvider<SystemState>((ref) {
  return ref.watch(systemRepositoryProvider).watchSystemState();
});

/// App-to-Firebase connection status.
final connectedProvider = StreamProvider<bool>((ref) {
  return ref.watch(systemRepositoryProvider).watchConnected();
});

/// Raw snapshot value from `/system`, for the debug screen only.
final rawSystemProvider = StreamProvider<Object?>((ref) {
  return ref.watch(systemRepositoryProvider).watchRawSystem();
});

/// Raw configuration map from `/config`.
final configStreamProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(systemRepositoryProvider).watchConfig();
});

/// Stream of `/forecast` node from RTDB for automated pre-ventilation settings.
final forecastPreferencesProvider = StreamProvider<ForecastPreferences>((ref) {
  return ref.watch(systemRepositoryProvider).watchForecastPreferences();
});

/// Known manual ventilation duration from `/config/manualDurationSec`, or null if not present.
// TODO(confirm): /config/manualDurationSec is planned firmware contract; app works without it.
final manualDurationProvider = Provider<Duration?>((ref) {
  final config = ref.watch(configStreamProvider).asData?.value;
  if (config != null) {
    final sec = config['manualDurationSec'];
    if (sec is num && sec > 0) {
      return Duration(seconds: sec.toInt());
    }
  }
  return null;
});
