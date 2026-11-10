import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/dashboard/widgets/fan_card.dart';

void main() {
  group('FanCard toggle behavior (Phase 5b alignment)', () {
    testWidgets('Safe tier: toggle disabled, correct helper text', (
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

      // Verify switch is disabled in Safe tier
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.onChanged, isNull); // Disabled
      expect(switchWidget.value, isFalse);

      // Verify helper text
      expect(
        find.text(
          'The fan stays off while the room is safe. Manual ventilation is available when the room gets stuffy.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('Medium tier: toggle enabled, prominent helper text when off', (
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
                const DeviceStatus(status: DeviceOnlineStatus.online),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNotNull); // Enabled in Medium
      expect(switchWidget.value, isFalse);

      expect(
        find.text('Room is stuffy. The fan stays off unless you turn it on.'),
        findsOneWidget,
      );
    });

    testWidgets('Medium tier with toggle=true: shows running message', (
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
                  manualToggle: true,
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

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNotNull);
      expect(switchWidget.value, isTrue);

      expect(
        find.text('Manual ventilation is on. The fan is running.'),
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

    testWidgets('App Offline: toggle disabled with app offline message', (
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

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);

      expect(
        find.text('App is offline. Fan control unavailable.'),
        findsOneWidget,
      );
    });

    testWidgets('Device Offline: toggle disabled with device offline message', (
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
                const DeviceStatus(
                  status: DeviceOnlineStatus.offline,
                  formattedTime: '14:20',
                ),
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: FanCard())),
        ),
      );
      await tester.pump();

      final switchWidget = tester.widget<Switch>(find.byType(Switch));
      expect(switchWidget.onChanged, isNull);

      expect(
        find.text('Device offline. Fan control unavailable.'),
        findsOneWidget,
      );
    });
  });
}

class _MockDeviceStatusNotifier extends DeviceStatusNotifier {
  _MockDeviceStatusNotifier(this._initial);

  final DeviceStatus _initial;

  @override
  DeviceStatus build() => _initial;
}
