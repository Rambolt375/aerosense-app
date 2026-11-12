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

    test(
      'initial state is Safe, fan is OFF, status is bare keyword "SAFE"',
      () {
        expect(repo.currentTier, equals(Tier.safe));
        expect(repo.currentFanOn, isFalse);
        expect(repo.currentStatusMessage, equals('SAFE'));
        expect(repo.rawManualToggle, isNull);
      },
    );

    test(
      'raw snapshot omits manualToggle until first request, emits bare SAFE',
      () async {
        final rawEvents = <Object?>[];
        final sub = repo.watchRawSystem().listen(rawEvents.add);

        await pumpEventQueue();

        expect(rawEvents.isNotEmpty, isTrue);
        final initialRaw = rawEvents.first as Map<String, dynamic>;
        expect(initialRaw.containsKey('manualToggle'), isFalse);
        expect(initialRaw.containsKey('lastSeen'), isFalse);
        expect(initialRaw['fanStatus'], equals('OFF'));
        expect(initialRaw['statusMessage'], equals('SAFE'));

        // Calling requestManualVentilation in Safe tier is rejected by firmware
        await repo.requestManualVentilation();
        await pumpEventQueue();

        final updatedRaw = rawEvents.last as Map<String, dynamic>;
        // Firmware resets manualToggle to false on rejection
        expect(updatedRaw['manualToggle'], isFalse);
        expect(updatedRaw['fanStatus'], equals('OFF'));
        expect(updatedRaw['statusMessage'], equals('SAFE'));

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

    test('Safe tier rejects requestManualVentilation, fan stays OFF', () async {
      await repo.requestManualVentilation();
      expect(repo.currentFanOn, isFalse);
      expect(repo.currentStatusMessage, equals('SAFE'));
      expect(repo.rawManualToggle, isFalse);
    });

    test(
      'Medium tier fan is OFF by default; request starts run with manualEndsAt',
      () async {
        final now = DateTime(2026, 11, 10, 8, 30);
        final medRepo = FakeSystemRepository(
          initialTemperature: 34.0,
          initialHumidity: 45.0,
          initialAirQuality: 500.0,
          clock: () => now,
          autoResetDuration: const Duration(minutes: 5),
          publishManualEndsAt: true,
        );

        expect(medRepo.currentTier, equals(Tier.medium));
        expect(medRepo.currentFanOn, isFalse);
        expect(medRepo.currentStatusMessage, equals('CAUTION'));

        // Request ventilation activates the fan and publishes manualEndsAt
        await medRepo.requestManualVentilation();
        expect(medRepo.currentFanOn, isTrue);
        expect(medRepo.rawManualToggle, isTrue);
        expect(medRepo.currentStatusMessage, equals('CAUTION'));
        expect(
          medRepo.currentManualEndsAt,
          equals(now.add(const Duration(minutes: 5))),
        );

        medRepo.dispose();
      },
    );

    test(
      'when publishManualEndsAt is false, manualEndsAt is omitted',
      () async {
        final medRepo = FakeSystemRepository(
          initialTemperature: 34.0,
          initialHumidity: 45.0,
          initialAirQuality: 500.0,
          publishManualEndsAt: false,
        );

        await medRepo.requestManualVentilation();
        expect(medRepo.currentFanOn, isTrue);
        expect(medRepo.currentManualEndsAt, isNull);

        medRepo.dispose();
      },
    );

    test(
      'watchConfig emits manualDurationSec when publishConfig is true',
      () async {
        final repoWithConfig = FakeSystemRepository(
          publishConfig: true,
          manualDurationSec: 300,
        );

        final config = await repoWithConfig.watchConfig().first;
        expect(config, isNotNull);
        expect(config!['manualDurationSec'], equals(300));

        repoWithConfig.dispose();
      },
    );

    test('watchConfig emits null when publishConfig is false', () async {
      final repoWithoutConfig = FakeSystemRepository(publishConfig: false);

      final config = await repoWithoutConfig.watchConfig().first;
      expect(config, isNull);

      repoWithoutConfig.dispose();
    });

    test(
      'Medium tier: writing false defensively is ignored (persistent run)',
      () async {
        final medRepo = FakeSystemRepository(
          initialTemperature: 34.0,
          initialHumidity: 45.0,
          initialAirQuality: 500.0,
        );

        await medRepo.requestManualVentilation();
        expect(medRepo.currentFanOn, isTrue);

        // Attempting to set false is ignored: firmware persists the run
        await medRepo.setManualToggle(false);
        expect(medRepo.currentFanOn, isTrue);
        expect(medRepo.rawManualToggle, isTrue);

        medRepo.dispose();
      },
    );

    test(
      'Medium tier: manual toggle auto-resets to false after duration',
      () async {
        final medRepo = FakeSystemRepository(
          initialTemperature: 34.0,
          initialHumidity: 45.0,
          initialAirQuality: 500.0,
          autoResetDuration: const Duration(milliseconds: 50),
        );

        await medRepo.requestManualVentilation();
        expect(medRepo.rawManualToggle, isTrue);
        expect(medRepo.currentFanOn, isTrue);

        // Wait for auto-reset duration
        await Future<void>.delayed(const Duration(milliseconds: 100));

        expect(medRepo.rawManualToggle, isFalse);
        expect(medRepo.currentFanOn, isFalse);
        expect(medRepo.currentStatusMessage, equals('CAUTION'));

        medRepo.dispose();
      },
    );

    test(
      'Danger cancels manual run and latches fan ON through Caution until Safe',
      () async {
        // Start in Medium tier
        final repo = FakeSystemRepository(
          initialTemperature: 34.0,
          initialHumidity: 45.0,
          initialAirQuality: 500.0,
        );

        await repo.requestManualVentilation();
        expect(repo.currentFanOn, isTrue);
        expect(repo.rawManualToggle, isTrue);

        // Danger event occurs
        repo.simulateKitchenSmoke();
        expect(repo.currentTier, equals(Tier.danger));
        expect(repo.currentFanOn, isTrue);
        // Manual run was cancelled by Danger
        expect(repo.rawManualToggle, isFalse);
        expect(repo.currentManualEndsAt, isNull);

        // When tier recovers to Medium (Phase 1 & Phase 2 in smoke scenario)
        // Fan remains latched ON!
        // We advance ticks manually to step 4 (Medium tier)
        for (var i = 0; i < 4; i++) {
          repo.onTickForTesting();
        }
        expect(repo.currentTier, equals(Tier.medium));
        expect(
          repo.currentFanOn,
          isTrue,
          reason: 'Fan must remain latched ON in Caution after Danger',
        );
        expect(repo.rawManualToggle, isFalse);

        // Advance to Phase 3 (Safe tier recovery)
        for (var i = 0; i < 8; i++) {
          repo.onTickForTesting();
        }
        expect(repo.currentTier, equals(Tier.safe));
        expect(
          repo.currentFanOn,
          isFalse,
          reason: 'Fan turns OFF only when room returns to Safe',
        );

        repo.dispose();
      },
    );
  });

  group('FakeSystemRepository - Scripted Scenarios with Danger Latch', () {
    test('Kitchen smoke simulation spikes to Danger, latches through Medium, recovers to Safe', () async {
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

      // Advance through ticks to watch recovery:
      // Steps 1-3: Danger (fan ON)
      // Steps 4-9: Medium (fan latched ON!)
      // Step 10+: Safe (latch clears, fan OFF)
      await Future<void>.delayed(const Duration(milliseconds: 200));

      expect(repo.currentScenario, equals(DemoScenario.none));
      expect(
        repo.currentAirQuality,
        closeTo(repo.currentBaselineAirQuality, 30.0),
      );
      expect(repo.currentTier, equals(Tier.safe));
      expect(repo.currentFanOn, isFalse);

      await sub.cancel();
      repo.dispose();
    });

    test(
      'Heat spike simulation ramps through Caution to Danger and recovers',
      () async {
        final repo = FakeSystemRepository(
          tickInterval: const Duration(milliseconds: 10),
          clock: () => DateTime(2026, 11, 10, 8, 30),
          initialTemperature: 35.0,
        );

        final states = <SystemState>[];
        final sub = repo.watchSystemState().listen(states.add);
        await pumpEventQueue();

        repo.simulateHeatSpike();
        expect(repo.currentScenario, equals(DemoScenario.heat));

        await Future<void>.delayed(const Duration(milliseconds: 450));

        expect(repo.currentScenario, equals(DemoScenario.none));
        expect(repo.currentTemperature, closeTo(repo.currentBaselineTemp, 0.5));
        expect(repo.currentTier, equals(Tier.safe));

        await sub.cancel();
        repo.dispose();
      },
    );

    test(
      'resetToBaseline cancels active scenarios and clears Danger latch',
      () async {
        final repo = FakeSystemRepository(
          tickInterval: const Duration(milliseconds: 10),
          clock: () => DateTime(2026, 11, 10, 8, 30),
        );

        final sub = repo.watchSystemState().listen((_) {});
        await pumpEventQueue();

        repo.simulateKitchenSmoke();
        expect(repo.currentScenario, equals(DemoScenario.smoke));
        expect(repo.currentTier, equals(Tier.danger));
        expect(repo.currentFanOn, isTrue);

        repo.resetToBaseline();
        expect(repo.currentScenario, equals(DemoScenario.none));
        expect(repo.currentAirQuality, equals(repo.currentBaselineAirQuality));
        expect(repo.currentTier, equals(Tier.safe));
        expect(repo.currentFanOn, isFalse);

        await sub.cancel();
        repo.dispose();
      },
    );
  });

  group('FakeSystemRepository - Timers and Resource Management', () {
    test(
      'timer starts on first listen and cancels when all subscriptions cancel',
      () async {
        final repo = FakeSystemRepository(
          tickInterval: const Duration(milliseconds: 20),
        );

        expect(repo.hasActiveTimers, isFalse);

        final sub1 = repo.watchSystemState().listen((_) {});
        await pumpEventQueue();
        expect(repo.hasActiveTimers, isTrue);

        final sub2 = repo.watchRawSystem().listen((_) {});
        await pumpEventQueue();
        expect(repo.hasActiveTimers, isTrue);

        await sub1.cancel();
        expect(repo.hasActiveTimers, isTrue);

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
