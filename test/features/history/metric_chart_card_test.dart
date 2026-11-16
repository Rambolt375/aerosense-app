import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';
import 'package:aerosense_app/features/history/widgets/metric_chart_card.dart';

void main() {
  const spots = [FlSpot(0, 50.0), FlSpot(900000, 55.0)];
  const xAxisConfig = XAxisConfig(
    minX: 0,
    maxX: 3600000,
    baselineX: 0,
    interval: 900000,
    formatDate: _formatTime,
  );

  Widget harness({required bool showThresholds}) {
    final yBounds = calculateYAxisBounds(
      spots: spots,
      safeMax: 60.0,
      dangerMin: 75.0,
      padding: 5.0,
      absoluteMin: 0.0,
      absoluteMax: 100.0,
      interval: 20.0,
      includeThresholds: showThresholds,
    );

    return MaterialApp(
      theme: AeroSenseTheme.light,
      home: Scaffold(
        body: SingleChildScrollView(
          child: MetricChartCard(
            title: 'Humidity',
            unit: '% RH',
            spots: spots,
            xAxisConfig: xAxisConfig,
            yBounds: yBounds,
            semanticsSummary: 'Humidity history',
            showThresholds: showThresholds,
          ),
        ),
      ),
    );
  }

  LineChartData chartData(WidgetTester tester) {
    return tester.widget<LineChart>(find.byType(LineChart)).data;
  }

  group('MetricChartCard threshold visuals', () {
    testWidgets('shows bands, legend, and threshold labels by default', (
      tester,
    ) async {
      await tester.pumpWidget(harness(showThresholds: true));

      expect(find.text('Safe'), findsOneWidget);
      expect(find.text('Caution'), findsOneWidget);
      expect(find.text('Danger'), findsOneWidget);

      final data = chartData(tester);
      expect(data.rangeAnnotations.horizontalRangeAnnotations, hasLength(3));
      expect(data.extraLinesData.horizontalLines, hasLength(2));
    });

    testWidgets('hides bands, legend, and threshold labels when disabled', (
      tester,
    ) async {
      await tester.pumpWidget(harness(showThresholds: false));

      expect(find.text('Safe'), findsNothing);
      expect(find.text('Caution'), findsNothing);
      expect(find.text('Danger'), findsNothing);

      final data = chartData(tester);
      expect(data.rangeAnnotations.horizontalRangeAnnotations, isEmpty);
      expect(data.extraLinesData.horizontalLines, isEmpty);
      expect(data.lineBarsData, hasLength(1));
    });
  });
}

String _formatTime(DateTime time) => '14:00';
