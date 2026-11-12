import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/notices/in_app_notice_notifier.dart';
import 'package:aerosense_app/features/notices/widgets/in_app_notice_banner.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('InAppNoticeNotifier logic', () {
    late DateTime currentTime;

    DateTime testClock() => currentTime;

    setUp(() {
      currentTime = DateTime(2026, 11, 12, 10, 0, 0);
    });

    test('no notice emitted for the first value after launch', () {
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(testClock)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inAppNoticeProvider.notifier);

      // First sample is Caution
      notifier.handleSystemState(
        const SystemState(
          temperature: 34.0,
          humidity: 50.0,
          airQuality: 1500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'CAUTION',
          tier: Tier.medium,
        ),
      );

      expect(container.read(inAppNoticeProvider), isNull);
    });

    test('emits Caution notice when transitioning into Medium', () {
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(testClock)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inAppNoticeProvider.notifier);

      // Initial baseline: Safe
      notifier.handleSystemState(
        const SystemState(
          temperature: 25.0,
          humidity: 50.0,
          airQuality: 500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );
      expect(container.read(inAppNoticeProvider), isNull);

      // Transition to Medium
      notifier.handleSystemState(
        const SystemState(
          temperature: 34.0,
          humidity: 50.0,
          airQuality: 1500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'CAUTION',
          tier: Tier.medium,
        ),
      );

      final notice = container.read(inAppNoticeProvider);
      expect(notice, isNotNull);
      expect(notice!.type, equals(NoticeType.caution));
      expect(notice.tier, equals(Tier.medium));
    });

    test('emits Danger notice and auto-clears when returning to Safe', () {
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(testClock)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inAppNoticeProvider.notifier);

      // Initial baseline: Safe
      notifier.handleSystemState(
        const SystemState(
          temperature: 25.0,
          humidity: 50.0,
          airQuality: 500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );

      // Transition to Danger
      notifier.handleSystemState(
        const SystemState(
          temperature: 37.0,
          humidity: 50.0,
          airQuality: 2200.0,
          fanOn: true,
          manualToggle: false,
          statusMessage: 'DANGER',
          tier: Tier.danger,
        ),
      );

      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.danger),
      );

      // Return to Safe -> auto clears
      notifier.handleSystemState(
        const SystemState(
          temperature: 24.0,
          humidity: 45.0,
          airQuality: 400.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );

      expect(container.read(inAppNoticeProvider), isNull);
    });

    test('Danger cooldown is 2 min, Caution cooldown is 10 min', () {
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(testClock)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inAppNoticeProvider.notifier);

      // Baseline Safe
      notifier.handleSystemState(
        const SystemState(
          temperature: 25.0,
          humidity: 50.0,
          airQuality: 500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );

      // Caution at 10:00
      notifier.handleSystemState(
        const SystemState(
          temperature: 34.0,
          humidity: 50.0,
          airQuality: 1500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'CAUTION',
          tier: Tier.medium,
        ),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.caution),
      );

      // Dismiss notice
      notifier.dismiss();
      expect(container.read(inAppNoticeProvider), isNull);

      // Transition to Safe then back to Caution at 10:05 (5 min elapsed < 10 min cooldown)
      currentTime = DateTime(2026, 11, 12, 10, 5, 0);
      notifier.handleSystemState(
        const SystemState(
          temperature: 25.0,
          humidity: 50.0,
          airQuality: 500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );
      notifier.handleSystemState(
        const SystemState(
          temperature: 34.0,
          humidity: 50.0,
          airQuality: 1500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'CAUTION',
          tier: Tier.medium,
        ),
      );
      // Suppressed because 10 min hasn't elapsed
      expect(container.read(inAppNoticeProvider), isNull);

      // Now at 10:11 (11 min elapsed > 10 min cooldown)
      currentTime = DateTime(2026, 11, 12, 10, 11, 0);
      notifier.handleSystemState(
        const SystemState(
          temperature: 25.0,
          humidity: 50.0,
          airQuality: 500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );
      notifier.handleSystemState(
        const SystemState(
          temperature: 34.0,
          humidity: 50.0,
          airQuality: 1500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'CAUTION',
          tier: Tier.medium,
        ),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.caution),
      );

      // Test Danger 2 min cooldown:
      // Transition to Danger at 10:12
      currentTime = DateTime(2026, 11, 12, 10, 12, 0);
      notifier.handleSystemState(
        const SystemState(
          temperature: 37.0,
          humidity: 50.0,
          airQuality: 2200.0,
          fanOn: true,
          manualToggle: false,
          statusMessage: 'DANGER',
          tier: Tier.danger,
        ),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.danger),
      );

      // Dismiss Danger
      notifier.dismiss();

      // Return to Safe and back to Danger at 10:13 (1 min < 2 min cooldown)
      currentTime = DateTime(2026, 11, 12, 10, 13, 0);
      notifier.handleSystemState(
        const SystemState(
          temperature: 25.0,
          humidity: 50.0,
          airQuality: 500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );
      notifier.handleSystemState(
        const SystemState(
          temperature: 37.0,
          humidity: 50.0,
          airQuality: 2200.0,
          fanOn: true,
          manualToggle: false,
          statusMessage: 'DANGER',
          tier: Tier.danger,
        ),
      );
      expect(container.read(inAppNoticeProvider), isNull); // suppressed!

      // At 10:14:30 (> 2 min cooldown)
      currentTime = DateTime(2026, 11, 12, 10, 14, 30);
      notifier.handleSystemState(
        const SystemState(
          temperature: 25.0,
          humidity: 50.0,
          airQuality: 500.0,
          fanOn: false,
          manualToggle: false,
          statusMessage: 'SAFE',
          tier: Tier.safe,
        ),
      );
      notifier.handleSystemState(
        const SystemState(
          temperature: 37.0,
          humidity: 50.0,
          airQuality: 2200.0,
          fanOn: true,
          manualToggle: false,
          statusMessage: 'DANGER',
          tier: Tier.danger,
        ),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.danger),
      );
    });

    test('device offline and online transition notices', () {
      final container = ProviderContainer(
        overrides: [clockProvider.overrideWithValue(testClock)],
      );
      addTearDown(container.dispose);

      final notifier = container.read(inAppNoticeProvider.notifier);

      // Baseline: online
      notifier.handleDeviceStatus(
        const DeviceStatus(status: DeviceOnlineStatus.online),
      );
      expect(container.read(inAppNoticeProvider), isNull);

      // Device goes offline
      notifier.handleDeviceStatus(
        const DeviceStatus(status: DeviceOnlineStatus.offline),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.deviceOffline),
      );

      // Return online at 10:05 (different type, so it fires)
      currentTime = DateTime(2026, 11, 12, 10, 5, 0);
      notifier.handleDeviceStatus(
        const DeviceStatus(status: DeviceOnlineStatus.online),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.deviceOnline),
      );
    });
  });

  group('InAppNoticeBanner widget', () {
    testWidgets(
      'renders notice message, close icon with tooltip, and dismisses',
      (tester) async {
        final container = ProviderContainer();

        // Set active notice
        container.read(inAppNoticeProvider.notifier).state = InAppNotice(
          type: NoticeType.caution,
          message: 'Room is getting stuffy. Manual ventilation is available.',
          timestamp: DateTime.now(),
          tier: Tier.medium,
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: InAppNoticeBanner())),
          ),
        );

        expect(
          find.text('Room is getting stuffy. Manual ventilation is available.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.close), findsOneWidget);
        expect(find.byTooltip('Dismiss notice'), findsOneWidget);

        // Tap dismiss
        await tester.tap(find.byTooltip('Dismiss notice'));
        await tester.pumpAndSettle();

        expect(
          find.text('Room is getting stuffy. Manual ventilation is available.'),
          findsNothing,
        );
        expect(container.read(inAppNoticeProvider), isNull);

        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  });
}
