import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/repositories/firebase_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';

void main() {
  group('FirebaseAuthRepository error mapping', () {
    test('maps credential errors accurately', () {
      expect(
        FirebaseAuthRepository.friendlyMessage('invalid-credential'),
        'Email or password is incorrect.',
      );
      expect(
        FirebaseAuthRepository.friendlyMessage('wrong-password'),
        'Email or password is incorrect.',
      );
      expect(
        FirebaseAuthRepository.friendlyMessage('user-not-found'),
        'Email or password is incorrect.',
      );
    });

    test('maps OAuth and Google sign-in specific error codes', () {
      expect(
        FirebaseAuthRepository.friendlyMessage('popup-blocked'),
        'Popup blocked by browser. Please allow popups for this site and try again.',
      );
      expect(
        FirebaseAuthRepository.friendlyMessage(
          'account-exists-with-different-credential',
        ),
        'An account already exists with this email using team credentials. Please sign in below.',
      );
      expect(
        FirebaseAuthRepository.friendlyMessage('network-request-failed'),
        'No internet connection.',
      );
      expect(
        FirebaseAuthRepository.friendlyMessage('disallowed_useragent'),
        'Google sign-in is not supported in this browser. Please open this page in Chrome or Safari.',
      );
      expect(
        FirebaseAuthRepository.friendlyMessage('user-disabled'),
        'This account has been disabled.',
      );
    });

    test('identifies cancellation codes correctly', () {
      expect(
        FirebaseAuthRepository.isCancellationCode('popup-closed-by-user'),
        isTrue,
      );
      expect(FirebaseAuthRepository.isCancellationCode('canceled'), isTrue);
      expect(
        FirebaseAuthRepository.isCancellationCode('invalid-credential'),
        isFalse,
      );
    });
  });

  group('FakeAuthRepository', () {
    test('emits synthetic user on signInWithGoogle', () async {
      final repo = FakeAuthRepository();
      expect(repo.currentUser, isNotNull);
      expect(repo.currentUser!.displayName, 'Demo User');

      await repo.signInWithGoogle();
      expect(repo.currentUser, isNotNull);
    });
  });
}
