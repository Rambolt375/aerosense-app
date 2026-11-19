import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/app.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/landing/landing_providers.dart';
import 'package:aerosense_app/features/landing/landing_copy.dart';
import 'package:aerosense_app/features/landing/landing_screen.dart';

import '../../support/test_auth_repository.dart';

/// Auth repository whose session can be flipped during a test.
class _SwitchableAuthRepository implements AuthRepository {
  _SwitchableAuthRepository([this._user]);

  final StreamController<User?> _controller =
      StreamController<User?>.broadcast();
  User? _user;

  @override
  Stream<User?> authStateChanges() => _controller.stream;

  @override
  Stream<User?> userChanges() => _controller.stream;

  @override
  User? get currentUser => _user;

  void emit(User? user) {
    _user = user;
    _controller.add(user);
  }

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signInWithGoogle() async {}

  @override
  Future<void> signOut() async => emit(null);

  @override
  Future<void> updateDisplayName(String name) async {}

  Future<void> dispose() => _controller.close();
}

Future<_SwitchableAuthRepository> _pumpApp(
  WidgetTester tester, {
  required bool web,
  bool signedIn = false,
}) async {
  final auth = _SwitchableAuthRepository(
    signedIn ? TestAuthUser(displayName: 'Alice Visitor') : null,
  );
  addTearDown(auth.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Mirror the real provider: Demo Mode swaps in the fake auth, which
        // signs in automatically. Everything else uses the switchable double.
        authRepositoryProvider.overrideWith((ref) {
          final isDemo = ref.watch(demoModeProvider);
          return isDemo ? ref.watch(fakeAuthRepositoryProvider) : auth;
        }),
        systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
        historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        webLandingEnabledProvider.overrideWithValue(web),
      ],
      child: const AeroSenseApp(),
    ),
  );
  // Let the first auth event resolve the splash.
  auth.emit(auth.currentUser);
  await tester.pumpAndSettle();
  return auth;
}

GoRouter _router(WidgetTester tester) {
  return ProviderScope.containerOf(tester.element(find.byType(AeroSenseApp)))
      .read(routerProvider);
}

String _location(WidgetTester tester) =>
    _router(tester).routerDelegate.currentConfiguration.uri.toString();

