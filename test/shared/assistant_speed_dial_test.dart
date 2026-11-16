import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/app.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';
import 'package:aerosense_app/features/assistant/assistant_screen.dart';
import 'package:aerosense_app/features/summary/widgets/summary_sheet.dart';
import 'package:aerosense_app/shared/account_avatar_button.dart';
import 'package:aerosense_app/shared/assistant_speed_dial.dart';

import '../support/test_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpApp(
    WidgetTester tester, {
    bool assistantEnabled = false,
    bool demo = false,
    FakeViewPadding viewInsets = const FakeViewPadding(),
  }) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.view.viewInsets = viewInsets;
    addTearDown(tester.view.reset);

    final auth = TestAuthRepository();
    addTearDown(auth.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
          geminiApiKeyProvider.overrideWithValue(
            assistantEnabled ? 'test-key' : '',
          ),
          if (demo) demoModeProvider.overrideWith(_DemoModeNotifier.new),
        ],
        child: const AeroSenseApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  group('AssistantSpeedDial', () {
    testWidgets('runs the only available action without expanding', (
      tester,
    ) async {
      await pumpApp(tester);

      expect(find.byType(AssistantSpeedDial), findsOneWidget);
      expect(find.byTooltip(AppStrings.assistantMenu), findsOneWidget);

      await tester.tap(find.byTooltip(AppStrings.assistantMenu));
      await tester.pumpAndSettle();

      expect(find.byType(SummarySheet), findsOneWidget);
      expect(find.text(AppStrings.askAeroSense), findsNothing);
    });

    testWidgets(
      'expands to Summarize and Ask when the assistant is available',
      (tester) async {
        await pumpApp(tester, assistantEnabled: true);

        await tester.tap(find.byTooltip(AppStrings.assistantMenu));
        await tester.pumpAndSettle();

        expect(find.text(AppStrings.summarize), findsOneWidget);
        expect(find.text(AppStrings.askAeroSense), findsOneWidget);
      },
    );

    testWidgets('uses the scripted Ask label in Demo Mode', (tester) async {
      await pumpApp(tester, demo: true);

      await tester.tap(find.byTooltip(AppStrings.assistantMenu));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.askAeroSenseScripted), findsOneWidget);
    });

    testWidgets('opens the assistant after collapsing the dial', (
      tester,
    ) async {
      await pumpApp(tester, assistantEnabled: true);

      await tester.tap(find.byTooltip(AppStrings.assistantMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(AppStrings.askAeroSense));
      await tester.pumpAndSettle();

      expect(find.byType(AssistantScreen), findsOneWidget);
      expect(find.byType(AssistantSpeedDial), findsNothing);
    });

    testWidgets('is hidden while a soft keyboard is open', (tester) async {
      await pumpApp(tester, viewInsets: const FakeViewPadding(bottom: 320));

      expect(find.byType(AssistantSpeedDial), findsNothing);
    });

    testWidgets('is hidden with the keyboard open on every tab', (
      tester,
    ) async {
      await pumpApp(tester, assistantEnabled: true);
      expect(find.byType(AssistantSpeedDial), findsOneWidget);

      // Open the keyboard after the shell is built, as a real text field would.
      tester.view.viewInsets = const FakeViewPadding(bottom: 320);
      addTearDown(tester.view.reset);
      await tester.pumpAndSettle();

      for (final label in ['History', 'Forecast', 'Settings', 'Dashboard']) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.byType(AssistantSpeedDial),
          findsNothing,
          reason: 'dial must stay hidden on $label while the keyboard is open',
        );
      }

      // Closing the keyboard brings it back.
      tester.view.viewInsets = FakeViewPadding.zero;
      await tester.pumpAndSettle();
      expect(find.byType(AssistantSpeedDial), findsOneWidget);
    });

    testWidgets('does not overlap the account menu at 360 dp', (tester) async {
      await pumpApp(tester, assistantEnabled: true);

      await tester.tap(find.byTooltip(AppStrings.assistantMenu));
      await tester.pumpAndSettle();
      final askRect = tester.getRect(find.text(AppStrings.askAeroSense));

      await tester.tap(find.byType(AccountAvatarButton));
      await tester.pumpAndSettle();

      expect(
        askRect.overlaps(tester.getRect(find.text(AppStrings.profileTitle))),
        isFalse,
      );
      expect(find.text(AppStrings.profileTitle), findsOneWidget);
      expect(find.text(AppStrings.askAeroSense), findsNothing);
    });

    testWidgets('Escape collapses the expanded dial', (tester) async {
      await pumpApp(tester, assistantEnabled: true);

      await tester.tap(find.byTooltip(AppStrings.assistantMenu));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.summarize), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.summarize), findsNothing);
    });

    testWidgets('keeps a floating SnackBar fully on screen with the dial', (
      tester,
    ) async {
      await pumpApp(tester, assistantEnabled: true);
      final context = tester.element(find.byType(AssistantSpeedDial));

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Debug notice'),
        ),
      );
      await tester.pumpAndSettle();

      final snackBar = tester.getRect(find.byType(SnackBar));
      final dial = tester.getRect(find.byType(AssistantSpeedDial));
      expect(snackBar.top, greaterThanOrEqualTo(0));
      expect(snackBar.bottom, lessThanOrEqualTo(800));
      expect(snackBar.overlaps(dial), isFalse);
      expect(find.byType(AssistantSpeedDial), findsOneWidget);
    });
  });
}

class _DemoModeNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}
