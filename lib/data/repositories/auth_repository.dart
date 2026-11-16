import 'package:firebase_auth/firebase_auth.dart';

/// Authentication operations the app requires.
///
/// The UI and router never call FirebaseAuth directly — they go through this
/// interface so the fake implementation can substitute cleanly in Demo Mode.
abstract class AuthRepository {
  /// Stream of the signed-in [User]. Emits null when signed out.
  ///
  /// Fires on sign-in and sign-out only; profile edits do not re-emit here.
  Stream<User?> authStateChanges();

  /// Stream of the signed-in [User] that also emits when the profile changes
  /// (display name, photo). Used by the avatar and the profile screen so a
  /// rename shows up without a reload. Emits null when signed out.
  Stream<User?> userChanges();

  /// Returns the currently signed-in [User] synchronously, or null.
  User? get currentUser;

  /// Updates the signed-in user's display name.
  ///
  /// The name is normalized (trimmed, inner whitespace collapsed, control
  /// characters removed) and must be 1-40 characters. This is a Firebase Auth
  /// profile change, not a Realtime Database write.
  ///
  /// Throws [AuthFailure] when the name is invalid or the update fails.
  Future<void> updateDisplayName(String name);

  /// Signs in with [email] and [password].
  ///
  /// Throws [AuthFailure] on bad credentials or other auth errors.
  Future<void> signIn({required String email, required String password});

  /// Signs in with Google OAuth.
  ///
  /// On Web, uses popup authentication. On Android, invokes the Google Sign In SDK.
  /// If the user dismisses the sign-in prompt, completes cleanly without throwing.
  /// Throws [AuthFailure] on network errors, blocked popups, or auth exceptions.
  Future<void> signInWithGoogle();

  /// Signs out the current user.
  Future<void> signOut();
}

/// Friendly authentication failure surfaced to the UI.
class AuthFailure implements Exception {
  const AuthFailure(this.message);
  final String message;

  @override
  String toString() => 'AuthFailure($message)';
}
