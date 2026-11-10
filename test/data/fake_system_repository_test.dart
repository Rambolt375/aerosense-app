import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';

void main() {
  group('FakeSystemRepository - Firmware Tier & Safety Logic', () {
    late FakeSystemRepository repo;

    setUp(() {
      repo = FakeSystemRepository(
        tickInterval: const Duration(milliseconds: 20),
        random: math.Random(123),
        clock: () => DateTime(2026, 11, 10, 8, 30),
      );
    });

    tearDown(() {
      repo.dispose();
    });

    test('initial state is Safe, fan is OFF, status is "System Safe"', () {
      expect(repo.currentTier, equals(Tier.safe));
      expect(repo.currentFanOn, isFalse);
      expect(repo.currentStatusMessage, equals('System Safe'));
      expect(repo.rawManualToggle, isNull);
    });

    test(
      'raw snapshot omits manualToggle until first setManualToggle call',
      () async {
        final rawEvents = <Object?>[];
        final sub = repo.watchRawSystem().listen(rawEvents.add);

        // Wait for the initial scheduled event
        await pumpEventQueue();

        expect(rawEvents.isNotEmpty, isTrue);
        final initialRaw = rawEvents.first as Map<String, dynamic>;
        expect(initialRaw.containsKey('manualToggle'), isFalse);
        expect(initialRaw.containsKey('lastSeen'), isFalse);
        expect(initialRaw['fanStatus'], equals('OFF'));
        expect(initialRaw['statusMessage'], equals('System Safe'));

        // Now call setManualToggle(true)
        await repo.setManualToggle(true);
        await pumpEventQueue();

        final updatedRaw = rawEvents.last as Map<String, dynamic>;
        expect(updatedRaw['manualToggle'], isTrue);
        expect(updatedRaw['fanStatus'], equals('ON'));
        expect(
          updatedRaw['statusMessage'],
          equals('SAFE: Fan manually overridden ON.'),
        );

        await sub.cancel();
      },
    );

    test(
      'parsed SystemState defaults manualToggle to false before first write',
      () async {
        final states = <SystemState>[];
        final sub = repo.watchSystemState().listen(states.add);

        await pumpEventQueue();

        expect(states.isNotEmpty, isTrue);
        expect(states.first.manualToggle, isFalse);
        expect(states.first.fanOn, isFalse);
        expect(states.first.tier, equals(Tier.safe));

        await sub.cancel();
      },
    );

    test('Safe tier honors manualToggle ON and OFF', () async {
      await repo.setManualToggle(true);
      expect(repo.currentFanOn, isTrue);
      expect(
        repo.currentStatusMessage,
        equals('SAFE: Fan manually overridden ON.'),
      );

      await repo.setManualToggle(false);
      expect(repo.currentFanOn, isFalse);
      expect(repo.currentStatusMessage, equals('System Safe'));
    });

    test('Medium tier fan is OFF by default; honors manualToggle', () async {
      // Create repo starting in Medium tier via temperature (29 °C)
      final medRepo = FakeSystemRepository(
        initialTemperature: 29.0,
        initialHumidity: 45.0,
        initialAirQuality: 500.0,
      );

      expect(medRepo.currentTier, equals(Tier.medium));
      expect(medRepo.currentFanOn, isFalse);
      expect(
        medRepo.currentStatusMessage,
        equals('MEDIUM: Environment is stuffy. Manual toggle available.'),
      );

      // Turning manual toggle ON activates the fan
      await medRepo.setManualToggle(true);
      expect(medRepo.currentFanOn, isTrue);
      expect(
        medRepo.currentStatusMessage,
        equals('MEDIUM: Fan manually turned ON by user.'),
      );

      // Turning manual toggle OFF stops the fan
      await medRepo.setManualToggle(false);
      expect(medRepo.currentFanOn, isFalse);
      expect(
        medRepo.currentStatusMessage,
        equals('MEDIUM: Environment is stuffy. Manual toggle available.'),
      );

      medRepo.dispose();
    });

    test(
      'Danger tier forces fan ON and ignores manualToggle turning it off',
      () async {
        // Create repo starting in Danger tier via air quality (2200)
        final dangerRepo = FakeSystemRepository(initialAirQuality: 2200.0);

        expect(dangerRepo.currentTier, equals(Tier.danger));
        expect(dangerRepo.currentFanOn, isTrue); // Forced ON!
        expect(
          dangerRepo.currentStatusMessage,
          equals('DANGER: High thresholds breached! Auto-fan activated.'),
        );

        // Trying to turn manual toggle OFF cannot shut down the fan in Danger
        await dangerRepo.setManualToggle(false);
        expect(dangerRepo.currentFanOn, isTrue);
        expect(
          dangerRepo.currentStatusMessage,
          equals('DANGER: High thresholds breached! Auto-fan activated.'),
        );

        dangerRepo.dispose();
      },
    );
  });

  group('FakeSystemRepository - Scripted Scenarios', () {
    test(
      'Kitchen smoke simulation spikes to Danger, holds, and recovers',
      () async {
        final repo = FakeSystemRepository(
          tickInterval: const Duration(milliseconds: 10),
          clock: () => DateTime(2026, 11, 10, 8, 30),
        );

        final states = <SystemState>[];
        final sub = repo.watchSystemState().listen(states.add);
        await pumpEventQueue();

        // Trigger smoke scenario
        repo.simulateKitchenSmoke();
        expect(repo.currentScenario, equals(DemoScenario.smoke));
        expect(
          repo.currentAirQuality,
          greaterThanOrEqualTo(Thresholds.airQualityDangerMin),
        );
        expect(repo.currentTier, equals(Tier.danger));
        expect(repo.currentFanOn, isTrue);

        // Advance through ticks to watch recovery
        // Phase 0: 3 ticks Danger
        // Phase 1: 3 ticks Medium (1850)
        // Phase 2: 3 ticks Medium (1200)
        // Phase 3: return to baseline Safe
        await Future<void>.delayed(const Duration(milliseconds: 150));

        expect(repo.currentScenario, equals(DemoScenario.none));
        expect(
          repo.currentAirQuality,
          closeTo(repo.currentBaselineAirQuality, 30.0),
        );
        expect(repo.currentTier, equals(Tier.safe));
        expect(repo.currentFanOn, isFalse);

        await sub.cancel();
        repo.dispose();
      },
    );

    test('Heat spike simulation ramps +0.5 C per tick to 33 C, holds, and recovers', () async {
      final repo = FakeSystemRepository(
        tickInterval: const Duration(milliseconds: 10),
        clock: () => DateTime(2026, 11, 10, 8, 30),
        initialTemperature:
            31.0, // Start close to Danger threshold (32) for fast test
      );

      final states = <SystemState>[];
      final sub = repo.watchSystemState().listen(states.add);
      await pumpEventQueue();

      repo.simulateHeatSpike();
      expect(repo.currentScenario, equals(DemoScenario.heat));

      // Advance ticks so it ramps to 33 C, holds, and recovers
      // From 31.5 to 33.0 is 3 ticks (30ms), hold 3 ticks (30ms), ramp down to baseline (170ms)
      await Future<void>.delayed(const Duration(milliseconds: 450));

      expect(repo.currentScenario, equals(DemoScenario.none));
      expect(repo.currentTemperature, closeTo(repo.currentBaselineTemp, 0.5));
      expect(repo.currentTier, equals(Tier.safe));

      await sub.cancel();
      repo.dispose();
    });

    test('resetToBaseline cancels active scenarios immediately', () async {
      final repo = FakeSystemRepository(
        tickInterval: const Duration(milliseconds: 10),
        clock: () => DateTime(2026, 11, 10, 8, 30),
      );

      final sub = repo.watchSystemState().listen((_) {});
      await pumpEventQueue();

      repo.simulateKitchenSmoke();
      expect(repo.currentScenario, equals(DemoScenario.smoke));
      expect(repo.currentTier, equals(Tier.danger));

      repo.resetToBaseline();
      expect(repo.currentScenario, equals(DemoScenario.none));
      expect(repo.currentAirQuality, equals(repo.currentBaselineAirQuality));
      expect(repo.currentTier, equals(Tier.safe));
      expect(repo.currentFanOn, isFalse);

      await sub.cancel();
      repo.dispose();
    });
  });

  group('FakeSystemRepository - Timers and Resource Management', () {
    test(
      'timer starts on first listen and cancels when all subscriptions cancel',
      () async {
        final repo = FakeSystemRepository(
          tickInterval: const Duration(milliseconds: 20),
        );

        // Initially no listeners -> no active timer
        expect(repo.hasActiveTimers, isFalse);

        // Add listener to state
        final sub1 = repo.watchSystemState().listen((_) {});
        await pumpEventQueue();
        expect(repo.hasActiveTimers, isTrue);

        // Add listener to raw
        final sub2 = repo.watchRawSystem().listen((_) {});
        await pumpEventQueue();
        expect(repo.hasActiveTimers, isTrue);

        // Cancel first listener -> timer still active for sub2
        await sub1.cancel();
        expect(repo.hasActiveTimers, isTrue);

        // Cancel second listener -> timer cancels
        await sub2.cancel();
        expect(repo.hasActiveTimers, isFalse);

        repo.dispose();
        expect(repo.hasActiveTimers, isFalse);
      },
    );

    test('dispose cancels all timers and marks repository disposed', () async {
      final repo = FakeSystemRepository(
        tickInterval: const Duration(milliseconds: 20),
      );

      final sub = repo.watchSystemState().listen((_) {});
      await pumpEventQueue();
      expect(repo.hasActiveTimers, isTrue);

      repo.dispose();
      expect(repo.hasActiveTimers, isFalse);

      await sub.cancel();
    });
  });
}
