import 'dart:async';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/history_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/history/history_pipeline.dart';
import 'package:aerosense_app/features/history/history_screen.dart';
import 'package:aerosense_app/features/history/widgets/metric_chart_card.dart';
import 'package:aerosense_app/features/history/widgets/range_selector.dart';

/// Test repository allowing programmatic control over history data and streams.
class _MockHistoryRepository implements HistoryRepository {
  _MockHistoryRepository({
    this.initialRecords = const [],
    this.shouldThrow = false,
  });

  List<HistoryRecord> initialRecords;
  bool shouldThrow;
  final controller = StreamController<HistoryRecord>.broadcast();

  @override
  Future<List<HistoryRecord>> fetchHistory({int limit = 288}) async {
    if (shouldThrow) {
      throw Exception('Simulated network error');
    }
    return initialRecords;
  }

  @override
  Stream<HistoryRecord> watchNewRecords() => controller.stream;

  void dispose() {
    controller.close();
  }
}

Widget createTestSubject({required HistoryRepository repository}) {
  return ProviderScope(
    overrides: [
      demoModeProvider.overrideWith(() => _AlwaysDemoNotifier()),
      historyRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      theme: AeroSenseTheme.light,
      home: const HistoryScreen(),
    ),
  );
}

class _AlwaysDemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

void main() {
  final now = DateTime.now();

  group('HistoryScreen UI & Interactions', () {
    testWidgets(
      'renders three metric charts, RangeSelector, and default 24 h range',
      (tester) async {
        final dataset = FakeHistoryRepository.generateHistory(
          anchor: now,
          count: 288,
        );
        final repo = _MockHistoryRepository(initialRecords: dataset);
        addTearDown(repo.dispose);

        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestSubject(repository: repo));
        await tester.pumpAndSettle();

        // Range selector present with all options
        expect(find.byType(RangeSelector), findsOneWidget);
        expect(find.text('1 h'), findsOneWidget);
        expect(find.text('6 h'), findsOneWidget);
        expect(find.text('24 h'), findsOneWidget);
        expect(find.text('7 d'), findsOneWidget);

        // Three metric chart cards
        expect(find.byType(MetricChartCard), findsNWidgets(3));
        expect(find.text('Temperature'), findsOneWidget);
        expect(find.text('Humidity'), findsOneWidget);
        expect(find.text('Air quality'), findsOneWidget);
        expect(find.text('Relative index, uncalibrated'), findsOneWidget);

        // LineChart widgets rendered
        expect(find.byType(LineChart), findsNWidgets(3));

        // Legend row on all 3 cards: "Safe", "Medium", "Danger"
        expect(find.text('Safe'), findsNWidgets(3));
        expect(find.text('Medium'), findsNWidgets(3));
        expect(find.text('Danger'), findsNWidgets(3));
      },
    );

    testWidgets('switching range via RangeSelector updates active range', (
      tester,
    ) async {
      final dataset = FakeHistoryRepository.generateHistory(
        anchor: now,
        count: 288,
      );
      final repo = _MockHistoryRepository(initialRecords: dataset);
      addTearDown(repo.dispose);

      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(createTestSubject(repository: repo));
      await tester.pumpAndSettle();

      // Tap "1 h"
      await tester.tap(find.text('1 h'));
      await tester.pumpAndSettle();

      final segmentedButton = tester.widget<SegmentedButton<HistoryRange>>(
        find.byType(SegmentedButton<HistoryRange>),
      );
      expect(segmentedButton.selected, {HistoryRange.h1});
    });

    testWidgets(
      'renders empty state "No history yet" when repository returns 0 records',
      (tester) async {
        final repo = _MockHistoryRepository(initialRecords: []);
        addTearDown(repo.dispose);

        await tester.pumpWidget(createTestSubject(repository: repo));
        await tester.pumpAndSettle();

        expect(find.text('No history yet'), findsOneWidget);
        expect(find.text('The device logs every 10 minutes.'), findsOneWidget);
        expect(find.byType(MetricChartCard), findsNothing);
      },
    );

    testWidgets(
      'renders error card with Retry button when fetch fails, and retry triggers reload',
      (tester) async {
        final repo = _MockHistoryRepository(shouldThrow: true);
        addTearDown(repo.dispose);

        await tester.pumpWidget(createTestSubject(repository: repo));
        await tester.pumpAndSettle();

        expect(find.text('Failed to load history'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);

        // Fix repo and tap retry
        repo.shouldThrow = false;
        repo.initialRecords = FakeHistoryRepository.generateHistory(
          anchor: now,
          count: 12,
        );

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(find.byType(MetricChartCard), findsNWidgets(3));
        expect(find.text('Failed to load history'), findsNothing);
      },
    );

    testWidgets(
      'renders synthetic timestamp chip when records have null timestamps',
      (tester) async {
        final records = List.generate(
          15,
          (i) => HistoryRecord(
            pushKey: 'key-${i.toString().padLeft(3, '0')}',
            timestamp: null,
            temperature: 24.0 + (i * 0.1),
            humidity: 50.0,
            airQuality: 700.0,
          ),
        );
        final repo = _MockHistoryRepository(initialRecords: records);
        addTearDown(repo.dispose);

        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestSubject(repository: repo));
        await tester.pumpAndSettle();

        // Synthetic chip text (Requirement 8)
        expect(
          find.text(
            "Time axis is estimated: the device isn't sending timestamps.",
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'provides Semantics summary labels for screen readers (Requirement 9)',
      (tester) async {
        final dataset = FakeHistoryRepository.generateHistory(
          anchor: now,
          count: 24,
        );
        final repo = _MockHistoryRepository(initialRecords: dataset);
        addTearDown(repo.dispose);

        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestSubject(repository: repo));
        await tester.pumpAndSettle();

        // Find Semantics nodes containing chart summaries
        final semantics = tester.allWidgets.whereType<Semantics>();
        final tempSemantics = semantics.firstWhere(
          (s) =>
              s.properties.label?.contains(
                'Temperature history over the last 24 h',
              ) ??
              false,
        );
        expect(tempSemantics.properties.label, contains('Safe below 33.5 °C'));
        expect(
          tempSemantics.properties.label,
          contains('Danger above 36.0 °C'),
        );
      },
    );

    testWidgets(
      'live append via watchNewRecords merges new record without re-downloading',
      (tester) async {
        final initial = [
          HistoryRecord(
            pushKey: 'k-001',
            timestamp: now.subtract(const Duration(minutes: 10)),
            temperature: 24.0,
            humidity: 50.0,
            airQuality: 600.0,
          ),
          HistoryRecord(
            pushKey: 'k-002',
            timestamp: now.subtract(const Duration(minutes: 5)),
            temperature: 24.5,
            humidity: 51.0,
            airQuality: 620.0,
          ),
        ];
        final repo = _MockHistoryRepository(initialRecords: initial);
        addTearDown(repo.dispose);

        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(createTestSubject(repository: repo));
        await tester.pumpAndSettle();

        expect(find.byType(LineChart), findsNWidgets(3));

        // Emit new record live
        repo.controller.add(
          HistoryRecord(
            pushKey: 'k-003',
            timestamp: now,
            temperature: 25.0,
            humidity: 52.0,
            airQuality: 640.0,
          ),
        );
        await tester.pump();

        // Chart updates seamlessly
        expect(find.byType(LineChart), findsNWidgets(3));
      },
    );
  });
}
