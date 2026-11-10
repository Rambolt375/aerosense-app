import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/forecast_screen.dart';
import 'package:aerosense_app/features/forecast/residual_gate.dart';
import 'package:aerosense_app/features/forecast/robust_diurnal_fitter.dart';
import 'package:aerosense_app/features/forecast/sinusoidal_fit.dart';
import 'package:aerosense_app/features/forecast/widgets/forecast_status_card.dart';

void main() {
  Widget buildTestApp({List<dynamic> overrides = const []}) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        systemRepositoryProvider.overrideWithValue(
          FakeSystemRepository(clock: () => DateTime(2026, 11, 10, 8, 30)),
        ),
        historyRepositoryProvider.overrideWithValue(
          FakeHistoryRepository(anchor: DateTime(2026, 11, 10, 8, 30)),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AeroSenseTheme.light,
        home: const ForecastScreen(),
      ),
    );
  }

  group('ForecastScreen & ForecastStatusCard Widget Tests', () {
    testWidgets(
      'renders ForecastScreen with ForecastStatusCard and model cards',
      (tester) async {
        await tester.pumpWidget(buildTestApp());
        await tester.pumpAndSettle();

        expect(find.text('Diurnal Forecast'), findsOneWidget);
        expect(find.byType(ForecastStatusCard), findsOneWidget);
        expect(find.text('Temperature model'), findsOneWidget);
        expect(find.text('Air quality model'), findsOneWidget);
        expect(find.text('Forecast status'), findsOneWidget);
      },
    );

    testWidgets('displays Locked out explanation copy when gate is lockedOut', (
      tester,
    ) async {
      final lockedGate = ForecastGate(
        tempModel: DiurnalModel(
          coefficients: const DiurnalCoefficients(
            a: 2.0,
            b: 2.0,
            c: 25.0,
            amplitude: 2.83,
            phase: 0.78,
            peakSeconds: 54000.0,
          ),
          residualStdDev: 0.3,
          effectiveThreshold: 0.9,
          hasClearDailyPattern: true,
        ),
        aqModel: DiurnalModel(
          coefficients: const DiurnalCoefficients(
            a: 100.0,
            b: 100.0,
            c: 700.0,
            amplitude: 141.4,
            phase: 0.78,
            peakSeconds: 64800.0,
          ),
          residualStdDev: 20.0,
          effectiveThreshold: 60.0,
          hasClearDailyPattern: true,
        ),
      );

      await tester.pumpWidget(
        buildTestApp(
          overrides: [
            forecastGateNotifierProvider.overrideWith(
              () => _TestForecastGateNotifier(lockedGate),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Locked out'), findsWidgets);
      expect(
        find.text(
          'Predictive layer locked out. Deterministic safety logic in control.',
        ),
        findsOneWidget,
      );
    });

    testWidgets(
      'displays predicted peak times when models have clear daily patterns',
      (tester) async {
        final activeGate = ForecastGate(
          tempModel: DiurnalModel(
            coefficients: const DiurnalCoefficients(
              a: 0.0,
              b: 4.5,
              c: 25.0,
              amplitude: 4.5,
              phase: 1.57,
              peakSeconds: 54000.0, // 15:00
            ),
            residualStdDev: 0.2,
            effectiveThreshold: 0.6,
            hasClearDailyPattern: true,
          ),
          aqModel: DiurnalModel(
            coefficients: const DiurnalCoefficients(
              a: 0.0,
              b: 180.0,
              c: 750.0,
              amplitude: 180.0,
              phase: 1.57,
              peakSeconds: 64800.0, // 18:00
            ),
            residualStdDev: 25.0,
            effectiveThreshold: 75.0,
            hasClearDailyPattern: true,
          ),
        );
        // Advance gate to active
        activeGate.tempGate.status = MetricGateStatus.active;
        activeGate.aqGate.status = MetricGateStatus.active;

        final fitState = DiurnalFitState(
          temperatureResult: DiurnalFitResult(
            status: DiurnalFitStatus.ready,
            model: activeGate.tempGate.model,
          ),
          airQualityResult: DiurnalFitResult(
            status: DiurnalFitStatus.ready,
            model: activeGate.aqGate.model,
          ),
        );

        await tester.pumpWidget(
          buildTestApp(
            overrides: [
              diurnalFitProvider.overrideWithValue(fitState),
              forecastGateNotifierProvider.overrideWith(
                () => _TestForecastGateNotifier(activeGate),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Active'), findsWidgets);
        expect(
          find.textContaining('Predicted temperature peak: ~15:00'),
          findsOneWidget,
        );
        expect(
          find.textContaining('Predicted air quality peak: ~18:00'),
          findsOneWidget,
        );
      },
    );
  });
}

class _TestForecastGateNotifier extends ForecastGateNotifier {
  _TestForecastGateNotifier(this._initialGate);

  final ForecastGate _initialGate;

  @override
  ForecastGate build() => _initialGate;
}
