import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/metric_tier.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/dashboard/widgets/metric_tile.dart';
import 'package:aerosense_app/features/dashboard/widgets/tier_banner.dart';

void main() {
  group('MetricTile', () {
    testWidgets('renders temperature with °C unit and tabular figures', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              icon: Icons.device_thermostat_outlined,
              label: 'Temperature',
              value: 27.4,
              unit: '°C',
              metricTier: MetricTier.forTemperature(27.4),
            ),
          ),
        ),
      );

      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('27.4'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);

      // Verify tabular figures font feature is applied
      final valueFinder = find.text('27.4');
      final textWidget = tester.widget<Text>(valueFinder);
      expect(
        textWidget.style?.fontFeatures,
        contains(const FontFeature.tabularFigures()),
      );
    });

    testWidgets('renders humidity with % unit', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              icon: Icons.water_drop_outlined,
              label: 'Humidity',
              value: 55.0,
              unit: '%',
              metricTier: MetricTier.forHumidity(55.0),
            ),
          ),
        ),
      );

      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('55.0'), findsOneWidget);
      expect(find.text('%'), findsOneWidget);
    });

    testWidgets('renders air quality with no unit and caption', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              icon: Icons.air_outlined,
              label: 'Air quality',
              value: 1128.0,
              unit: '',
              metricTier: MetricTier.forAirQuality(1128.0),
              caption: 'Relative index, uncalibrated',
            ),
          ),
        ),
      );

      expect(find.text('Air quality'), findsOneWidget);
      expect(find.text('1128.0'), findsOneWidget);
      expect(find.text('Relative index, uncalibrated'), findsOneWidget);
      // Verify "ppm" does NOT appear
      expect(find.textContaining('ppm', findRichText: true), findsNothing);
    });

    testWidgets('null value renders as "--"', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              icon: Icons.device_thermostat_outlined,
              label: 'Temperature',
              value: null,
              unit: '°C',
              metricTier: MetricTier.forTemperature(null),
            ),
          ),
        ),
      );

      expect(find.text('--'), findsOneWidget);
      expect(find.text('°C'), findsOneWidget);
    });

    testWidgets('individual tier badge shows correct tier', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MetricTile(
              icon: Icons.device_thermostat_outlined,
              label: 'Temperature',
              value: 34.0,
              unit: '°C',
              metricTier: MetricTier.forTemperature(34.0), // Medium (>= 33.5)
            ),
          ),
        ),
      );

      expect(find.text('Medium'), findsOneWidget);
    });
  });

  group('TierBanner', () {
    testWidgets('Safe tier shows check icon and correct title', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(tier: Tier.safe, statusMessage: 'System Safe'),
          ),
        ),
      );

      expect(find.byIcon(Icons.check_circle_outlined), findsOneWidget);
      expect(find.text('Room is safe'), findsOneWidget);
      expect(find.text('System Safe'), findsOneWidget);
    });

    testWidgets('Medium tier shows warning icon and correct title', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(
              tier: Tier.medium,
              statusMessage:
                  'MEDIUM: Environment is stuffy. Manual toggle available.',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
      expect(find.text('Room is getting stuffy'), findsOneWidget);
      expect(
        find.text('MEDIUM: Environment is stuffy. Manual toggle available.'),
        findsOneWidget,
      );
    });

    testWidgets('Danger tier shows error icon and correct title', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(
              tier: Tier.danger,
              statusMessage:
                  'DANGER: High thresholds breached! Auto-fan activated.',
            ),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Hazardous air detected'), findsOneWidget);
      expect(
        find.text('DANGER: High thresholds breached! Auto-fan activated.'),
        findsOneWidget,
      );
    });

    testWidgets('Danger icon pulses (animation controller active)', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(tier: Tier.danger, statusMessage: 'DANGER: Test'),
          ),
        ),
      );

      // Use pump() not pumpAndSettle to verify animation state
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Animation is active: opacity should be changing
      final finder = find.descendant(
        of: find.byType(TierBanner),
        matching: find.byType(AnimatedBuilder),
      );
      expect(finder, findsOneWidget);
    });

    testWidgets('statusMessage displayed verbatim when descriptive', (
      tester,
    ) async {
      const customMessage = 'Custom firmware message with special chars: !@#';
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(tier: Tier.safe, statusMessage: customMessage),
          ),
        ),
      );

      expect(find.text(customMessage), findsOneWidget);
    });

    testWidgets('bare keyword "NORMAL" displays app friendly text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(tier: Tier.safe, statusMessage: 'NORMAL'),
          ),
        ),
      );

      expect(
        find.text('All environmental parameters are within safe ranges.'),
        findsOneWidget,
      );
      expect(find.text('NORMAL'), findsNothing);
    });

    testWidgets('bare keyword "CAUTION" displays app friendly text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(tier: Tier.medium, statusMessage: 'CAUTION'),
          ),
        ),
      );

      expect(
        find.text(
          'The room is getting stuffy. Manual ventilation is available.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('bare keyword "DANGER" displays app friendly text', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: TierBanner(tier: Tier.danger, statusMessage: 'DANGER'),
          ),
        ),
      );

      expect(
        find.text('Hazardous thresholds breached! Auto-fan is activated.'),
        findsOneWidget,
      );
    });
  });
}
