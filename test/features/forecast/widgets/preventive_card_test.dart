import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';
import 'package:aerosense_app/data/models/forecast_preferences.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/forecast/preventive_decision.dart';
import 'package:aerosense_app/features/forecast/preventive_providers.dart';
import 'package:aerosense_app/features/forecast/widgets/preventive_card.dart';

class _ThrowingSystemRepository extends FakeSystemRepository {
  @override
  Future<void> requestPreventiveTrigger() async {
    throw Exception('Permission denied');
  }
}

class _MockPreventiveDecisionNotifier extends PreventiveDecisionNotifier {
  _MockPreventiveDecisionNotifier(this._decision);
  final PreventiveDecision _decision;

  @override
  PreventiveDecision build() => _decision;
}

class _MockDeviceStatusNotifier extends DeviceStatusNotifier {
  _MockDeviceStatusNotifier(this._status);
  final DeviceStatus _status;

  @override
  DeviceStatus build() => _status;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildTestCard({
    bool isTeam = true,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
        historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        isTeamAccountProvider.overrideWithValue(isTeam),
        ...overrides,
      ],
      child: MaterialApp(
        theme: AeroSenseTheme.light,
        home: const Scaffold(
          body: Padding(
            padding: EdgeInsets.all(16),
            child: PreVentilationCard(),
          ),
        ),
      ),
    );
  }

  group('PreVentilationCard Widget Tests', () {
    testWidgets('renders Off status when allowPreventive is false', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeRepo = FakeSystemRepository();

      await tester.pumpWidget(
        buildTestCard(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            systemRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pre-Ventilation'), findsOneWidget);
      expect(find.text('Off'), findsOneWidget);
      expect(
        find.text('Automated pre-ventilation is turned off in Settings.'),
        findsOneWidget,
      );

      // Button is disabled with visible reason
      final button = find.widgetWithText(
        OutlinedButton,
        'Run pre-ventilation now (demo)',
      );
      expect(button, findsOneWidget);
      final outlinedButton = tester.widget<OutlinedButton>(button);
      expect(outlinedButton.onPressed, isNull);
      expect(
        find.text('Button unavailable: Disabled in Settings'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      fakeRepo.dispose();
    });

    testWidgets('renders Armed status with planned run and peak times', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeRepo = FakeSystemRepository();
      await fakeRepo.setAllowPreventive(true);

      final peakTime = DateTime(2026, 11, 15, 14, 0);
      final plannedTime = DateTime(2026, 11, 15, 13, 45);

      final decision = PreventiveDecision(
        canTrigger: true,
        uiState: PreventiveUiState.armed,
        nextPeakTime: peakTime,
        nextPlannedRunTime: plannedTime,
        predictedPeakValue: 1500,
      );

      await tester.pumpWidget(
        buildTestCard(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            systemRepositoryProvider.overrideWithValue(fakeRepo),
            preventiveDecisionProvider.overrideWith(
              () => _MockPreventiveDecisionNotifier(decision),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Armed'), findsOneWidget);
      expect(find.textContaining('Next run planned for'), findsOneWidget);

      // Demo button is enabled
      final button = find.widgetWithText(
        OutlinedButton,
        'Run pre-ventilation now (demo)',
      );
      expect(button, findsOneWidget);
      final outlinedButton = tester.widget<OutlinedButton>(button);
      expect(outlinedButton.onPressed, isNotNull);

      await tester.pumpWidget(const SizedBox());
      fakeRepo.dispose();
    });

    testWidgets('renders Running status when pre-ventilation is running', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeRepo = FakeSystemRepository();
      await fakeRepo.setAllowPreventive(true);

      const decision = PreventiveDecision(
        canTrigger: false,
        uiState: PreventiveUiState.running,
        reason: 'Pre-ventilation in progress',
      );

      await tester.pumpWidget(
        buildTestCard(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            systemRepositoryProvider.overrideWithValue(fakeRepo),
            preventiveDecisionProvider.overrideWith(
              () => _MockPreventiveDecisionNotifier(decision),
            ),
            systemStateProvider.overrideWith(
              (ref) => Stream.value(
                const SystemState(
                  tier: Tier.safe,
                  fanOn: true,
                  temperature: 24,
                  humidity: 50,
                  airQuality: 100,
                ),
              ),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Running'), findsOneWidget);
      expect(
        find.text('Pre-ventilation cycle is running (fixed duration).'),
        findsOneWidget,
      );

      // Demo button is disabled because run is active
      final button = find.widgetWithText(
        OutlinedButton,
        'Run pre-ventilation now (demo)',
      );
      final outlinedButton = tester.widget<OutlinedButton>(button);
      expect(outlinedButton.onPressed, isNull);
      expect(
        find.text(
          'Button unavailable: Ventilation cycle is already in progress',
        ),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      fakeRepo.dispose();
    });

    testWidgets(
      'Running state triggered by preventiveTrigger=true (real firmware: trigger stays true for whole run)',
      (tester) async {
        // Real firmware keeps preventiveTrigger=true for the entire run duration.
        // The card must show Running and disable the button when trigger=true,
        // regardless of whether the fan state has updated yet.
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = FakeSystemRepository();
        await fakeRepo.setAllowPreventive(true);

        const decision = PreventiveDecision(
          canTrigger: false,
          uiState: PreventiveUiState.running,
          reason: 'Pre-ventilation in progress',
        );

        await tester.pumpWidget(
          buildTestCard(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              systemRepositoryProvider.overrideWithValue(fakeRepo),
              preventiveDecisionProvider.overrideWith(
                () => _MockPreventiveDecisionNotifier(decision),
              ),
              // preventiveTrigger=true, fan still off (brief race window on real hardware)
              forecastPreferencesProvider.overrideWith(
                (ref) => Stream.value(
                  const ForecastPreferences(
                    allowPreventive: true,
                    preventiveTrigger: true,
                  ),
                ),
              ),
              systemStateProvider.overrideWith(
                (ref) => Stream.value(
                  const SystemState(
                    tier: Tier.safe,
                    fanOn: false,
                    temperature: 24,
                    humidity: 50,
                    airQuality: 100,
                  ),
                ),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Running'), findsOneWidget);

        // Button disabled because isTriggerActive is true
        final button = find.widgetWithText(
          OutlinedButton,
          'Run pre-ventilation now (demo)',
        );
        final outlinedButton = tester.widget<OutlinedButton>(button);
        expect(outlinedButton.onPressed, isNull);
        expect(
          find.text(
            'Button unavailable: Ventilation cycle is already in progress',
          ),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        fakeRepo.dispose();
      },
    );

    testWidgets(
      'renders Unavailable status with reason when offline or safety override',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final fakeRepo = FakeSystemRepository();
        await fakeRepo.setAllowPreventive(true);

        const decision = PreventiveDecision(
          canTrigger: false,
          uiState: PreventiveUiState.unavailable,
          reason: 'Device is offline',
        );

        await tester.pumpWidget(
          buildTestCard(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              systemRepositoryProvider.overrideWithValue(fakeRepo),
              deviceStatusProvider.overrideWith(
                () => _MockDeviceStatusNotifier(
                  const DeviceStatus(status: DeviceOnlineStatus.offline),
                ),
              ),
              preventiveDecisionProvider.overrideWith(
                () => _MockPreventiveDecisionNotifier(decision),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Unavailable'), findsOneWidget);
        expect(find.text('Unavailable: Device is offline'), findsOneWidget);
        expect(
          find.text('Button unavailable: Device is offline'),
          findsOneWidget,
        );

        await tester.pumpWidget(const SizedBox());
        fakeRepo.dispose();
      },
    );

    testWidgets('hides demo run section for non-team visitor accounts', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fakeRepo = FakeSystemRepository();

      await tester.pumpWidget(
        buildTestCard(
          isTeam: false,
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            systemRepositoryProvider.overrideWithValue(fakeRepo),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Run pre-ventilation now (demo)'), findsNothing);

      await tester.pumpWidget(const SizedBox());
      fakeRepo.dispose();
    });

    testWidgets(
      'shows snackbar when request fails with network or permission error',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final throwingRepo = _ThrowingSystemRepository();
        await throwingRepo.setAllowPreventive(true);

        const decision = PreventiveDecision(
          canTrigger: false,
          uiState: PreventiveUiState.armed,
        );

        await tester.pumpWidget(
          buildTestCard(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              systemRepositoryProvider.overrideWithValue(throwingRepo),
              preventiveDecisionProvider.overrideWith(
                () => _MockPreventiveDecisionNotifier(decision),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        final button = find.widgetWithText(
          OutlinedButton,
          'Run pre-ventilation now (demo)',
        );
        expect(button, findsOneWidget);
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.text('Could not send the request'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        throwingRepo.dispose();
      },
    );
  });
}
