import 'package:firebase_auth/firebase_auth.dart';

/// Authentication operations the app requires.
///
/// The UI and router never call FirebaseAuth directly — they go through this
/// interface so the fake implementation can substitute cleanly in Demo Mode.
abstract class AuthRepository {
  /// Stream of the signed-in [User]. Emits null when signed out.
  Stream<User?> authStateChanges();

  /// Returns the currently signed-in [User] synchronously, or null.
  User? get currentUser;

  /// Signs in with [email] and [password].
  ///
  /// Throws [AuthFailure] on bad credentials or other auth errors.
  Future<void> signIn({required String email, required String password});

  /// Signs out the current user.
  Future<void> signOut();
}

/// Friendly authentication failure surfaced to the UI.
class AuthFailure {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => 'AuthFailure($message)';
}
