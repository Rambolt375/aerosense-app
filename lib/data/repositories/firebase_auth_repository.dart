import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';

/// Firebase Auth implementation of [AuthRepository].
class FirebaseAuthRepository implements AuthRepository {
  FirebaseAuthRepository({FirebaseAuth? auth})
    : _auth = auth ?? FirebaseAuth.instance;

  final FirebaseAuth _auth;
  bool _googleSignInInitialized = false;

  @override
  Stream<User?> authStateChanges() => _auth.authStateChanges();

  @override
  User? get currentUser => _auth.currentUser;

  @override
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (e) {
      throw AuthFailure(friendlyMessage(e.code));
    } catch (_) {
      throw const AuthFailure('Sign in failed. Please try again.');
    }
  }

  @override
  Future<void> signInWithGoogle() async {
    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();
        await _auth.signInWithPopup(provider);
      } else {
        if (!_googleSignInInitialized) {
          await GoogleSignIn.instance.initialize();
          _googleSignInInitialized = true;
        }
        final account = await GoogleSignIn.instance.authenticate();
        final authTokens = account.authentication;
        final credential = GoogleAuthProvider.credential(
          idToken: authTokens.idToken,
        );
        await _auth.signInWithCredential(credential);
      }
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled ||
          e.code == GoogleSignInExceptionCode.interrupted) {
        // User cancelled the prompt; return cleanly without displaying an error.
        return;
      }
      throw AuthFailure(friendlyMessage(e.code.name));
    } on FirebaseAuthException catch (e) {
      if (isCancellationCode(e.code)) {
        // Popup closed by user before finishing authentication.
        return;
      }
      throw AuthFailure(friendlyMessage(e.code));
    } catch (e) {
      final message = e.toString().toLowerCase();
      if (message.contains('disallowed_useragent')) {
        throw AuthFailure(friendlyMessage('disallowed_useragent'));
      }
      throw const AuthFailure('Sign in failed. Please try again.');
    }
  }

  @override
  Future<void> signOut() async {
    try {
      if (!kIsWeb) {
        await GoogleSignIn.instance.signOut();
      }
    } catch (_) {}
    await _auth.signOut();
  }

  /// Whether [code] represents a user-initiated cancellation.
  static bool isCancellationCode(String code) {
    return code == 'popup-closed-by-user' ||
        code == 'canceled' ||
        code == 'interrupted';
  }

  /// Maps FirebaseAuth error codes to short, user-friendly messages.
  static String friendlyMessage(String code) {
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
        return 'Sign-in method is not enabled.';
      case 'popup-blocked':
        return 'Popup blocked by browser. Please allow popups for this site and try again.';
      case 'account-exists-with-different-credential':
        return 'An account already exists with this email using team credentials. Please sign in below.';
      case 'disallowed_useragent':
        return 'Google sign-in is not supported in this browser. Please open this page in Chrome or Safari.';
      default:
        return 'Sign in failed ($code).';
    }
  }
}
