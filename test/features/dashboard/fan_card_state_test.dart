import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/dashboard/fan_card_state.dart';

void main() {
  group('FanCardUiState derivation (pure table-driven)', () {
    test('table of state transitions', () {
      final cases =
          <
            ({
              String description,
              Tier tier,
              bool fanOn,
              bool manualToggle,
              bool appConnected,
              bool deviceOffline,
              bool isPending,
              bool dangerLatchActive,
              bool isWaitingForDevice,
              FanCardUiState expected,
            })
          >[
            // App offline takes highest priority
            (
              description: 'App offline overrides everything',
              tier: Tier.medium,
              fanOn: true,
              manualToggle: true,
              appConnected: false,
              deviceOffline: false,
              isPending: false,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.appOffline,
            ),
            // Device offline takes next priority
            (
              description: 'Device offline overrides tier states',
              tier: Tier.medium,
              fanOn: true,
              manualToggle: true,
              appConnected: true,
              deviceOffline: true,
              isPending: false,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.deviceOffline,
            ),
            // Danger tier
            (
              description: 'Danger tier is safety override',
              tier: Tier.danger,
              fanOn: true,
              manualToggle: false,
              appConnected: true,
              deviceOffline: false,
              isPending: false,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.danger,
            ),
            (
              description: 'Danger tier overrides pending write',
              tier: Tier.danger,
              fanOn: true,
              manualToggle: false,
              appConnected: true,
              deviceOffline: false,
              isPending: true,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.danger,
            ),
            // Safe tier
            (
              description: 'Safe tier keeps fan off and disabled',
              tier: Tier.safe,
              fanOn: false,
              manualToggle: false,
              appConnected: true,
              deviceOffline: false,
              isPending: false,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.safe,
            ),
            // Danger Latch in Medium
            (
              description: 'Danger latch active in Medium tier',
              tier: Tier.medium,
              fanOn: true,
              manualToggle: false,
              appConnected: true,
              deviceOffline: false,
              isPending: false,
              dangerLatchActive: true,
              isWaitingForDevice: false,
              expected: FanCardUiState.dangerLatched,
            ),
            // Waiting for device (> 30s past end time)
            (
              description: 'Waiting for device when manualToggle stays true > 30s past end',
              tier: Tier.medium,
              fanOn: true,
              manualToggle: true,
              appConnected: true,
              deviceOffline: false,
              isPending: false,
              dangerLatchActive: false,
              isWaitingForDevice: true,
              expected: FanCardUiState.waitingForDevice,
            ),
            // Running (fanOn + manualToggle)
            (
              description: 'Running when fanOn and manualToggle are both true',
              tier: Tier.medium,
              fanOn: true,
              manualToggle: true,
              appConnected: true,
              deviceOffline: false,
              isPending: false,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.running,
            ),
            // Running overrides pending flag
            (
              description: 'Running state overrides pending write flag',
              tier: Tier.medium,
              fanOn: true,
              manualToggle: true,
              appConnected: true,
              deviceOffline: false,
              isPending: true,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.running,
            ),
            // Pending state (request sent, waiting for device echo)
            (
              description: 'Pending state when request is in flight',
              tier: Tier.medium,
              fanOn: false,
              manualToggle: false,
              appConnected: true,
              deviceOffline: false,
              isPending: true,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.pending,
            ),
            // Caution Idle
            (
              description: 'Idle state when room is stuffy and fan is off',
              tier: Tier.medium,
              fanOn: false,
              manualToggle: false,
              appConnected: true,
              deviceOffline: false,
              isPending: false,
              dangerLatchActive: false,
              isWaitingForDevice: false,
              expected: FanCardUiState.idle,
            ),
          ];

      for (final c in cases) {
        final result = deriveFanCardUiState(
          tier: c.tier,
          fanOn: c.fanOn,
          manualToggle: c.manualToggle,
          appConnected: c.appConnected,
          deviceOffline: c.deviceOffline,
          isPending: c.isPending,
          dangerLatchActive: c.dangerLatchActive,
          isWaitingForDevice: c.isWaitingForDevice,
        );
        expect(result, equals(c.expected), reason: c.description);
      }
    });
  });

  group('Danger latch evaluation logic', () {
    test('does not latch if tier is not medium or fan is off or manualToggle is true', () {
      expect(
        evaluateDangerLatch(
          tier: Tier.safe,
          fanOn: true,
          manualToggle: false,
          dangerObservedSinceSafe: true,
          unlatchedCautionHeldDuration: const Duration(seconds: 10),
        ),
        isFalse,
      );
      expect(
        evaluateDangerLatch(
          tier: Tier.medium,
          fanOn: false,
          manualToggle: false,
          dangerObservedSinceSafe: true,
          unlatchedCautionHeldDuration: const Duration(seconds: 10),
        ),
        isFalse,
      );
      expect(
        evaluateDangerLatch(
          tier: Tier.medium,
          fanOn: true,
          manualToggle: true,
          dangerObservedSinceSafe: true,
          unlatchedCautionHeldDuration: const Duration(seconds: 10),
        ),
        isFalse,
      );
    });

    test('latches immediately if danger was observed since last safe', () {
      expect(
        evaluateDangerLatch(
          tier: Tier.medium,
          fanOn: true,
          manualToggle: false,
          dangerObservedSinceSafe: true,
          unlatchedCautionHeldDuration: Duration.zero,
        ),
        isTrue,
      );
    });

    test(
      'does not latch on normal run spin-down (< 6 s without observed danger)',
      () {
        expect(
          evaluateDangerLatch(
            tier: Tier.medium,
            fanOn: true,
            manualToggle: false,
            dangerObservedSinceSafe: false,
            unlatchedCautionHeldDuration: const Duration(seconds: 2),
          ),
          isFalse,
        );
      },
    );

    test('latches if held >= 6 s without observed danger (e.g. app opened mid-latch)', () {
      expect(
        evaluateDangerLatch(
          tier: Tier.medium,
          fanOn: true,
          manualToggle: false,
          dangerObservedSinceSafe: false,
          unlatchedCautionHeldDuration: const Duration(seconds: 6),
        ),
        isTrue,
      );
    });
  });

  group('Clamping manualEndsAt', () {
    final now = DateTime(2026, 11, 12, 10, 0);

    test('returns null if manualEndsAt is null', () {
      expect(
        clampManualEndsAt(
          manualEndsAt: null,
          now: now,
          knownDuration: const Duration(minutes: 5),
        ),
        isNull,
      );
    });

    test('returns null if remaining < 0', () {
      final past = now.subtract(const Duration(seconds: 5));
      expect(
        clampManualEndsAt(
          manualEndsAt: past,
          now: now,
          knownDuration: const Duration(minutes: 5),
        ),
        isNull,
      );
    });

    test('returns null if remaining > 2 * known duration', () {
      final futureTooFar = now.add(const Duration(minutes: 11)); // > 2 * 5 min
      expect(
        clampManualEndsAt(
          manualEndsAt: futureTooFar,
          now: now,
          knownDuration: const Duration(minutes: 5),
        ),
        isNull,
      );
    });

    test('returns valid manualEndsAt within [0, 2 * knownDuration]', () {
      final valid = now.add(const Duration(minutes: 4, seconds: 50));
      expect(
        clampManualEndsAt(
          manualEndsAt: valid,
          now: now,
          knownDuration: const Duration(minutes: 5),
        ),
        equals(valid),
      );
    });
  });

  group('evaluateWaitingForDevice', () {
    final endsAt = DateTime(2026, 11, 12, 10, 5);

    test('false if manualToggle is false or endsAt is null', () {
      expect(
        evaluateWaitingForDevice(
          manualToggle: false,
          endsAt: endsAt,
          now: endsAt.add(const Duration(seconds: 35)),
        ),
        isFalse,
      );
      expect(
        evaluateWaitingForDevice(
          manualToggle: true,
          endsAt: null,
          now: endsAt.add(const Duration(seconds: 35)),
        ),
        isFalse,
      );
    });

    test('false within 30s of endsAt', () {
      expect(
        evaluateWaitingForDevice(
          manualToggle: true,
          endsAt: endsAt,
          now: endsAt.add(const Duration(seconds: 29)),
        ),
        isFalse,
      );
    });

    test('true when > 30s past endsAt', () {
      expect(
        evaluateWaitingForDevice(
          manualToggle: true,
          endsAt: endsAt,
          now: endsAt.add(const Duration(seconds: 31)),
        ),
        isTrue,
      );
    });
  });

  group('Button labels and helper texts', () {
    test('idle with known duration shows minutes and stuffy helper', () {
      expect(
        fanButtonLabel(
          state: FanCardUiState.idle,
          manualDuration: const Duration(minutes: 5),
        ),
        equals('Ventilate for 5 min'),
      );
      expect(
        fanCardHelperText(
          state: FanCardUiState.idle,
          manualDuration: const Duration(minutes: 5),
        ),
        equals('Room is stuffy. The fan stays off unless you turn it on.'),
      );
    });

    test(
      'idle with unknown duration shows Ventilate and fixed time helper',
      () {
        expect(
          fanButtonLabel(state: FanCardUiState.idle, manualDuration: null),
          equals('Ventilate'),
        );
        expect(
          fanCardHelperText(state: FanCardUiState.idle, manualDuration: null),
          equals('The fan runs for a fixed time set by the device.'),
        );
      },
    );

    test('running with countdown shows remaining M:SS', () {
      expect(
        fanButtonLabel(
          state: FanCardUiState.running,
          remainingTime: const Duration(minutes: 4, seconds: 58),
        ),
        equals('Fan running, 4:58 left'),
      );
      expect(
        fanButtonLabel(
          state: FanCardUiState.running,
          remainingTime: const Duration(seconds: 42),
        ),
        equals('Fan running, 0:42 left'),
      );
      expect(
        fanCardHelperText(state: FanCardUiState.running),
        equals('Manual ventilation is on. The fan is running.'),
      );
    });

    test('running without countdown shows Fan running', () {
      expect(
        fanButtonLabel(state: FanCardUiState.running, remainingTime: null),
        equals('Fan running'),
      );
    });

    test('danger latch text ends with a period', () {
      expect(
        fanCardHelperText(state: FanCardUiState.dangerLatched),
        equals('Fan stays on until the room is safe.'),
      );
    });

    test('waitingForDevice shows Waiting for the device... and helper', () {
      expect(
        fanButtonLabel(state: FanCardUiState.waitingForDevice),
        equals('Waiting for the device...'),
      );
      expect(
        fanCardHelperText(state: FanCardUiState.waitingForDevice),
        equals('Waiting for the device to turn off the fan.'),
      );
    });

    test('isFanButtonEnabled only true for idle state', () {
      for (final s in FanCardUiState.values) {
        if (s == FanCardUiState.idle) {
          expect(isFanButtonEnabled(s), isTrue);
        } else {
          expect(isFanButtonEnabled(s), isFalse);
        }
      }
    });
  });
}
