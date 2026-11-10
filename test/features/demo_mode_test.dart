import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/app.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/history_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';
import 'package:aerosense_app/features/auth/login_screen.dart';
import 'package:aerosense_app/features/settings/settings_screen.dart';
import 'package:aerosense_app/shared/demo_ribbon.dart';

void main() {
  group('Demo Mode Provider & Repositories', () {
    test(
      'demoModeProvider defaults to compile-time flag and can be toggled',
      () {
        final container = ProviderContainer();
        addTearDown(container.dispose);

        expect(container.read(demoModeProvider), equals(kDemoDefault));

        container.read(demoModeProvider.notifier).setDemo(true);
        expect(container.read(demoModeProvider), isTrue);

        container.read(demoModeProvider.notifier).toggle();
        expect(container.read(demoModeProvider), isFalse);
      },
    );

    test(
      'repositories switch dynamically between Fake and Live implementations',
      () {
        final mockLiveAuth = _MockLiveAuthRepository();
        final mockLiveSystem = _MockLiveSystemRepository();
        final mockLiveHistory = _MockLiveHistoryRepository();

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              final isDemo = ref.watch(demoModeProvider);
              return isDemo ? FakeAuthRepository() : mockLiveAuth;
            }),
            systemRepositoryProvider.overrideWith((ref) {
              final isDemo = ref.watch(demoModeProvider);
              return isDemo
                  ? ref.watch(fakeSystemRepositoryProvider)
                  : mockLiveSystem;
            }),
            historyRepositoryProvider.overrideWith((ref) {
              final isDemo = ref.watch(demoModeProvider);
              return isDemo ? FakeHistoryRepository() : mockLiveHistory;
            }),
          ],
        );
        addTearDown(container.dispose);

        // Explicitly set to false (live mode)
        container.read(demoModeProvider.notifier).setDemo(false);
        expect(container.read(authRepositoryProvider), equals(mockLiveAuth));
        expect(
          container.read(systemRepositoryProvider),
          equals(mockLiveSystem),
        );
        expect(
          container.read(historyRepositoryProvider),
          equals(mockLiveHistory),
        );

        // Switch to Demo Mode
        container.read(demoModeProvider.notifier).setDemo(true);
        expect(
          container.read(authRepositoryProvider),
          isA<FakeAuthRepository>(),
        );
        expect(
          container.read(systemRepositoryProvider),
          isA<FakeSystemRepository>(),
        );
        expect(
          container.read(historyRepositoryProvider),
          isA<FakeHistoryRepository>(),
        );

        // Switch back to live mode
        container.read(demoModeProvider.notifier).setDemo(false);
        expect(container.read(authRepositoryProvider), equals(mockLiveAuth));
        expect(
          container.read(systemRepositoryProvider),
          equals(mockLiveSystem),
        );
        expect(
          container.read(historyRepositoryProvider),
          equals(mockLiveHistory),
        );
      },
    );

    test('fake repository timers cancel when demo turns off', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(demoModeProvider.notifier).setDemo(true);
      final repo = container.read(fakeSystemRepositoryProvider);

      // Start listening to stream
      final sub = repo.watchSystemState().listen((_) {});
      expect(repo.hasActiveTimers, isTrue);

      // Turn demo mode off -> repo disposed and timers cancelled
      container.read(demoModeProvider.notifier).setDemo(false);
      expect(repo.hasActiveTimers, isFalse);

      sub.cancel();
    });
  });

  group('Demo Ribbon & Padding Removal', () {
    testWidgets(
      'DemoRibbon appears when demoModeProvider is true and disappears when false',
      (tester) async {
        final mockLiveAuth = _MockLiveAuthRepository();

        final container = ProviderContainer(
          overrides: [
            authRepositoryProvider.overrideWith((ref) {
              final isDemo = ref.watch(demoModeProvider);
              return isDemo ? FakeAuthRepository() : mockLiveAuth;
            }),
            systemRepositoryProvider.overrideWith((ref) {
              final isDemo = ref.watch(demoModeProvider);
              return isDemo
                  ? ref.watch(fakeSystemRepositoryProvider)
                  : _MockLiveSystemRepository();
            }),
            historyRepositoryProvider.overrideWith((ref) {
              final isDemo = ref.watch(demoModeProvider);
              return isDemo
                  ? FakeHistoryRepository()
                  : _MockLiveHistoryRepository();
            }),
          ],
        );
        addTearDown(container.dispose);

        // 1. Live mode: demoMode is false
        container.read(demoModeProvider.notifier).setDemo(false);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const AeroSenseApp(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(DemoRibbon), findsNothing);

        // 2. Demo mode: set to true
        container.read(demoModeProvider.notifier).setDemo(true);
        await tester.pumpAndSettle();

        expect(find.byType(DemoRibbon), findsOneWidget);
        expect(find.text('DEMO MODE'), findsOneWidget);

        // 3. Switch back to false
        container.read(demoModeProvider.notifier).setDemo(false);
        await tester.pumpAndSettle();

        expect(find.byType(DemoRibbon), findsNothing);

        container.dispose();
      },
    );

    testWidgets('removes top padding for child when ribbon is active', (
      tester,
    ) async {
      double? innerTopPadding;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            demoModeProvider.overrideWith(() => _TestDemoNotifier(true)),
          ],
          child: MaterialApp(
            home: MediaQuery(
              data: const MediaQueryData(padding: EdgeInsets.only(top: 40)),
              child: Consumer(
                builder: (context, ref, _) {
                  final isDemo = ref.watch(demoModeProvider);
                  return Column(
                    children: [
                      if (isDemo) const DemoRibbon(),
                      Expanded(
                        child: MediaQuery.removePadding(
                          context: context,
                          removeTop: true,
                          child: Builder(
                            builder: (ctx) {
                              innerTopPadding = MediaQuery.paddingOf(ctx).top;
                              return const SizedBox();
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(innerTopPadding, equals(0.0));
    });
  });

  group('LoginScreen "Try Demo Mode" Button', () {
    testWidgets(
      'renders "Try Demo Mode" button and clicking activates demo mode',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            demoModeProvider.overrideWith(() => _TestDemoNotifier(false)),
            authRepositoryProvider.overrideWithValue(_MockLiveAuthRepository()),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: LoginScreen()),
          ),
        );

        final tryDemoButton = find.widgetWithText(
          OutlinedButton,
          'Try Demo Mode',
        );
        expect(tryDemoButton, findsOneWidget);

        expect(container.read(demoModeProvider), isFalse);
        await tester.tap(tryDemoButton);
        await tester.pump();

        expect(container.read(demoModeProvider), isTrue);
      },
    );
  });

  group('SettingsScreen Demo Controls', () {
    testWidgets('switch toggles demo mode and reveals simulation triggers', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          demoModeProvider.overrideWith(() => _TestDemoNotifier(false)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );

      // Initially demo mode is false -> scenario card not present
      expect(find.text('Simulation Scenarios'), findsNothing);
      expect(find.text('Simulate Kitchen Smoke'), findsNothing);

      // Toggle switch to true
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      await tester.tap(switchFinder);
      await tester.pump();

      expect(container.read(demoModeProvider), isTrue);

      // Now scenario buttons are visible
      expect(find.text('Simulation Scenarios'), findsOneWidget);
      expect(find.text('Simulate Kitchen Smoke'), findsOneWidget);
      expect(find.text('Simulate Heat Spike'), findsOneWidget);
      expect(find.text('Reset to Baseline'), findsOneWidget);

      // Trigger kitchen smoke
      final smokeBtn = find.text('Simulate Kitchen Smoke');
      await tester.tap(smokeBtn);
      await tester.pump();

      final fakeRepo = container.read(fakeSystemRepositoryProvider);
      expect(fakeRepo.currentScenario, equals(DemoScenario.smoke));

      // Trigger heat spike
      final heatBtn = find.text('Simulate Heat Spike');
      await tester.tap(heatBtn);
      await tester.pump();

      expect(fakeRepo.currentScenario, equals(DemoScenario.heat));

      // Reset to baseline
      final resetBtn = find.text('Reset to Baseline');
      await tester.tap(resetBtn);
      await tester.pump();

      expect(fakeRepo.currentScenario, equals(DemoScenario.none));
    });
  });
}

class _TestDemoNotifier extends DemoModeNotifier {
  _TestDemoNotifier(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

class _MockLiveAuthRepository implements AuthRepository {
  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {}
}

class _MockLiveSystemRepository implements SystemRepository {
  @override
  Stream<bool> watchConnected() => Stream.value(true);

  @override
  Stream<Object?> watchRawSystem() => const Stream.empty();

  @override
  Stream<SystemState> watchSystemState() => const Stream.empty();

  @override
  Future<void> setManualToggle(bool value) async {}
}

class _MockLiveHistoryRepository implements HistoryRepository {
  @override
  Future<List<HistoryRecord>> fetchHistory({int limit = 288}) async => [];

  @override
  Stream<HistoryRecord> watchNewRecords() => const Stream.empty();
}
