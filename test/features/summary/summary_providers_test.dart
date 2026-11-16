import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

void main() {
  DiurnalFitState fitState({
    int temperaturePercent = 0,
    int airQualityPercent = 0,
  }) {
    return DiurnalFitState(
      temperatureResult: DiurnalFitResult(
        status: DiurnalFitStatus.learning,
        learningPercentage: temperaturePercent,
      ),
      airQualityResult: DiurnalFitResult(
        status: DiurnalFitStatus.learning,
        learningPercentage: airQualityPercent,
      ),
    );
  }

  ForecastGate gateWith({
    MetricGateStatus temperature = MetricGateStatus.active,
    MetricGateStatus airQuality = MetricGateStatus.active,
    bool deviceOffline = false,
  }) {
    final gate = ForecastGate(isDeviceOffline: deviceOffline);
    gate.tempGate.status = temperature;
    gate.aqGate.status = airQuality;
    return gate;
  }

  group('forecastSummaryFor', () {
    test('maps an active gate to the active summary', () {
      final summary = forecastSummaryFor(
        gateWith(),
        fitState(temperaturePercent: 42),
      );

      expect(summary.status, ForecastSummaryStatus.active);
      expect(summary.temperaturePeak, isNull);
      expect(summary.airQualityPeak, isNull);
    });

    test('maps a residual-gate lockout to lockedOut', () {
      final summary = forecastSummaryFor(
        gateWith(temperature: MetricGateStatus.lockedOut),
        fitState(),
      );

      expect(summary.status, ForecastSummaryStatus.lockedOut);
    });

    test('maps learning to learning and uses the first available progress', () {
      final summary = forecastSummaryFor(
        gateWith(
          temperature: MetricGateStatus.learning,
          airQuality: MetricGateStatus.learning,
        ),
        fitState(temperaturePercent: 42, airQualityPercent: 71),
      );

      expect(summary.status, ForecastSummaryStatus.learning);
      expect(summary.learningPercent, 42);
    });

    test(
      'falls back to air-quality learning progress when temperature is 0',
      () {
        final summary = forecastSummaryFor(
          gateWith(
            temperature: MetricGateStatus.learning,
            airQuality: MetricGateStatus.learning,
          ),
          fitState(airQualityPercent: 71),
        );

        expect(summary.status, ForecastSummaryStatus.learning);
        expect(summary.learningPercent, 71);
      },
    );

    test('maps waiting-for-timestamps to waitingForTimestamps', () {
      final summary = forecastSummaryFor(
        gateWith(temperature: MetricGateStatus.waitingForTimestamps),
        fitState(),
      );

      expect(summary.status, ForecastSummaryStatus.waitingForTimestamps);
    });

    test('maps device offline to paused, never lockedOut', () {
      final summary = forecastSummaryFor(
        gateWith(
          temperature: MetricGateStatus.active,
          airQuality: MetricGateStatus.active,
          deviceOffline: true,
        ),
        fitState(),
      );

      expect(summary.status, ForecastSummaryStatus.paused);
      expect(summary.status, isNot(ForecastSummaryStatus.lockedOut));
    });
  });
}
