import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_diurnal_generator.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';

void main() {
  tearDown(() {
    // Always restore firmware preset after tests
    Thresholds.current = ThresholdPreset.firmware;
  });

  group('Requirement 4: Demo Mode thresholds derivation (Firmware preset)', () {
    test('normal diurnal demo baseline stays strictly Safe across full 24-hour cycle', () {
      final random = math.Random(42);
      final anchor = DateTime(2026, 11, 12, 0, 0);

      // Sample every 5 minutes for 24 hours (288 samples)
      for (var min = 0; min < 24 * 60; min += 5) {
        final time = anchor.add(Duration(minutes: min));
        final sample = generateDiurnalSample(
          time,
          random: random,
          addNoise: true,
        );

        expect(
          sample.temperature,
          lessThan(Thresholds.tempSafeMax),
          reason:
              'Temp ${sample.temperature} at $time must be Safe (< ${Thresholds.tempSafeMax})',
        );
        expect(
          sample.airQuality,
          lessThan(Thresholds.airQualitySafeMax),
          reason:
              'AQ ${sample.airQuality} at $time must be Safe (< ${Thresholds.airQualitySafeMax})',
        );
        expect(
          sample.humidity,
          lessThan(Thresholds.humiditySafeMax),
          reason:
              'Humidity ${sample.humidity} at $time must be Safe (< ${Thresholds.humiditySafeMax})',
        );
      }
    });

    test('heat spike reaches Danger (>= 36.0) through Caution (>= 33.5) and recovers', () {
      final fakeRepo = FakeSystemRepository(
        tickInterval: const Duration(milliseconds: 10),
        random: math.Random(123),
      );

      // Initially safe
      expect(fakeRepo.currentTemperature, lessThan(Thresholds.tempSafeMax));
      expect(fakeRepo.currentTier, Tier.safe);

      fakeRepo.simulateHeatSpike();

      var crossedCaution = false;
      var reachedDanger = false;
      var recoveredToSafe = false;

      // Advance ticks to trace the scenario lifecycle
      for (var i = 0; i < 40; i++) {
        final temp = fakeRepo.currentTemperature;
        final tier = fakeRepo.currentTier;

        if (temp != null) {
          if (temp >= Thresholds.tempSafeMax &&
              temp < Thresholds.tempDangerMin) {
            crossedCaution = true;
            expect(
              tier,
              Tier.medium,
              reason: 'Must reflect Medium/Caution tier',
            );
          }
          if (temp >= Thresholds.tempDangerMin) {
            reachedDanger = true;
            expect(tier, Tier.danger, reason: 'Must reflect Danger tier');
            expect(
              fakeRepo.currentFanOn,
              isTrue,
              reason: 'Fan forced ON in Danger',
            );
          }
          if (reachedDanger && temp < Thresholds.tempSafeMax) {
            recoveredToSafe = true;
            break;
          }
        }

        // Trigger tick manually by advancing fake repository ticker or scenario step
        fakeRepo.onTickForTesting();
      }

      expect(
        crossedCaution,
        isTrue,
        reason: 'Heat spike must cross Caution (>= 33.5)',
      );
      expect(
        reachedDanger,
        isTrue,
        reason: 'Heat spike must reach Danger (>= 36.0)',
      );
      expect(
        recoveredToSafe,
        isTrue,
        reason: 'Heat spike must recover back to Safe',
      );
    });

    test('history anomalies actually cross Caution and Danger on temperature', () {
      final records = FakeHistoryRepository.generateHistory(
        anchor: DateTime(2026, 11, 12, 12, 0),
        count: 1008,
        includeAnomalies: true,
        seed: 42,
      );

      final temps = records.map((r) => r.temperature!).toList();

      final hasCautionTemp = temps.any(
        (t) => t >= Thresholds.tempSafeMax && t < Thresholds.tempDangerMin,
      );
      final hasDangerTemp = temps.any((t) => t >= Thresholds.tempDangerMin);

      expect(
        hasCautionTemp,
        isTrue,
        reason:
            'History anomalies must cross Caution threshold (>= ${Thresholds.tempSafeMax})',
      );
      expect(
        hasDangerTemp,
        isTrue,
        reason:
            'History anomalies must reach Danger threshold (>= ${Thresholds.tempDangerMin})',
      );

      // Clean history without anomalies stays safe
      final cleanRecords = FakeHistoryRepository.generateHistory(
        anchor: DateTime(2026, 11, 12, 12, 0),
        count: 1008,
        includeAnomalies: false,
        seed: 42,
      );
      for (final r in cleanRecords) {
        expect(
          r.temperature,
          lessThan(Thresholds.tempSafeMax),
          reason: 'Clean history without anomalies must stay strictly Safe',
        );
      }
    });

    test(
      'simulateSensorUnplugged nulls temperature and humidity, then recovers',
      () {
        final fakeRepo = FakeSystemRepository(random: math.Random(42));

        fakeRepo.simulateSensorUnplugged();

        expect(fakeRepo.currentScenario, DemoScenario.sensorUnplugged);
        expect(fakeRepo.currentTemperature, isNull);
        expect(fakeRepo.currentHumidity, isNull);
        expect(fakeRepo.currentTier, Tier.safe);

        // 5 ticks of disconnected state
        for (var i = 0; i < 5; i++) {
          fakeRepo.onTickForTesting();
          expect(fakeRepo.currentTemperature, isNull);
          expect(fakeRepo.currentHumidity, isNull);
        }

        // Reconnects on tick 6
        fakeRepo.onTickForTesting();
        expect(fakeRepo.currentScenario, DemoScenario.none);
        expect(fakeRepo.currentTemperature, isNotNull);
        expect(fakeRepo.currentHumidity, isNotNull);
        expect(fakeRepo.currentTemperature, lessThan(Thresholds.tempSafeMax));
      },
    );
  });

  group('Requirement 4: Dynamic preset adaptation (Demo preset)', () {
    setUp(() {
      Thresholds.current = ThresholdPreset.demo; // Caution: 28.0, Danger: 32.0
    });

    test('diurnal baseline stays Safe (< 28.0) under Demo preset', () {
      final random = math.Random(99);
      final anchor = DateTime(2026, 11, 12, 0, 0);

      for (var min = 0; min < 24 * 60; min += 15) {
        final time = anchor.add(Duration(minutes: min));
        final sample = generateDiurnalSample(
          time,
          random: random,
          addNoise: true,
        );

        expect(sample.temperature, lessThan(Thresholds.tempSafeMax)); // < 28.0
        expect(
          sample.airQuality,
          lessThan(Thresholds.airQualitySafeMax),
        ); // < 1000.0
      }
    });

    test('heat spike reaches Danger (>= 32.0) through Caution (>= 28.0) under Demo preset', () {
      final fakeRepo = FakeSystemRepository(random: math.Random(99));

      fakeRepo.simulateHeatSpike();

      var crossedCaution = false;
      var reachedDanger = false;

      for (var i = 0; i < 40; i++) {
        final temp = fakeRepo.currentTemperature;
        if (temp != null) {
          if (temp >= Thresholds.tempSafeMax &&
              temp < Thresholds.tempDangerMin) {
            crossedCaution = true;
          }
          if (temp >= Thresholds.tempDangerMin) {
            reachedDanger = true;
            break;
          }
        }
        fakeRepo.onTickForTesting();
      }

      expect(
        crossedCaution,
        isTrue,
        reason: 'Must cross Caution under Demo preset (>= 28.0)',
      );
      expect(
        reachedDanger,
        isTrue,
        reason: 'Must reach Danger under Demo preset (>= 32.0)',
      );
    });

    test('history anomalies cross Caution (>= 28.0) and Danger (>= 32.0) under Demo preset', () {
      final records = FakeHistoryRepository.generateHistory(
        anchor: DateTime(2026, 11, 12, 12, 0),
        count: 1008,
        includeAnomalies: true,
        seed: 99,
      );

      final temps = records.map((r) => r.temperature!).toList();
      expect(temps.any((t) => t >= 28.0 && t < 32.0), isTrue);
      expect(temps.any((t) => t >= 32.0), isTrue);
    });
  });
}
