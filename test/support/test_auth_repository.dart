import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/core/account_name.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';

/// Synthetic [User] used by the profile and account-menu tests.
class TestAuthUser implements User {
  TestAuthUser({
    this.displayName,
    this.email,
    this.photoURL,
    this.providerId = 'google.com',
  });

  @override
  String? displayName;

  @override
  final String? email;

  @override
  final String? photoURL;

  final String? providerId;

  @override
  String get uid => 'test-uid';

  @override
  List<UserInfo> get providerData =>
      providerId == null ? const [] : [_TestUserInfo(providerId!)];

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _TestUserInfo implements UserInfo {
  _TestUserInfo(this.providerId);

  @override
  final String providerId;

  @override
  String get uid => 'test-uid';

  @override
  String? get displayName => null;

  @override
  String? get email => null;

  @override
  String? get phoneNumber => null;

  @override
  String? get photoURL => null;
}

/// Auth repository double with observable edits and an injectable failure.
///
/// Emits on [userChanges] after a successful rename so the avatar and profile
/// screen refresh exactly as they do with Firebase.
class TestAuthRepository implements AuthRepository {
  TestAuthRepository({TestAuthUser? user})
    : _user =
          user ??
          TestAuthUser(
            displayName: 'Alice Visitor',
            email: 'alice@example.com',
          );

  /// Repository with no signed-in user (drives the `/login` redirect).
  TestAuthRepository.signedOut() : _user = null;

  final StreamController<User?> _changes = StreamController<User?>.broadcast();

  TestAuthUser? _user;

  /// When set, [updateDisplayName] throws this instead of saving.
  AuthFailure? failure;

  int updateCalls = 0;
  String? lastUpdateAttempt;
  bool signOutCalled = false;

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
    updateCalls++;
    lastUpdateAttempt = name;
    final failure = this.failure;
    if (failure != null) throw failure;

    final clean = normalizeDisplayName(name);
    if (clean == null) throw const AuthFailure(AppStrings.profileNameInvalid);

    final current = _user;
    _user = TestAuthUser(
      displayName: clean,
      email: current?.email,
      photoURL: current?.photoURL,
      providerId: current?.providerId,
    );
    _changes.add(_user);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }

  Future<void> dispose() => _changes.close();
}
