import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/auth/login_screen.dart';

class _MockAuthRepository implements AuthRepository {
  bool googleSignInCalled = false;
  bool emailSignInCalled = false;
  String? lastEmail;
  String? lastPassword;
  Exception? exceptionToThrow;

  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  Stream<User?> userChanges() => authStateChanges();

  @override
  User? get currentUser => null;

  @override
  Future<void> updateDisplayName(String name) async {}

  @override
  Future<void> signIn({required String email, required String password}) async {
    emailSignInCalled = true;
    lastEmail = email;
    lastPassword = password;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<void> signInWithGoogle() async {
    googleSignInCalled = true;
    if (exceptionToThrow != null) throw exceptionToThrow!;
  }

  @override
  Future<void> signOut() async {}
}

void main() {
  test('assets/icon/icon.png asset file exists in repo', () {
    final file = File('assets/icon/icon.png');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'assets/icon/icon.png must exist',
    );
  });

  test('assets/icon/google_logo.png asset file exists in repo', () {
    final file = File('assets/icon/google_logo.png');
    expect(
      file.existsSync(),
      isTrue,
      reason: 'assets/icon/google_logo.png must exist',
    );
  });

  group('LoginScreen UI & Actions', () {
    testWidgets('renders all expected UI elements', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          ],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      // Icon with semantic label
      expect(find.bySemanticsLabel('AeroSense App Icon'), findsOneWidget);

      // Title & Subtitle
      expect(find.text('AeroSense'), findsOneWidget);
      expect(find.text('Adaptive Ventilation Companion'), findsOneWidget);

      // Primary Action: Continue with Google
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.bySemanticsLabel('Google icon'), findsOneWidget);

      // Secondary Team section
      expect(find.text('or team sign-in'), findsOneWidget);
      expect(find.byType(TextFormField), findsNWidgets(2));
      expect(find.text('Sign In as Team'), findsOneWidget);

      // Demo Mode button
      expect(find.text('Try Demo Mode'), findsOneWidget);
    });

    testWidgets('Continue with Google triggers signInWithGoogle', (
      tester,
    ) async {
      final mockAuth = _MockAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(mockAuth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.text('Continue with Google'));
      await tester.pump();

      expect(mockAuth.googleSignInCalled, isTrue);
    });

    testWidgets('Sign in as team validates empty fields', (tester) async {
      final mockAuth = _MockAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(mockAuth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.text('Sign In as Team'));
      await tester.pumpAndSettle();

      expect(find.text('Enter your email address.'), findsOneWidget);
      expect(find.text('Enter your password.'), findsOneWidget);
      expect(mockAuth.emailSignInCalled, isFalse);
    });

    testWidgets('Sign in as team triggers signIn with email and password', (
      tester,
    ) async {
      final mockAuth = _MockAuthRepository();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(mockAuth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'team@aerosense.local',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'team1234',
      );

      await tester.tap(find.text('Sign In as Team'));
      await tester.pumpAndSettle();

      expect(mockAuth.emailSignInCalled, isTrue);
      expect(mockAuth.lastEmail, 'team@aerosense.local');
      expect(mockAuth.lastPassword, 'team1234');
    });

    testWidgets('displays AuthFailure message when sign-in fails', (
      tester,
    ) async {
      final mockAuth = _MockAuthRepository()
        ..exceptionToThrow = const AuthFailure(
          'Email or password is incorrect.',
        );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authRepositoryProvider.overrideWithValue(mockAuth)],
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Email'),
        'team@aerosense.local',
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Password'),
        'wrongpassword',
      );

      await tester.tap(find.text('Sign In as Team'));
      await tester.pumpAndSettle();

      expect(find.text('Email or password is incorrect.'), findsOneWidget);
    });

    testWidgets('Try Demo Mode button enables demo mode', (tester) async {
      final container = ProviderContainer(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        ],
      );
      addTearDown(container.dispose);

      expect(container.read(demoModeProvider), isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );

      await tester.tap(find.text('Try Demo Mode'));
      await tester.pumpAndSettle();

      expect(container.read(demoModeProvider), isTrue);
    });
  });
}
