import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';

/// Fake [AuthRepository] for Demo Mode.
///
/// Signs in automatically without Firebase, emitting a synthetic user.
class FakeAuthRepository implements AuthRepository {
  @override
  Stream<User?> authStateChanges() => Stream.value(_FakeUser());

  @override
  User? get currentUser => _FakeUser();

  @override
  Future<void> signIn({required String email, required String password}) async {
    // Demo Mode: sign-in is automatic, nothing to do.
  }

  @override
  Future<void> signOut() async {
    // No-op in Demo Mode — sign-out has no effect without real auth.
  }
}

/// Synthetic [User] implementation for demo/fake auth.
class _FakeUser implements User {
  @override
  String get uid => 'demo-uid';

  @override
  String? get email => 'demo@aerosense.local';

  @override
  String? get displayName => 'Demo User';

  @override
  bool get isAnonymous => false;

  @override
  bool get emailVerified => true;

  // Unused User interface members — not needed for the demo flow.
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
