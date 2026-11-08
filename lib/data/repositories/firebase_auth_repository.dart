import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';

/// Firebase Auth implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(_friendlyMessage(e.code));
    } catch (_) {
      throw const AuthFailure('Sign in failed. Please try again.');
    }
  }

  @override
  Future<void> signOut() => _auth.signOut();

  /// Maps FirebaseAuth error codes to short, user-friendly messages.
  ///
  /// invalid-credential is the modern code (email enumeration protection,
  /// default on new Firebase projects since Sep 2023). The legacy codes
  /// wrong-password and user-not-found are retained for older projects.
  static String _friendlyMessage(String code) {
    switch (code) {
      case 'invalid-credential':
      case 'wrong-password':
      case 'user-not-found':
      case 'invalid-login-credentials':
        return 'Email or password is incorrect.';
      case 'invalid-email':
        return 'Enter a valid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'network-request-failed':
        return 'No internet connection.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled.';
      default:
        return 'Sign in failed ($code).';
    }
  }
}
