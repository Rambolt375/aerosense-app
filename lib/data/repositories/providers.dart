import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  return isDemo ? FakeAuthRepository() : FirebaseAuthRepository();
});

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  return isDemo
      ? ref.watch(fakeSystemRepositoryProvider)
      : FirebaseSystemRepository();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  final isDemo = ref.watch(demoModeProvider);
  return isDemo ? FakeHistoryRepository() : FirebaseHistoryRepository();
});

// ---------------------------------------------------------------------------
// Auth providers
// ---------------------------------------------------------------------------

/// Stream of the signed-in [User]. Emits null when signed out.
final authStateProvider = StreamProvider<User?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
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
