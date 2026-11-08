import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/widgets/fan_card.dart';

void main() {
  group('FanCard toggle behavior', () {
    testWidgets('Safe tier: toggle enabled, correct helper text when off', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.safe,
                  manualToggle: false,
                  fanOn: false,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      // Verify switch is enabled (finds a Switch with non-null onChanged)
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.onChanged, isNotNull);
      expect(switchWidget.value, isFalse);

      // Verify helper text
      expect(find.text('Manual toggle forces the fan on.'), findsOneWidget);
    });

    testWidgets('Safe tier with manualToggle=true: shows override message', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.safe,
                  manualToggle: true,
                  fanOn: true,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      expect(
        find.text('Manual override is on. The fan is running.'),
        findsOneWidget,
      );
    });

    testWidgets('Medium tier: toggle enabled, prominent helper text', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.medium,
                  manualToggle: false,
                  fanOn: false,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNotNull);

      expect(
        find.text('Room is stuffy. The fan stays off unless you turn it on.'),
        findsOneWidget,
      );
    });

    testWidgets('Danger tier: toggle disabled, locked to fanOn state', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.danger,
                  manualToggle: true,
                  fanOn: true,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull); // Disabled
      expect(switchWidget.value, isTrue); // Reflects fanOn

      expect(
        find.text(
          'Safety override active. The fan is forced on and manual control is bypassed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Offline: toggle disabled with offline message', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.safe,
                  manualToggle: false,
                  fanOn: false,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(false)),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);

      expect(
        find.text('App is offline. Fan control unavailable.'),
        findsOneWidget,
      );
    });

    testWidgets('Danger tier: no write called when switch tapped', (
      tester,
    ) async {
      final fakeRepo = FakeSystemRepository();
      var writeCalled = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWith((_) {
              return _WriteSnoopingSystemRepository(
                fakeRepo,
                onWrite: () => writeCalled = true,
              );
            }),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.danger,
                  manualToggle: true,
                  fanOn: true,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      // Switch is disabled in Danger, so tapping has no effect
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(writeCalled, isFalse);
    });
  });
}

/// Test double that wraps FakeSystemRepository and tracks setManualToggle calls.
class _WriteSnoopingSystemRepository extends FakeSystemRepository {
  _WriteSnoopingSystemRepository(this._inner, {required this.onWrite});

  final FakeSystemRepository _inner;
  final VoidCallback onWrite;

  @override
  Future<void> setManualToggle(bool value) {
    onWrite();
    return _inner.setManualToggle(value);
  }

  @override
  Stream<SystemState> watchSystemState() => _inner.watchSystemState();

  @override
  Stream<Object?> watchRawSystem() => _inner.watchRawSystem();

  @override
  Stream<bool> watchConnected() => _inner.watchConnected();
}
