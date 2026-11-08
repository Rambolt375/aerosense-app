import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/metric_tier.dart';
import 'package:aerosense_app/data/models/tier.dart';

void main() {
  group('MetricTier.forTemperature', () {
    test('null → safe', () {
      expect(MetricTier.forTemperature(null), Tier.safe);
    });
    test('27.9 → safe (below tempSafeMax)', () {
      expect(MetricTier.forTemperature(27.9), Tier.safe);
    });
    test('28.0 → medium (at tempSafeMax boundary)', () {
      expect(MetricTier.forTemperature(28.0), Tier.medium);
    });
    test('30.0 → medium', () {
      expect(MetricTier.forTemperature(30.0), Tier.medium);
    });
    test('32.0 → medium (at tempDangerMin, not > yet)', () {
      expect(MetricTier.forTemperature(32.0), Tier.medium);
    });
    test('32.1 → danger (> tempDangerMin)', () {
      expect(MetricTier.forTemperature(32.1), Tier.danger);
    });
    test('Thresholds.tempSafeMax (28.0) → medium', () {
      expect(MetricTier.forTemperature(Thresholds.tempSafeMax), Tier.medium);
    });
    test('Thresholds.tempDangerMin (32.0) → medium', () {
      expect(MetricTier.forTemperature(Thresholds.tempDangerMin), Tier.medium);
    });
    test('Thresholds.tempDangerMin + 0.1 → danger', () {
      expect(
        MetricTier.forTemperature(Thresholds.tempDangerMin + 0.1),
        Tier.danger,
      );
    });
  });

  group('MetricTier.forHumidity', () {
    test('null → safe', () {
      expect(MetricTier.forHumidity(null), Tier.safe);
    });
    test('59.9 → safe', () {
      expect(MetricTier.forHumidity(59.9), Tier.safe);
    });
    test('60.0 → medium (at humiditySafeMax)', () {
      expect(MetricTier.forHumidity(60.0), Tier.medium);
    });
    test('70.0 → medium', () {
      expect(MetricTier.forHumidity(70.0), Tier.medium);
    });
    test('75.0 → medium (at humidityDangerMin)', () {
      expect(MetricTier.forHumidity(75.0), Tier.medium);
    });
    test('75.1 → danger', () {
      expect(MetricTier.forHumidity(75.1), Tier.danger);
    });
    test('Thresholds.humiditySafeMax (60.0) → medium', () {
      expect(MetricTier.forHumidity(Thresholds.humiditySafeMax), Tier.medium);
    });
    test('Thresholds.humidityDangerMin (75.0) → medium', () {
      expect(MetricTier.forHumidity(Thresholds.humidityDangerMin), Tier.medium);
    });
    test('Thresholds.humidityDangerMin + 0.1 → danger', () {
      expect(
        MetricTier.forHumidity(Thresholds.humidityDangerMin + 0.1),
        Tier.danger,
      );
    });
  });

  group('MetricTier.forAirQuality', () {
    test('null → safe', () {
      expect(MetricTier.forAirQuality(null), Tier.safe);
    });
    test('999.9 → safe', () {
      expect(MetricTier.forAirQuality(999.9), Tier.safe);
    });
    test('1000.0 → medium (at airQualitySafeMax)', () {
      expect(MetricTier.forAirQuality(1000.0), Tier.medium);
    });
    test('1500.0 → medium', () {
      expect(MetricTier.forAirQuality(1500.0), Tier.medium);
    });
    test('2000.0 → medium (at airQualityDangerMin)', () {
      expect(MetricTier.forAirQuality(2000.0), Tier.medium);
    });
    test('2000.1 → danger', () {
      expect(MetricTier.forAirQuality(2000.1), Tier.danger);
    });
    test('1128 (DATA_SAMPLE value) → medium', () {
      expect(MetricTier.forAirQuality(1128.0), Tier.medium);
    });
    test('Thresholds.airQualitySafeMax (1000.0) → medium', () {
      expect(
        MetricTier.forAirQuality(Thresholds.airQualitySafeMax),
        Tier.medium,
      );
    });
    test('Thresholds.airQualityDangerMin (2000.0) → medium', () {
      expect(
        MetricTier.forAirQuality(Thresholds.airQualityDangerMin),
        Tier.medium,
      );
    });
    test('Thresholds.airQualityDangerMin + 0.1 → danger', () {
      expect(
        MetricTier.forAirQuality(Thresholds.airQualityDangerMin + 0.1),
        Tier.danger,
      );
    });
  });
}
