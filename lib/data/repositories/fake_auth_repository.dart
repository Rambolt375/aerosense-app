import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/core/account_name.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';

/// Fake [AuthRepository] for Demo Mode.
///
/// Signs in automatically without Firebase, emitting a synthetic user. Profile
/// edits live in memory only and are discarded when Demo Mode is switched off.
class FakeAuthRepository implements AuthRepository {
  FakeAuthRepository() : _user = _FakeUser();

  _FakeUser _user;
  final StreamController<User?> _changes = StreamController<User?>.broadcast();

  /// Both streams start with the current user so a late listener never misses
  /// the signed-in state.
  ///
  /// `authStateChanges` mirrors Firebase and reports sign-in/out only, so a
  /// profile edit never looks like a new session. `userChanges` also follows
  /// profile edits.
  ///
  /// Built with [Stream.multi] instead of an `async*` + `yield*` generator: a
  /// generator keeps its inner subscription alive, so closing the broadcast
  /// controller while a listener is attached never resolves `close()`.
  @override
  Stream<User?> authStateChanges() => Stream.value(_user);

  @override
  Stream<User?> userChanges() => _profileStream();

  Stream<User?> _profileStream() {
    return Stream<User?>.multi((controller) {
      controller.add(_user);
      final listener = _changes.stream.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = listener.cancel;
    });
  }

  @override
  User? get currentUser => _user;

  @override
  Future<void> updateDisplayName(String name) async {
    final clean = normalizeDisplayName(name);
    if (clean == null) {
      throw const AuthFailure(AppStrings.profileNameInvalid);
    }
    // Emit a new instance, mirroring an auth layer that rebuilds the profile.
    _user = _FakeUser(displayName: clean);
    _changes.add(_user);
  }

  @override
  Future<void> signIn({required String email, required String password}) async {
    // Demo Mode: sign-in is automatic, nothing to do.
  }

  @override
  Future<void> signInWithGoogle() async {
    // Demo Mode: synthetic sign-in succeeds immediately.
  }

  @override
  Future<void> signOut() async {
    // No-op in Demo Mode — sign-out has no effect without real auth.
  }

  /// Closes the change stream; called when Demo Mode is switched off.
  Future<void> dispose() => _changes.close();
}

/// Synthetic [User] implementation for demo/fake auth.
class _FakeUser implements User {
  _FakeUser({this.displayName = 'Demo User'});

  @override
  String get uid => 'demo-uid';

  @override
  String? get email => 'demo@aerosense.local';

  @override
  final String? displayName;

  @override
  bool get isAnonymous => false;

  @override
  bool get emailVerified => true;

  @override
  String? get photoURL => null;

  @override
  List<UserInfo> get providerData => const [];

  // Unused User interface members — not needed for the demo flow.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
