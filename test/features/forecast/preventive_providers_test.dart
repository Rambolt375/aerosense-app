import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/preventive_providers.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';
import 'package:aerosense_app/features/forecast/sinusoidal_fit.dart';

DiurnalModel _createTestAqModel({
  double peakSeconds = 14 * 3600.0, // 14:00
  double amplitude = 500.0,
  double c = 1000.0, // Peak = 1500 (>= 1400)
  bool hasClearDailyPattern = true,
}) {
  return DiurnalModel(
    coefficients: DiurnalCoefficients(
      a: amplitude,
      b: 0.0,
      c: c,
      amplitude: amplitude,
      phase: 0.0,
      peakSeconds: peakSeconds,
    ),
    residualStdDev: 10.0,
    effectiveThreshold: 30.0,
    hasClearDailyPattern: hasClearDailyPattern,
    rSquared: 0.6,
  );
}

void main() {
  group('Preventive providers & SharedPreferences persistence', () {
    test('publishPreventiveTriggersProvider defaults to false and persists changes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      expect(container.read(publishPreventiveTriggersProvider), isFalse);

      await container
          .read(publishPreventiveTriggersProvider.notifier)
          .setPublishing(true);
      expect(container.read(publishPreventiveTriggersProvider), isTrue);
      expect(prefs.getBool(PublishPreventiveNotifier.prefKey), isTrue);

      await container
          .read(publishPreventiveTriggersProvider.notifier)
          .setPublishing(false);
      expect(container.read(publishPreventiveTriggersProvider), isFalse);
      expect(prefs.getBool(PublishPreventiveNotifier.prefKey), isFalse);
    });

    test('preventiveTimestampsProvider loads saved timestamps from SharedPreferences', () async {
      final savedTrigger = DateTime(2026, 11, 15, 13, 45);
      final savedPeak = DateTime(2026, 11, 15, 14, 0);

      SharedPreferences.setMockInitialValues({
        PreventiveTimestampsNotifier.prefKeyLastTrigger: savedTrigger
            .toIso8601String(),
        PreventiveTimestampsNotifier.prefKeyLastPeak: savedPeak
            .toIso8601String(),
      });
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      final timestamps = container.read(preventiveTimestampsProvider);
      expect(timestamps.lastTriggerTime, equals(savedTrigger));
      expect(timestamps.lastTriggeredPeakTime, equals(savedPeak));
    });

    test(
      'preventiveTimestampsProvider records and persists new timestamps',
      () async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        );
        addTearDown(container.dispose);

        final triggerTime = DateTime(2026, 11, 15, 13, 45);
        final peakTime = DateTime(2026, 11, 15, 14, 0);

        await container
            .read(preventiveTimestampsProvider.notifier)
            .recordTrigger(triggerTime, peakTime);

        final timestamps = container.read(preventiveTimestampsProvider);
        expect(timestamps.lastTriggerTime, equals(triggerTime));
        expect(timestamps.lastTriggeredPeakTime, equals(peakTime));

        expect(
          prefs.getString(PreventiveTimestampsNotifier.prefKeyLastTrigger),
          equals(triggerTime.toIso8601String()),
        );
        expect(
          prefs.getString(PreventiveTimestampsNotifier.prefKeyLastPeak),
          equals(peakTime.toIso8601String()),
        );
      },
    );

    test('preventiveDecisionProvider evaluates decision with injected clock and state', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeRepo = FakeSystemRepository();
      await fakeRepo.setAllowPreventive(true);

      final testClock = DateTime(2026, 11, 15, 13, 45); // 15 min before 14:00

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          systemRepositoryProvider.overrideWithValue(fakeRepo),
          preventiveClockProvider.overrideWithValue(() => testClock),
          diurnalFitProvider.overrideWithValue(
            DiurnalFitState(
              temperatureResult: const DiurnalFitResult(
                status: DiurnalFitStatus.learning,
              ),
              airQualityResult: DiurnalFitResult(
                status: DiurnalFitStatus.ready,
                model: _createTestAqModel(),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeRepo.dispose);

      // Decision should compute armed and canTrigger if all gates match
      final decision = container.read(preventiveDecisionProvider);
      expect(decision.uiState, isNotNull);
    });
  });

  group('RunPreVentilationNotifier decline detection (5 s window)', () {
    test('surfaces decline message when firmware resets trigger without starting fan', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      // allowPreventive defaults to false -> firmware declines immediately.
      final fakeRepo = FakeSystemRepository();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          systemRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeRepo.dispose);

      await container.read(runPreVentilationNotifierProvider.notifier).runNow();

      // Drain microtasks so the broadcast stream delivers
      // initial false -> true pulse -> false reset.
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(runPreVentilationNotifierProvider);
      expect(state.isPending, isFalse);
      expect(
        state.feedbackMessage,
        equals('The device declined (permission off or busy)'),
      );
      expect(fakeRepo.currentFanOn, isFalse);
      expect(fakeRepo.currentPreventiveTrigger, isFalse);
    });

    test('does not surface decline message when the run is accepted', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeRepo = FakeSystemRepository();
      await fakeRepo.setAllowPreventive(true);

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          systemRepositoryProvider.overrideWithValue(fakeRepo),
        ],
      );
      addTearDown(container.dispose);
      addTearDown(fakeRepo.dispose);

      await container.read(runPreVentilationNotifierProvider.notifier).runNow();

      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }

      final state = container.read(runPreVentilationNotifierProvider);
      expect(state.isPending, isFalse);
      expect(state.feedbackMessage, isNull);
      expect(state.errorMessage, isNull);
      // Real firmware keeps the trigger true for the whole run.
      expect(fakeRepo.currentPreventiveTrigger, isTrue);
      expect(fakeRepo.currentFanOn, isTrue);
    });
  });
}
