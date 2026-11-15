import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';

typedef ForecastPrefsSnapshot = ({bool trigger, bool fan});

void main() {
  group('FakeSystemRepository - Pre-ventilation firmware simulation', () {
    late FakeSystemRepository repo;
    late DateTime testClock;

    setUp(() {
      testClock = DateTime(2026, 11, 15, 12, 0);
      repo = FakeSystemRepository(
        clock: () => testClock,
        autoResetDuration: const Duration(minutes: 5),
      );
    });

    tearDown(() {
      repo.dispose();
    });

    test('initial forecast preferences have allowPreventive false and trigger false', () async {
      final prefs = await repo.watchForecastPreferences().first;
      expect(prefs.allowPreventive, isFalse);
      expect(prefs.preventiveTrigger, isFalse);
    });

    test('setAllowPreventive updates allowPreventive in stream', () async {
      await repo.setAllowPreventive(true);
      final prefs = await repo.watchForecastPreferences().first;
      expect(prefs.allowPreventive, isTrue);

      await repo.setAllowPreventive(false);
      final updated = await repo.watchForecastPreferences().first;
      expect(updated.allowPreventive, isFalse);
    });

    test('declines preventive trigger when allowPreventive is false', () async {
      // allowPreventive is false by default.
      // Firmware contract: trigger briefly pulses true→false without fan starting.
      // Collect events before the call so we capture the pulse.
      final events = <bool>[];
      final sub = repo.watchForecastPreferences().listen(
        (p) => events.add(p.preventiveTrigger),
      );
      // Allow the initial scheduleMicrotask emit to fire.
      await Future<void>.delayed(Duration.zero);
      events.clear(); // discard the initial false

      await repo.requestPreventiveTrigger();
      // Allow async stream delivery.
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      // Final state: declined — trigger is false and fan is off.
      expect(repo.currentPreventiveTrigger, isFalse);
      expect(repo.currentFanOn, isFalse);
      // Sequence must include true then false (true→false pulse = firmware decline).
      expect(events, contains(true));
      expect(events.last, isFalse);
    });

    test(
      'decline emits true→false pulse immediately without starting the fan',
      () async {
        // This test captures the sequence: app writes true, firmware declines
        // by resetting to false. Fan never starts.
        final events = <ForecastPrefsSnapshot>[];
        final sub = repo.watchForecastPreferences().listen(
          (p) => events.add((
            trigger: p.preventiveTrigger,
            fan: repo.currentFanOn,
          )),
        );
        // Discard initial scheduleMicrotask emit.
        await Future<void>.delayed(Duration.zero);
        events.clear();

        await repo.requestPreventiveTrigger(); // allowPreventive is false
        await Future<void>.delayed(Duration.zero);

        await sub.cancel();

        expect(events.length, greaterThanOrEqualTo(2));
        final trueEvent = events.firstWhere((e) => e.trigger);
        final falseEvent = events.lastWhere((e) => !e.trigger);
        expect(trueEvent.fan, isFalse); // fan never started
        expect(falseEvent.fan, isFalse);
      },
    );

    test('accepts preventive trigger when allowPreventive is true and room is Safe', () async {
      await repo.setAllowPreventive(true);
      await repo.requestPreventiveTrigger();

      final prefs = await repo.watchForecastPreferences().first;
      expect(prefs.preventiveTrigger, isTrue);
      expect(repo.currentFanOn, isTrue);
    });

    test(
      'auto-resets preventive trigger and turns off fan after fixed duration',
      () async {
        await repo.setAllowPreventive(true);
        await repo.requestPreventiveTrigger();

        expect(repo.currentFanOn, isTrue);

        // Advance clock past 5-minute duration
        testClock = testClock.add(const Duration(minutes: 5, seconds: 1));
        repo.onTickForTesting();

        final prefs = await repo.watchForecastPreferences().first;
        expect(prefs.preventiveTrigger, isFalse);
        expect(repo.currentFanOn, isFalse);
      },
    );

    test('writing false does NOT cancel a running preventive cycle', () async {
      await repo.setAllowPreventive(true);
      await repo.requestPreventiveTrigger();
      expect(repo.currentFanOn, isTrue);

      // Attempt to cancel via trigger setter with false
      await repo.setPreventiveTrigger(false);

      // Must remain active per firmware contract
      expect(repo.currentFanOn, isTrue);
      final prefs = await repo.watchForecastPreferences().first;
      expect(prefs.preventiveTrigger, isTrue);
    });

    test(
      'entering Danger cancels preventive trigger and latches fan ON',
      () async {
        await repo.setAllowPreventive(true);
        await repo.requestPreventiveTrigger();
        expect(repo.currentFanOn, isTrue);

        // Simulate Danger spike
        repo.simulateKitchenSmoke();

        expect(repo.currentTier, equals(Tier.danger));
        expect(repo.currentFanOn, isTrue);
        expect(repo.currentDangerLatched, isTrue);

        final prefs = await repo.watchForecastPreferences().first;
        expect(prefs.preventiveTrigger, isFalse);
      },
    );

    test(
      'declines preventive trigger when room is already in Danger',
      () async {
        await repo.setAllowPreventive(true);
        repo.simulateKitchenSmoke();
        expect(repo.currentTier, equals(Tier.danger));

        await repo.requestPreventiveTrigger();

        final prefs = await repo.watchForecastPreferences().first;
        expect(prefs.preventiveTrigger, isFalse);
      },
    );

    test(
      'declines preventive trigger when manual ventilation is already running',
      () async {
        // Put room in Caution
        final cautionRepo = FakeSystemRepository(
          initialTemperature: 25.0,
          initialHumidity: 50.0,
          initialAirQuality: Thresholds.airQualityCautionMin + 100.0,
          clock: () => testClock,
        );
        try {
          await cautionRepo.setAllowPreventive(true);
          await cautionRepo.requestManualVentilation();
          expect(cautionRepo.rawManualToggle, isTrue);

          await cautionRepo.requestPreventiveTrigger();

          final prefs = await cautionRepo.watchForecastPreferences().first;
          expect(prefs.preventiveTrigger, isFalse);
        } finally {
          cautionRepo.dispose();
        }
      },
    );
  });
}
