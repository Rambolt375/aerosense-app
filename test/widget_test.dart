import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/app.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';

void main() {
  testWidgets('AeroSenseApp launches to dashboard screen when authenticated', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        ],
        child: const AeroSenseApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Dashboard'), findsWidgets);
  });

  testWidgets('shows splash screen with spinner while auth is loading', (
    tester,
  ) async {
    final authStreamController = StreamController<User?>.broadcast();
    addTearDown(authStreamController.close);

    final mockAuth = _ConfigurableAuthRepository(
      authStream: authStreamController.stream,
      user: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        ],
        child: const AeroSenseApp(),
      ),
    );
    await tester.pump();

    // Splash route is active with progress indicator
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('redirects to /login when unauthenticated after auth resolves', (
    tester,
  ) async {
    final authStreamController = StreamController<User?>.broadcast();
    addTearDown(authStreamController.close);

    final mockAuth = _ConfigurableAuthRepository(
      authStream: authStreamController.stream,
      user: null,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(mockAuth),
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        ],
        child: const AeroSenseApp(),
      ),
    );

    authStreamController.add(null);
    await tester.pumpAndSettle();

    expect(find.text('Adaptive Ventilation Companion'), findsOneWidget);
  });

  testWidgets('splash returns to original from parameter after auth resolves', (
    tester,
  ) async {
    final authRepo = FakeAuthRepository();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(authRepo),
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        ],
        child: const AeroSenseApp(),
      ),
    );

    // Navigate to splash with from parameter
    final router = ProviderScope.containerOf(
      tester.element(find.byType(AeroSenseApp)),
    ).read(routerProvider);
    router.go('/splash?from=%2Fsettings');
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsWidgets);
  });
}

class _ConfigurableAuthRepository implements AuthRepository {
  _ConfigurableAuthRepository({
    required Stream<User?> authStream,
    required this.user,
  }) : _authStream = authStream.asBroadcastStream();

  final Stream<User?> _authStream;
  final User? user;

  @override
  Stream<User?> authStateChanges() => _authStream;

  @override
  User? get currentUser => user;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}
