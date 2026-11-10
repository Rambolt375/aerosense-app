import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/metric_tier.dart';
import 'package:aerosense_app/data/models/tier.dart';

void main() {
  group('MetricTier.forTemperature', () {
    test('null → safe', () {
      expect(MetricTier.forTemperature(null), Tier.safe);
    });
    test('33.4 → safe (below tempSafeMax)', () {
      expect(MetricTier.forTemperature(33.4), Tier.safe);
    });
    test('33.5 → medium (at tempSafeMax boundary >=)', () {
      expect(MetricTier.forTemperature(33.5), Tier.medium);
    });
    test('35.0 → medium', () {
      expect(MetricTier.forTemperature(35.0), Tier.medium);
    });
    test('35.9 → medium (below tempDangerMin 36.0)', () {
      expect(MetricTier.forTemperature(35.9), Tier.medium);
    });
    test('36.0 → danger (at tempDangerMin boundary >=)', () {
      expect(MetricTier.forTemperature(36.0), Tier.danger);
    });
    test('36.1 → danger (> tempDangerMin)', () {
      expect(MetricTier.forTemperature(36.1), Tier.danger);
    });
    test('Thresholds.tempSafeMax (33.5) → medium', () {
      expect(MetricTier.forTemperature(Thresholds.tempSafeMax), Tier.medium);
    });
    test('Thresholds.tempDangerMin (36.0) → danger', () {
      expect(MetricTier.forTemperature(Thresholds.tempDangerMin), Tier.danger);
    });
  });

  group('MetricTier.forHumidity', () {
    test('null → safe', () {
      expect(MetricTier.forHumidity(null), Tier.safe);
    });
    test('59.9 → safe', () {
      expect(MetricTier.forHumidity(59.9), Tier.safe);
    });
    test('60.0 → medium (at humiditySafeMax boundary >=)', () {
      expect(MetricTier.forHumidity(60.0), Tier.medium);
    });
    test('70.0 → medium', () {
      expect(MetricTier.forHumidity(70.0), Tier.medium);
    });
    test('74.9 → medium', () {
      expect(MetricTier.forHumidity(74.9), Tier.medium);
    });
    test('75.0 → danger (at humidityDangerMin boundary >=)', () {
      expect(MetricTier.forHumidity(75.0), Tier.danger);
    });
    test('75.1 → danger', () {
      expect(MetricTier.forHumidity(75.1), Tier.danger);
    });
    test('Thresholds.humiditySafeMax (60.0) → medium', () {
      expect(MetricTier.forHumidity(Thresholds.humiditySafeMax), Tier.medium);
    });
    test('Thresholds.humidityDangerMin (75.0) → danger', () {
      expect(MetricTier.forHumidity(Thresholds.humidityDangerMin), Tier.danger);
    });
  });

  group('MetricTier.forAirQuality', () {
    test('null → safe', () {
      expect(MetricTier.forAirQuality(null), Tier.safe);
    });
    test('1399.9 → safe', () {
      expect(MetricTier.forAirQuality(1399.9), Tier.safe);
    });
    test('1400.0 → medium (at airQualitySafeMax boundary >=)', () {
      expect(MetricTier.forAirQuality(1400.0), Tier.medium);
    });
    test('1800.0 → medium', () {
      expect(MetricTier.forAirQuality(1800.0), Tier.medium);
    });
    test('1999.9 → medium', () {
      expect(MetricTier.forAirQuality(1999.9), Tier.medium);
    });
    test('2000.0 → danger (at airQualityDangerMin boundary >=)', () {
      expect(MetricTier.forAirQuality(2000.0), Tier.danger);
    });
    test('2000.1 → danger', () {
      expect(MetricTier.forAirQuality(2000.1), Tier.danger);
    });
    test('1128 (DATA_SAMPLE value) → safe', () {
      expect(MetricTier.forAirQuality(1128.0), Tier.safe);
    });
    test('Thresholds.airQualitySafeMax (1400.0) → medium', () {
      expect(
        MetricTier.forAirQuality(Thresholds.airQualitySafeMax),
        Tier.medium,
      );
    });
    test('Thresholds.airQualityDangerMin (2000.0) → danger', () {
      expect(
        MetricTier.forAirQuality(Thresholds.airQualityDangerMin),
        Tier.danger,
      );
    });
  });
}
