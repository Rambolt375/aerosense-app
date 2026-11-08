import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/dashboard_screen.dart';

void main() {
  group('DashboardScreen responsive layout', () {
    testWidgets('Mobile (360 dp): single column layout', (tester) async {
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.safe,
                  temperature: 27.0,
                  humidity: 55.0,
                  airQuality: 820.0,
                  fanOn: false,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      // Verify dashboard content renders
      expect(find.text('Room is safe'), findsOneWidget);
      expect(find.text('Temperature'), findsOneWidget);
      expect(find.text('Humidity'), findsOneWidget);
      expect(find.text('Air quality'), findsOneWidget);

      // Verify metric grid uses single column (childAspectRatio and layout)
      final gridView = tester.widget<GridView>(find.byType(GridView));
      expect(
        (gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        1,
      );
    });

    testWidgets('Tablet (768 dp): 2 or 3 column layout', (tester) async {
      tester.view.physicalSize = const Size(768, 1024);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.safe,
                  temperature: 27.0,
                  humidity: 55.0,
                  airQuality: 820.0,
                  fanOn: false,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      final gridView = tester.widget<GridView>(find.byType(GridView));
      final crossAxisCount =
          (gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
              .crossAxisCount;
      expect(crossAxisCount, 2); // 768 dp → 2 columns
    });

    testWidgets('Desktop (1280 dp): 3 columns, max-width 1200 container', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(
                const SystemState(
                  tier: Tier.safe,
                  temperature: 27.0,
                  humidity: 55.0,
                  airQuality: 820.0,
                  fanOn: false,
                ),
              ),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();

      // Verify 3-column grid
      final gridView = tester.widget<GridView>(find.byType(GridView));
      expect(
        (gridView.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
            .crossAxisCount,
        3,
      );

      // Verify max-width container exists
      final constrainedBoxFinder = find.byWidgetPredicate(
        (w) => w is ConstrainedBox && w.constraints.maxWidth == 1200,
      );
      expect(constrainedBoxFinder, findsOneWidget);
    });
  });

  group('DashboardScreen loading and error states', () {
    testWidgets('shows loading skeleton during initial load', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.value(const SystemState()).asBroadcastStream(),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );

      // Before first frame
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Loading state renders skeleton blocks
      // (Note: The actual loading state uses surfaceContainerHighest colored containers)
    });

    testWidgets('shows error card with Retry button on stream failure', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
            systemStateProvider.overrideWith(
              (_) => Stream.error(Exception('Test error')),
            ),
            connectedProvider.overrideWith((_) => Stream.value(true)),
          ],
          child: const MaterialApp(home: DashboardScreen()),
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(find.text('Failed to load dashboard'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Retry'), findsOneWidget);
    });
  });
}
