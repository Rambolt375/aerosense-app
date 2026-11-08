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

/// Compile-time demo flag. Set with --dart-define=DEMO=true.
const bool _kDemo = bool.fromEnvironment('DEMO', defaultValue: false);

// ---------------------------------------------------------------------------
// Repository providers
// ---------------------------------------------------------------------------

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return _kDemo ? FakeAuthRepository() : FirebaseAuthRepository();
});

final systemRepositoryProvider = Provider<SystemRepository>((ref) {
  return _kDemo ? FakeSystemRepository() : FirebaseSystemRepository();
});

final historyRepositoryProvider = Provider<HistoryRepository>((ref) {
  return _kDemo ? FakeHistoryRepository() : FirebaseHistoryRepository();
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
