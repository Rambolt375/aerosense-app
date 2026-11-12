import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/settings/settings_screen.dart';

class _MockSignOutAuthRepository implements AuthRepository {
  bool signOutCalled = false;

  @override
  Stream<User?> authStateChanges() => Stream.value(null);

  @override
  User? get currentUser => null;

  @override
  Future<void> signIn({
    required String email,
    required String password,
  }) async {}

  @override
  Future<void> signOut() async {
    signOutCalled = true;
  }
}

class _TestDemoNotifier extends DemoModeNotifier {
  _TestDemoNotifier(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget buildSettings({required ProviderContainer container}) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: SettingsScreen()),
    );
  }

  group('SettingsScreen Widget Tests', () {
    testWidgets('renders all sections and read-only values in live mode', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          demoModeProvider.overrideWith(() => _TestDemoNotifier(false)),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildSettings(container: container));
      await tester.pumpAndSettle();

      // Appearance
      expect(find.text('Appearance'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Light'), findsOneWidget);
      expect(find.text('Dark'), findsOneWidget);

      // Demo Mode Switch (off)
      expect(find.text('Demo Mode'), findsOneWidget);
      expect(find.text('Run the demo'), findsNothing);

      // Thresholds Source Label
      expect(find.text('Source: built-in (firmware defaults)'), findsOneWidget);
      expect(
        find.text(
          'The ESP32 firmware is the sole authority for safety thresholds and fan actuation. These values are read-only.',
        ),
        findsOneWidget,
      );

      // Interpolated Threshold Values
      expect(find.text('< ${Thresholds.tempCautionMin} °C'), findsOneWidget);
      expect(find.text('>= ${Thresholds.tempDangerMin} °C'), findsOneWidget);
      expect(
        find.text('< ${Thresholds.airQualityCautionMin.toInt()}'),
        findsOneWidget,
      );
      expect(
        find.text('>= ${Thresholds.airQualityDangerMin.toInt()}'),
        findsOneWidget,
      );

      // Humidity caveat text
      expect(find.text('Not yet confirmed in the firmware'), findsOneWidget);

      // Forecast Parameters
      expect(find.text('Forecast Parameters'), findsOneWidget);
      expect(find.text('${AppConfig.forecastSigmaMultiplier}'), findsOneWidget);
      expect(
        find.text('${AppConfig.minForecastSpanHours} hours'),
        findsOneWidget,
      );
      expect(find.text('${AppConfig.minHourlyBins} / 24 bins'), findsOneWidget);

      // Application info
      expect(find.text(AppConfig.appVersion), findsOneWidget);
      expect(find.text('asia-southeast1'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets(
      'shows Demo preset source label and Run the demo when demo mode is active',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();

        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            demoModeProvider.overrideWith(() => _TestDemoNotifier(true)),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(buildSettings(container: container));
        await tester.pumpAndSettle();

        expect(find.text('Demo preset'), findsOneWidget);
        expect(find.text('Run the demo'), findsOneWidget);
        expect(find.text('Simulate Kitchen Smoke'), findsOneWidget);
        expect(find.text('Simulate Heat Spike'), findsOneWidget);
        expect(find.text('Simulate Sensor Unplugged'), findsOneWidget);
        expect(find.text('Reset to Baseline'), findsOneWidget);
        expect(
          find.text(
            'Simulates sensor unplugged where the sensor stops reporting, displaying "--" in the dashboard, then recovers.',
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('theme selection switches themeModeProvider', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildSettings(container: container));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), equals(ThemeMode.system));

      // Select Dark
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), equals(ThemeMode.dark));
      expect(prefs.getString('theme_mode'), equals('dark'));
    });

    testWidgets('sign out opens confirmation dialog and signs out', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final mockAuth = _MockSignOutAuthRepository();

      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          authRepositoryProvider.overrideWithValue(mockAuth),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(buildSettings(container: container));
      await tester.pumpAndSettle();

      final signOutBtn = find.text('Sign out');
      await tester.ensureVisible(signOutBtn);
      await tester.pumpAndSettle();
      await tester.tap(signOutBtn);
      await tester.pumpAndSettle();

      // Dialog is open
      expect(
        find.text('Are you sure you want to sign out of AeroSense?'),
        findsOneWidget,
      );

      // Confirm sign out in dialog
      final confirmBtn = find.widgetWithText(FilledButton, 'Sign out');
      await tester.tap(confirmBtn);
      await tester.pumpAndSettle();

      expect(mockAuth.signOutCalled, isTrue);
    });
  });
}
