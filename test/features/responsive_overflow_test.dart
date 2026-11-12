import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/auth/login_screen.dart';
import 'package:aerosense_app/features/dashboard/dashboard_screen.dart';
import 'package:aerosense_app/features/forecast/forecast_screen.dart';
import 'package:aerosense_app/features/history/history_screen.dart';
import 'package:aerosense_app/features/settings/settings_screen.dart';

class _AlwaysDemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

void main() {
  const testSizes = [
    Size(360, 640), // Small mobile
    Size(768, 1024), // Tablet
    Size(1280, 800), // Desktop / Web
  ];

  Widget buildApp(Widget screen, {double textScale = 1.0}) {
    return ProviderScope(
      overrides: [
        demoModeProvider.overrideWith(() => _AlwaysDemoNotifier()),
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        systemRepositoryProvider.overrideWithValue(
          FakeSystemRepository(clock: () => DateTime(2026, 11, 10, 8, 30)),
        ),
        historyRepositoryProvider.overrideWithValue(
          FakeHistoryRepository(anchor: DateTime(2026, 11, 10, 8, 30)),
        ),
        systemStateProvider.overrideWith(
          (_) => Stream.value(
            const SystemState(
              tier: Tier.medium,
              statusMessage: 'Room is getting stuffy',
              temperature: 28.5,
              humidity: 62.0,
              airQuality: 1100.0,
              fanOn: true,
              manualToggle: true,
            ),
          ),
        ),
        connectedProvider.overrideWith((_) => Stream.value(true)),
      ],
      child: MaterialApp(
        theme: AeroSenseTheme.light,
        builder: (context, child) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          );
        },
        home: screen,
      ),
    );
  }

  group('Responsive and text-scale layout audit (no overflow)', () {
    for (final size in testSizes) {
      final label = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('Dashboard renders cleanly at $label (textScale 1.3)', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildApp(const DashboardScreen(), textScale: 1.3),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(DashboardScreen), findsOneWidget);
      });

      testWidgets('History renders cleanly at $label (textScale 1.3)', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildApp(const HistoryScreen(), textScale: 1.3),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(HistoryScreen), findsOneWidget);
      });

      testWidgets('Forecast renders cleanly at $label (textScale 1.3)', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildApp(const ForecastScreen(), textScale: 1.3),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(ForecastScreen), findsOneWidget);
      });

      testWidgets('Settings renders cleanly at $label (textScale 1.3)', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          buildApp(const SettingsScreen(), textScale: 1.3),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(SettingsScreen), findsOneWidget);
      });

      testWidgets('Login renders cleanly at $label (textScale 1.3)', (
        tester,
      ) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(buildApp(const LoginScreen(), textScale: 1.3));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(LoginScreen), findsOneWidget);
      });
    }
  });
}
