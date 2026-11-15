import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/strings.dart';
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

    test('no tier notice emitted for the first value after launch', () {
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

    test(
      'emits offline notice on first launch when resolved status is offline',
      () {
        final container = ProviderContainer(
          overrides: [clockProvider.overrideWithValue(testClock)],
        );
        addTearDown(container.dispose);

        final notifier = container.read(inAppNoticeProvider.notifier);

        // First resolved device status is offline
        notifier.handleDeviceStatus(
          const DeviceStatus(
            status: DeviceOnlineStatus.offline,
            formattedTime: '09:40',
          ),
        );

        final notice = container.read(inAppNoticeProvider);
        expect(notice, isNotNull);
        expect(notice!.type, equals(NoticeType.deviceOffline));
        expect(notice.message, equals('Device offline. Last data at 09:40'));
      },
    );

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

    test('device offline and online transition notices and cooldown', () {
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

      // Device goes offline at 10:00
      notifier.handleDeviceStatus(
        const DeviceStatus(
          status: DeviceOnlineStatus.offline,
          formattedTime: '09:40',
        ),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.deviceOffline),
      );
      expect(
        container.read(inAppNoticeProvider)?.message,
        equals('Device offline. Last data at 09:40'),
      );

      // Clear/dismiss notice
      notifier.dismiss();
      expect(container.read(inAppNoticeProvider), isNull);

      // Dismiss online notice
      notifier.dismiss();

      // A second offline event inside the 10-minute cooldown shows nothing
      currentTime = DateTime(2026, 11, 12, 10, 5, 0); // 5 min elapsed
      notifier.handleDeviceStatus(
        const DeviceStatus(
          status: DeviceOnlineStatus.offline,
          formattedTime: '09:45',
        ),
      );
      expect(container.read(inAppNoticeProvider), isNull);

      // Device transitions back to online at 10:10
      currentTime = DateTime(2026, 11, 12, 10, 10, 0);
      notifier.handleDeviceStatus(
        const DeviceStatus(status: DeviceOnlineStatus.online),
      );
      notifier.dismiss();

      // After 10-minute cooldown (10:11), transition to offline fires again
      currentTime = DateTime(2026, 11, 12, 10, 11, 0);
      notifier.handleDeviceStatus(
        const DeviceStatus(
          status: DeviceOnlineStatus.offline,
          formattedTime: '09:50',
        ),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.deviceOffline),
      );

      // Return online after its 10-minute cooldown (10:21 > 10:10)
      currentTime = DateTime(2026, 11, 12, 10, 21, 0);
      notifier.handleDeviceStatus(
        const DeviceStatus(status: DeviceOnlineStatus.online),
      );
      expect(
        container.read(inAppNoticeProvider)?.type,
        equals(NoticeType.deviceOnline),
      );
      expect(
        container.read(inAppNoticeProvider)?.message,
        equals(AppStrings.deviceReconnected),
      );
    });
  });

  group('InAppNoticeBanner widget', () {
    testWidgets('renders Caution notice and dismisses', (tester) async {
      final container = ProviderContainer();

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

      await tester.tap(find.byTooltip('Dismiss notice'));
      await tester.pumpAndSettle();

      expect(
        find.text('Room is getting stuffy. Manual ventilation is available.'),
        findsNothing,
      );
      expect(container.read(inAppNoticeProvider), isNull);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });

    testWidgets('the banner no longer renders offline notices', (tester) async {
      final container = ProviderContainer();

      // Set device offline notice
      container.read(inAppNoticeProvider.notifier).state = InAppNotice(
        type: NoticeType.deviceOffline,
        message: 'Device offline. Last data at 10:00',
        timestamp: DateTime.now(),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: Scaffold(body: InAppNoticeBanner())),
        ),
      );

      // Banner should not render anything for offline
      expect(find.byType(InAppNoticeBanner), findsOneWidget);
      expect(find.text('Device offline. Last data at 10:00'), findsNothing);

      // Set device online notice
      container.read(inAppNoticeProvider.notifier).state = InAppNotice(
        type: NoticeType.deviceOnline,
        message: 'Device reconnected',
        timestamp: DateTime.now(),
      );
      await tester.pump();

      expect(find.text('Device reconnected'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      container.dispose();
    });
  });

  group('Transient offline/online SnackBar', () {
    testWidgets(
      'appears with 5s duration when offline notice emitted and is gone after 5s',
      (tester) async {
        final container = ProviderContainer();

        Widget testConsumerWidget() {
          return Consumer(
            builder: (context, ref, child) {
              ref.listen<InAppNotice?>(inAppNoticeProvider, (previous, next) {
                if (next == null) return;
                if (next.type == NoticeType.deviceOffline ||
                    next.type == NoticeType.deviceOnline) {
                  final messenger = ScaffoldMessenger.of(context);
                  messenger.clearSnackBars();
                  messenger.showSnackBar(
                    SnackBar(
                      behavior: SnackBarBehavior.floating,
                      duration: const Duration(seconds: 5),
                      content: Text(next.message),
                    ),
                  );
                }
              });
              return const Scaffold(
                body: Center(child: Text('App Shell Content')),
              );
            },
          );
        }

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(home: testConsumerWidget()),
          ),
        );

        expect(find.byType(SnackBar), findsNothing);

        // Emit offline notice
        container.read(inAppNoticeProvider.notifier).state = InAppNotice(
          type: NoticeType.deviceOffline,
          message: 'Device offline. Last data at 10:00',
          timestamp: DateTime.now(),
        );

        await tester.pump(); // frame where snackbar is created
        await tester.pump(
          const Duration(milliseconds: 750),
        ); // animation settles

        expect(find.byType(SnackBar), findsOneWidget);
        expect(find.text('Device offline. Last data at 10:00'), findsOneWidget);

        // After 5 seconds of fake time, snackbar is dismissed
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle(); // animation completes

        expect(find.byType(SnackBar), findsNothing);

        await tester.pumpWidget(const SizedBox());
        container.dispose();
      },
    );
  });
}