void main() {
  group('redirect table', () {
    testWidgets('web, signed out: stays on the landing page', (tester) async {
      await _pumpApp(tester, web: true);

      expect(find.byType(LandingScreen), findsOneWidget);
      expect(_location(tester), '/');
    });

    testWidgets('Android, signed out: goes straight to /login', (tester) async {
      await _pumpApp(tester, web: false);

      expect(find.byType(LandingScreen), findsNothing);
      expect(_location(tester), '/login');
      expect(find.text('Adaptive Ventilation Companion'), findsOneWidget);
    });

    testWidgets('signed in on web: / goes to the dashboard', (tester) async {
      await _pumpApp(tester, web: true, signedIn: true);

      expect(_location(tester), '/dashboard');
      expect(find.text('Dashboard'), findsWidgets);
    });

    testWidgets('signed in on Android: / goes to the dashboard', (
      tester,
    ) async {
      await _pumpApp(tester, web: false, signedIn: true);

      expect(_location(tester), '/dashboard');
    });

    testWidgets('signed in: /login goes to the dashboard', (tester) async {
      await _pumpApp(tester, web: true, signedIn: true);

      _router(tester).go('/login');
      await tester.pumpAndSettle();

      expect(_location(tester), '/dashboard');
    });

    testWidgets('signed out: /login is public', (tester) async {
      await _pumpApp(tester, web: true);

      _router(tester).go('/login');
      await tester.pumpAndSettle();

      expect(_location(tester), '/login');
    });

    testWidgets('deep link survives the sign-in round trip', (tester) async {
      final auth = await _pumpApp(tester, web: true);

      _router(tester).go('/history');
      await tester.pumpAndSettle();

      expect(_location(tester), '/login?from=%2Fhistory');

      auth.emit(TestAuthUser(displayName: 'Alice Visitor'));
      await tester.pumpAndSettle();

      expect(_location(tester), '/history');
    });

    testWidgets('an external from value is ignored after sign-in', (
      tester,
    ) async {
      final auth = await _pumpApp(tester, web: true);

      _router(
        tester,
      ).go('/login?from=${Uri.encodeComponent('https://evil.example/steal')}');
      await tester.pumpAndSettle();

      auth.emit(TestAuthUser(displayName: 'Alice Visitor'));
      await tester.pumpAndSettle();

      expect(_location(tester), '/dashboard');
    });

    testWidgets('the router keeps its identity across sign-in', (tester) async {
      final auth = await _pumpApp(tester, web: true);
      final before = _router(tester);

      auth.emit(TestAuthUser(displayName: 'Alice Visitor'));
      await tester.pumpAndSettle();

      expect(identical(_router(tester), before), isTrue);
    });

    testWidgets('signing out on web returns to the landing page', (
      tester,
    ) async {
      final auth = await _pumpApp(tester, web: true, signedIn: true);
      expect(_location(tester), '/dashboard');

      auth.emit(null);
      await tester.pumpAndSettle();

      expect(_location(tester), '/');
      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets('signing out on Android returns to /login', (tester) async {
      final auth = await _pumpApp(tester, web: false, signedIn: true);

      auth.emit(null);
      await tester.pumpAndSettle();

      expect(_location(tester), '/login');
    });

    testWidgets('a cold-start deep link survives the splash round trip', (
      tester,
    ) async {
      final auth = _SwitchableAuthRepository();
      addTearDown(auth.dispose);

      // The browser opens `/#/history`; the router starts at splash with `from`.
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            historyRepositoryProvider.overrideWithValue(
              FakeHistoryRepository(),
            ),
            webLandingEnabledProvider.overrideWithValue(true),
          ],
          child: const AeroSenseApp(),
        ),
      );
      final router = ProviderScope.containerOf(
        tester.element(find.byType(AeroSenseApp)),
      ).read(routerProvider);
      router.go('/splash?from=%2Fhistory');
      await tester.pump();

      auth.emit(null);
      await tester.pumpAndSettle();

      expect(_location(tester), '/login?from=%2Fhistory');

      auth.emit(TestAuthUser(displayName: 'Alice Visitor'));
      await tester.pumpAndSettle();

      expect(_location(tester), '/history');
    });

    testWidgets('a cold-start visit to / on web lands on the landing page', (
      tester,
    ) async {
      final auth = _SwitchableAuthRepository();
      addTearDown(auth.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            historyRepositoryProvider.overrideWithValue(
              FakeHistoryRepository(),
            ),
            webLandingEnabledProvider.overrideWithValue(true),
          ],
          child: const AeroSenseApp(),
        ),
      );
      auth.emit(null);
      await tester.pumpAndSettle();

      expect(_location(tester), '/');
      expect(find.byType(LandingScreen), findsOneWidget);
    });

    testWidgets('"Try the demo" from the landing page opens the dashboard', (
      tester,
    ) async {
      await _pumpApp(tester, web: true);
      expect(find.byType(LandingScreen), findsOneWidget);

      await tester.tap(find.text(LandingCopy.tryDemo));
      await tester.pumpAndSettle();

      expect(_location(tester), '/dashboard');
      expect(find.byType(LandingScreen), findsNothing);
    });
  });

  group('safeRedirectFrom', () {
    test('keeps internal deep links', () {
      expect(safeRedirectFrom('/history'), '/history');
      expect(safeRedirectFrom('/forecast?tab=week'), '/forecast?tab=week');
      expect(safeRedirectFrom('/profile'), '/profile');
    });

    test('rejects the entry points, external URLs and empty values', () {
      expect(safeRedirectFrom(null), isNull);
      expect(safeRedirectFrom(''), isNull);
      expect(safeRedirectFrom('/'), isNull);
      expect(safeRedirectFrom('/login'), isNull);
      expect(safeRedirectFrom('/splash'), isNull);
      expect(safeRedirectFrom('/dashboard'), isNull);
      expect(safeRedirectFrom('https://evil.example'), isNull);
      expect(safeRedirectFrom('//evil.example/path'), isNull);
      expect(safeRedirectFrom('history'), isNull);
    });
  });
}
