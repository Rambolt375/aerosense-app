import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/manual_toggle_notifier.dart';

void main() {
  group('ManualToggleNotifier', () {
    test('initial state reflects stream value', () async {
      final streamController = StreamController<SystemState>.broadcast();
      addTearDown(streamController.close);

      final container = ProviderContainer(
        overrides: [
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          systemStateProvider.overrideWith((_) => streamController.stream),
        ],
      );
      addTearDown(container.dispose);

      // Keep an active listener on the notifier
      container.listen(manualToggleProvider, (_, _) {});

      streamController.add(
        const SystemState(tier: Tier.safe, manualToggle: false, fanOn: false),
      );
      await pumpEventQueue();

      final state = container.read(manualToggleProvider);
      expect(state.value, isFalse);
      expect(state.isPending, isFalse);
    });

    test(
      'optimistically updates value and sets isPending: true on setToggle',
      () async {
        final streamController = StreamController<SystemState>.broadcast();
        addTearDown(streamController.close);

        final fakeRepo = FakeSystemRepository();
        final container = ProviderContainer(
          overrides: [
            systemRepositoryProvider.overrideWithValue(fakeRepo),
            systemStateProvider.overrideWith((_) => streamController.stream),
          ],
        );
        addTearDown(container.dispose);

        container.listen(manualToggleProvider, (_, _) {});

        // Initial stream event
        streamController.add(const SystemState(manualToggle: false));
        await pumpEventQueue();

        expect(container.read(manualToggleProvider).value, isFalse);

        // Call setToggle
        final future = container
            .read(manualToggleProvider.notifier)
            .setToggle(true);

        // Optimistic state is updated immediately
        expect(container.read(manualToggleProvider).value, isTrue);
        expect(container.read(manualToggleProvider).isPending, isTrue);

        await future;

        // Stream confirms the value
        streamController.add(const SystemState(manualToggle: true));
        await pumpEventQueue();

        expect(container.read(manualToggleProvider).value, isTrue);
        expect(container.read(manualToggleProvider).isPending, isFalse);
      },
    );

    test('ignores stream value while write is pending', () async {
      final streamController = StreamController<SystemState>.broadcast();
      addTearDown(streamController.close);

      final fakeRepo = FakeSystemRepository();
      final container = ProviderContainer(
        overrides: [
          systemRepositoryProvider.overrideWithValue(fakeRepo),
          systemStateProvider.overrideWith((_) => streamController.stream),
        ],
      );
      addTearDown(container.dispose);

      container.listen(manualToggleProvider, (_, _) {});

      streamController.add(const SystemState(manualToggle: false));
      await pumpEventQueue();

      await container.read(manualToggleProvider.notifier).setToggle(true);

      // Stream still emits false (lag from network/firmware)
      streamController.add(const SystemState(manualToggle: false));
      await pumpEventQueue();

      // Should keep pending value: true
      expect(container.read(manualToggleProvider).value, isTrue);
      expect(container.read(manualToggleProvider).isPending, isTrue);
    });

    test('reverts immediately if repository write throws', () async {
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

      container.listen(manualToggleProvider, (_, _) {});

      streamController.add(const SystemState(manualToggle: false));
      await pumpEventQueue();

      await expectLater(
        container.read(manualToggleProvider.notifier).setToggle(true),
        throwsA(isA<Exception>()),
      );

      // Reverted to stream value, isPending is false
      expect(container.read(manualToggleProvider).value, isFalse);
      expect(container.read(manualToggleProvider).isPending, isFalse);
    });

    testWidgets(
      'timeout reconciles to stream value if stream does not confirm',
      (tester) async {
        final streamController = StreamController<SystemState>.broadcast();
        addTearDown(streamController.close);

        final fakeRepo = FakeSystemRepository();
        late final ProviderContainer container;

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container = ProviderContainer(
              overrides: [
                systemRepositoryProvider.overrideWithValue(fakeRepo),
                systemStateProvider.overrideWith(
                  (_) => streamController.stream,
                ),
              ],
            ),
            child: const SizedBox.shrink(),
          ),
        );
        addTearDown(container.dispose);

        container.listen(manualToggleProvider, (_, _) {});

        streamController.add(const SystemState(manualToggle: false));
        await tester.pump();

        await container.read(manualToggleProvider.notifier).setToggle(true);
        expect(container.read(manualToggleProvider).value, isTrue);
        expect(container.read(manualToggleProvider).isPending, isTrue);

        // Advance clock by 6 seconds (beyond 5s timeout)
        await tester.pump(const Duration(seconds: 6));

        // Reconciled to stream value (false)
        expect(container.read(manualToggleProvider).value, isFalse);
        expect(container.read(manualToggleProvider).isPending, isFalse);
      },
    );
  });
}

class _FailingSystemRepository extends FakeSystemRepository {
  @override
  Future<void> setManualToggle(bool value) async {
    throw Exception('Network error');
  }
}
