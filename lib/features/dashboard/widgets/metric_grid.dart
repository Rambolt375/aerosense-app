import 'package:flutter/material.dart';
import 'package:aerosense_app/data/models/metric_tier.dart';
import 'package:aerosense_app/features/dashboard/widgets/metric_tile.dart';

/// Responsive grid container for the three metric tiles.
///
/// Layout per DESIGN.md §4:
/// - Mobile (< 600 dp): single column stack
/// - Tablet (600–899 dp): 2 or 3 columns
/// - Desktop (≥ 900 dp): 3 columns side by side
class MetricGrid extends StatelessWidget {
  const MetricGrid({
    super.key,
    required this.temperature,
    required this.humidity,
    required this.airQuality,
  });

  final double? temperature;
  final double? humidity;
  final double? airQuality;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width < 600 ? 1 : (width < 900 ? 2 : 3);

    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      childAspectRatio: 1.4,
      children: [
        MetricTile(
          icon: Icons.device_thermostat_outlined,
          label: 'Temperature',
          value: temperature,
          unit: '°C',
          metricTier: MetricTier.forTemperature(temperature),
        ),
        MetricTile(
          icon: Icons.water_drop_outlined,
          label: 'Humidity',
          value: humidity,
          unit: '%',
          metricTier: MetricTier.forHumidity(humidity),
        ),
        MetricTile(
          icon: Icons.air_outlined,
          label: 'Air quality',
          value: airQuality,
          unit: '',
          metricTier: MetricTier.forAirQuality(airQuality),
          caption: 'Relative index, uncalibrated',
        ),
      ],
    );
  }
}
