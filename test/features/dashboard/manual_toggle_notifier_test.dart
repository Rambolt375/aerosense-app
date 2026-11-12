import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';
import 'package:aerosense_app/features/dashboard/manual_toggle_notifier.dart';

class _FailingSystemRepository implements SystemRepository {
  @override
  Future<void> requestManualVentilation() async {
    throw Exception('Firebase connection error');
  }

  @override
  Stream<SystemState> watchSystemState() => const Stream.empty();

  @override
  Stream<Object?> watchRawSystem() => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> watchConfig() => const Stream.empty();

  @override
  Stream<bool> watchConnected() => Stream.value(true);
}

void main() {
  group('ManualVentilationNotifier', () {
    test('initial state has isPending: false and no error', () async {
      final streamController = StreamController<SystemState>.broadcast();
      addTearDown(streamController.close);

      final container = ProviderContainer(
        overrides: [
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          systemStateProvider.overrideWith((_) => streamController.stream),
        ],
      );
      addTearDown(container.dispose);

      container.listen(manualVentilationProvider, (_, _) {});

      streamController.add(
        const SystemState(tier: Tier.safe, manualToggle: false, fanOn: false),
      );
      await pumpEventQueue();

      final state = container.read(manualVentilationProvider);
      expect(state.isPending, isFalse);
      expect(state.errorMessage, isNull);
    });

    test(
      'debounces double taps: second call while pending is ignored',
      () async {
        final streamController = StreamController<SystemState>.broadcast();
        addTearDown(streamController.close);

        final fakeRepo = FakeSystemRepository(
          initialTemperature: 34.0, // Medium tier
        );
        final container = ProviderContainer(
          overrides: [
            systemRepositoryProvider.overrideWithValue(fakeRepo),
            systemStateProvider.overrideWith((_) => streamController.stream),
          ],
        );
        addTearDown(container.dispose);

        container.listen(manualVentilationProvider, (_, _) {});
        streamController.add(
          const SystemState(
            tier: Tier.medium,
            manualToggle: false,
            fanOn: false,
          ),
        );
        await pumpEventQueue();

        final notifier = container.read(manualVentilationProvider.notifier);

        // Start first call
        final future1 = notifier.startVentilation();
        expect(container.read(manualVentilationProvider).isPending, isTrue);

        // Second call while pending is debounced and ignored
        final future2 = notifier.startVentilation();
        expect(container.read(manualVentilationProvider).isPending, isTrue);

        await future1;
        await future2;
      },
    );

    test(
      'write failure clears isPending, sets errorMessage, and throws',
      () async {
        final streamController = StreamController<SystemState>.broadcast();
        addTearDown(streamController.close);

        final container = ProviderContainer(
          overrides: [
            systemRepositoryProvider.overrideWithValue(
              _FailingSystemRepository(),
            ),
            systemStateProvider.overrideWith((_) => streamController.stream),
          ],
        );
        addTearDown(container.dispose);

        container.listen(manualVentilationProvider, (_, _) {});
        streamController.add(
          const SystemState(tier: Tier.medium, manualToggle: false),
        );
        await pumpEventQueue();

        final notifier = container.read(manualVentilationProvider.notifier);

        expect(notifier.startVentilation(), throwsException);
        await pumpEventQueue();

        final state = container.read(manualVentilationProvider);
        expect(state.isPending, isFalse);
        expect(
          state.errorMessage,
          equals('Failed to start ventilation. Check connection.'),
        );
      },
    );

    test('stream confirming manualToggle clears isPending and records observedRunStartedAt', () async {
      final streamController = StreamController<SystemState>.broadcast();
      addTearDown(streamController.close);

      final fakeRepo = FakeSystemRepository(initialTemperature: 34.0);
      final container = ProviderContainer(
        overrides: [
          systemRepositoryProvider.overrideWithValue(fakeRepo),
          systemStateProvider.overrideWith((_) => streamController.stream),
        ],
      );
      addTearDown(container.dispose);

      container.listen(manualVentilationProvider, (_, _) {});
      streamController.add(
        const SystemState(tier: Tier.medium, manualToggle: false),
      );
      await pumpEventQueue();

      final notifier = container.read(manualVentilationProvider.notifier);
      await notifier.startVentilation();

      expect(container.read(manualVentilationProvider).isPending, isTrue);

      // Stream confirms!
      streamController.add(
        const SystemState(tier: Tier.medium, manualToggle: true, fanOn: true),
      );
      await pumpEventQueue();

      final state = container.read(manualVentilationProvider);
      expect(state.isPending, isFalse);
      expect(state.observedRunStartedAt, isNotNull);
      expect(state.errorMessage, isNull);
    });

    test(
      'dangerObservedSinceSafe turns true in Danger and resets in Safe',
      () async {
        final streamController = StreamController<SystemState>.broadcast();
        addTearDown(streamController.close);

        final container = ProviderContainer(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith((_) => streamController.stream),
          ],
        );
        addTearDown(container.dispose);

        container.listen(manualVentilationProvider, (_, _) {});

        // Initially safe
        streamController.add(const SystemState(tier: Tier.safe));
        await pumpEventQueue();
        expect(
          container.read(manualVentilationProvider).dangerObservedSinceSafe,
          isFalse,
        );

        // Transitions to Danger
        streamController.add(const SystemState(tier: Tier.danger));
        await pumpEventQueue();
        expect(
          container.read(manualVentilationProvider).dangerObservedSinceSafe,
          isTrue,
        );

        // Transitions down to Medium: latch flag stays true
        streamController.add(const SystemState(tier: Tier.medium, fanOn: true));
        await pumpEventQueue();
        expect(
          container.read(manualVentilationProvider).dangerObservedSinceSafe,
          isTrue,
        );

        // Returns to Safe: resets latch flag
        streamController.add(const SystemState(tier: Tier.safe));
        await pumpEventQueue();
        expect(
          container.read(manualVentilationProvider).dangerObservedSinceSafe,
          isFalse,
        );
      },
    );

    test(
      'timeout (5s without confirmation) shows device did not start fan error',
      () async {
        final streamController = StreamController<SystemState>.broadcast();
        addTearDown(streamController.close);

        var fakeTime = DateTime(2026, 11, 12, 10, 0);
        final notifier = ManualVentilationNotifier(clock: () => fakeTime);

        final container = ProviderContainer(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith((_) => streamController.stream),
            manualVentilationProvider.overrideWith(() => notifier),
          ],
        );
        addTearDown(container.dispose);

        container.listen(manualVentilationProvider, (_, _) {});
        streamController.add(
          const SystemState(tier: Tier.medium, manualToggle: false),
        );
        await pumpEventQueue();

        await notifier.startVentilation();
        expect(container.read(manualVentilationProvider).isPending, isTrue);

        // Wait 5 seconds for timeout timer to fire
        await Future<void>.delayed(const Duration(milliseconds: 5100));

        final state = container.read(manualVentilationProvider);
        expect(state.isPending, isFalse);
        expect(
          state.errorMessage,
          equals(
            "The device didn't start the fan. The room may no longer be in the stuffy range.",
          ),
        );
      },
    );
  });
}
