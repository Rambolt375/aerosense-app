import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/dashboard/manual_toggle_notifier.dart';
import 'package:aerosense_app/features/dashboard/widgets/fan_card.dart';

class _MockDeviceStatusNotifier extends DeviceStatusNotifier {
  _MockDeviceStatusNotifier(this._initial);
  final DeviceStatus _initial;

  @override
  DeviceStatus build() => _initial;
}

void main() {
  group('FanCard behavior (Phase 6a timed ventilation)', () {
    testWidgets('Header shows Fan off when fan is off', (tester) async {
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
            deviceStatusProvider.overrideWith(
              () => _MockDeviceStatusNotifier(
                const DeviceStatus(status: DeviceOnlineStatus.online),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      expect(find.text('Fan off'), findsOneWidget);
      expect(find.text('Fan Off'), findsNothing);
    });

    testWidgets('Header shows Fan on when fan is on', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.danger,
                  manualToggle: false,
                  fanOn: true,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
            deviceStatusProvider.overrideWith(
              () => _MockDeviceStatusNotifier(
                const DeviceStatus(status: DeviceOnlineStatus.online),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      expect(find.text('Fan on'), findsOneWidget);
      expect(find.text('Fan On'), findsNothing);
    });

    testWidgets('Safe tier: button disabled, Safe helper text', (tester) async {
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
            deviceStatusProvider.overrideWith(
              () => _MockDeviceStatusNotifier(
                const DeviceStatus(status: DeviceOnlineStatus.online),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final buttonFinder = find.byType(FilledButton);
      expect(buttonFinder, findsOneWidget);
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull); // Disabled

      expect(
        find.text(
          'The fan stays off while the room is safe. Manual ventilation is available when the room gets stuffy.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'Caution idle with known duration: button enabled with duration and stuffy helper',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              systemRepositoryProvider.overrideWithValue(
                FakeSystemRepository(),
              ),
              systemStateProvider.overrideWith(
                (_) => Stream.value(
                  const SystemState(
                    tier: Tier.medium,
                    manualToggle: false,
                    fanOn: false,
                  ),
                ),
              ),
              configStreamProvider.overrideWith(
                (_) => Stream.value({'manualDurationSec': 300}),
              ),
              connectedProvider.overrideWith((_) => Stream.value(true)),
              deviceStatusProvider.overrideWith(
                () => _MockDeviceStatusNotifier(
                  const DeviceStatus(status: DeviceOnlineStatus.online),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: FanCard())),
          ),
        );
        await tester.pump();

        final buttonFinder = find.byType(FilledButton);
        expect(buttonFinder, findsOneWidget);
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(button.onPressed, isNotNull); // Enabled
        expect(find.text('Ventilate for 5 min'), findsOneWidget);

        expect(
          find.text('Room is stuffy. The fan stays off unless you turn it on.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Caution idle with unknown duration: button says Ventilate and fixed time helper',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              systemRepositoryProvider.overrideWithValue(
                FakeSystemRepository(),
              ),
              systemStateProvider.overrideWith(
                (_) => Stream.value(
                  const SystemState(
                    tier: Tier.medium,
                    manualToggle: false,
                    fanOn: false,
                  ),
                ),
              ),
              configStreamProvider.overrideWith((_) => Stream.value(null)),
              connectedProvider.overrideWith((_) => Stream.value(true)),
              deviceStatusProvider.overrideWith(
                () => _MockDeviceStatusNotifier(
                  const DeviceStatus(status: DeviceOnlineStatus.online),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: FanCard())),
          ),
        );
        await tester.pump();

        final buttonFinder = find.byType(FilledButton);
        expect(buttonFinder, findsOneWidget);
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(button.onPressed, isNotNull); // Enabled
        expect(find.text('Ventilate'), findsOneWidget);

        expect(
          find.text('The fan runs for a fixed time set by the device.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Caution running with manualEndsAt: button disabled with countdown',
      (tester) async {
        final futureEnd = DateTime.now().add(
          const Duration(minutes: 4, seconds: 50),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              systemRepositoryProvider.overrideWithValue(
                FakeSystemRepository(),
              ),
              systemStateProvider.overrideWith(
                (_) => Stream.value(
                  SystemState(
                    tier: Tier.medium,
                    manualToggle: true,
                    fanOn: true,
                    manualEndsAt: futureEnd,
                  ),
                ),
              ),
              connectedProvider.overrideWith((_) => Stream.value(true)),
              deviceStatusProvider.overrideWith(
                () => _MockDeviceStatusNotifier(
                  const DeviceStatus(status: DeviceOnlineStatus.online),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: FanCard())),
          ),
        );
        await tester.pump();

        final buttonFinder = find.byType(FilledButton);
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(button.onPressed, isNull); // Disabled while running

        expect(find.textContaining('Fan running,'), findsOneWidget);
        expect(
          find.text('Manual ventilation is on. The fan is running.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'Caution running mid-run (no manualEndsAt, no observation): shows Fan running without countdown',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              systemRepositoryProvider.overrideWithValue(
                FakeSystemRepository(),
              ),
              systemStateProvider.overrideWith(
                (_) => Stream.value(
                  const SystemState(
                    tier: Tier.medium,
                    manualToggle: true,
                    fanOn: true,
                    manualEndsAt: null,
                  ),
                ),
              ),
              connectedProvider.overrideWith((_) => Stream.value(true)),
              deviceStatusProvider.overrideWith(
                () => _MockDeviceStatusNotifier(
                  const DeviceStatus(status: DeviceOnlineStatus.online),
                ),
              ),
            ],
            child: const MaterialApp(home: Scaffold(body: FanCard())),
          ),
        );
        await tester.pump();

        final buttonFinder = find.byType(FilledButton);
        final button = tester.widget<FilledButton>(buttonFinder);
        expect(button.onPressed, isNull);

        expect(find.text('Fan running'), findsOneWidget);
        expect(find.textContaining('left'), findsNothing);
      },
    );

    testWidgets('Danger tier: button disabled, safety override copy', (
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
                  manualToggle: false,
                  fanOn: true,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
            deviceStatusProvider.overrideWith(
              () => _MockDeviceStatusNotifier(
                const DeviceStatus(status: DeviceOnlineStatus.online),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final buttonFinder = find.byType(FilledButton);
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);

      expect(
        find.text(
          'Safety override active. The fan is forced on and manual control is bypassed.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Danger latch: shows "Fan stays on until the room is safe."', (
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
                  fanOn: true,
                ),
              ),
            ),
            manualVentilationProvider.overrideWith(
              () => _MockManualVentilationNotifier(
                const ManualVentilationState(dangerObservedSinceSafe: true),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
            deviceStatusProvider.overrideWith(
              () => _MockDeviceStatusNotifier(
                const DeviceStatus(status: DeviceOnlineStatus.online),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final buttonFinder = find.byType(FilledButton);
      final button = tester.widget<FilledButton>(buttonFinder);
      expect(button.onPressed, isNull);

      // Must have the period per Requirement 8
      expect(find.text('Fan stays on until the room is safe.'), findsOneWidget);
    });

    testWidgets('App Offline: button disabled with offline message', (
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
            connectedProvider.overrideWith((_) => Stream.value(false)),
            deviceStatusProvider.overrideWith(
              () => _MockDeviceStatusNotifier(
                const DeviceStatus(status: DeviceOnlineStatus.online),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final buttonFinder = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

      expect(
        find.text('App is offline. Fan control unavailable.'),
        findsOneWidget,
      );
    });

    testWidgets('Device Offline: button disabled with device offline message', (
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
            deviceStatusProvider.overrideWith(
              () => _MockDeviceStatusNotifier(
                const DeviceStatus(status: DeviceOnlineStatus.offline),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final buttonFinder = find.byType(FilledButton);
      expect(tester.widget<FilledButton>(buttonFinder).onPressed, isNull);

      expect(
        find.text('Device offline. Fan control unavailable.'),
        findsOneWidget,
      );
    });
  });
}

class _MockManualVentilationNotifier extends ManualVentilationNotifier {
  _MockManualVentilationNotifier(this._initial);
  final ManualVentilationState _initial;

  @override
  ManualVentilationState build() => _initial;
}
