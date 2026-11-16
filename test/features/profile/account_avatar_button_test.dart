import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/app.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_screen.dart';
import 'package:aerosense_app/features/dashboard/dashboard_screen.dart';
import 'package:aerosense_app/features/forecast/forecast_screen.dart';
import 'package:aerosense_app/features/history/history_screen.dart';
import 'package:aerosense_app/features/profile/profile_screen.dart';
import 'package:aerosense_app/features/settings/settings_screen.dart';
import 'package:aerosense_app/shared/account_avatar.dart';
import 'package:aerosense_app/shared/account_avatar_button.dart';

import '../../support/test_auth_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<TestAuthRepository> pumpApp(
    WidgetTester tester, {
    Size size = const Size(420, 900),
    TestAuthRepository? auth,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = auth ?? TestAuthRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(repository),
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        ],
        child: const AeroSenseApp(),
      ),
    );
    await tester.pumpAndSettle();
    return repository;
  }

  Future<void> openMenu(WidgetTester tester) async {
    await tester.tap(find.byType(AccountAvatarButton));
    await tester.pumpAndSettle();
  }

  group('Account avatar in the shell app bar', () {
    testWidgets('shows the display name in the tooltip and a 48 dp target', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();

      await pumpApp(tester);

      expect(find.bySemanticsLabel(AppStrings.accountMenu), findsOneWidget);
      expect(find.byTooltip('Alice Visitor'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AccountAvatarButton),
          matching: find.text('A'),
        ),
        findsOneWidget,
      );
      expect(
        tester.getSize(
          find
              .ancestor(
                of: find.byType(AccountAvatar),
                matching: find.byType(SizedBox),
              )
              .first,
        ),
        const Size(48, 48),
      );
      expect(tester.getSize(find.byType(AccountAvatar)).width, 40);

      semantics.dispose();
    });

    testWidgets('offers exactly two menu items', (tester) async {
      await pumpApp(tester);
      await openMenu(tester);

      expect(find.byType(PopupMenuItem<AccountMenuAction>), findsNWidgets(2));
      expect(find.text(AppStrings.profileTitle), findsOneWidget);
      expect(find.text(AppStrings.signOut), findsOneWidget);
    });

    testWidgets('opens below the avatar without covering it', (tester) async {
      await pumpApp(tester);

      final avatarBottom = tester
          .getBottomRight(find.byType(AccountAvatarButton))
          .dy;
      await openMenu(tester);

      expect(
        tester.getTopLeft(find.text(AppStrings.profileTitle)).dy,
        greaterThanOrEqualTo(avatarBottom),
      );
    });

    testWidgets('appears on all four tabs', (tester) async {
      await pumpApp(tester);

      expect(find.byType(AccountAvatarButton), findsOneWidget);
      expect(find.byType(DashboardScreen), findsOneWidget);

      for (final (label, screen) in [
        ('History', HistoryScreen),
        ('Forecast', ForecastScreen),
        ('Settings', SettingsScreen),
      ]) {
        await tester.tap(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(label),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.byType(screen), findsOneWidget);
        expect(find.byType(AccountAvatarButton), findsOneWidget);
      }
    });

    testWidgets('appears in the wide NavigationRail layout', (tester) async {
      await pumpApp(tester, size: const Size(1280, 900));

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(find.byType(AccountAvatarButton), findsOneWidget);
    });

    testWidgets('is hidden on the login screen', (tester) async {
      await pumpApp(tester, auth: TestAuthRepository.signedOut());

      expect(find.text('Adaptive Ventilation Companion'), findsOneWidget);
      expect(find.byType(AccountAvatarButton), findsNothing);
    });

    testWidgets('is hidden on /profile and /assistant', (tester) async {
      await pumpApp(tester);

      final router = ProviderScope.containerOf(
        tester.element(find.byType(AeroSenseApp)),
      ).read(routerProvider);

      router.go('/profile');
      await tester.pumpAndSettle();
      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.byType(AccountAvatarButton), findsNothing);
      expect(find.byType(NavigationBar), findsNothing);

      router.go('/assistant');
      await tester.pumpAndSettle();
      expect(find.byType(AssistantScreen), findsOneWidget);
      expect(find.byType(AccountAvatarButton), findsNothing);
    });
  });

  group('Account menu actions', () {
    testWidgets('Profile opens the profile page', (tester) async {
      await pumpApp(tester);
      await openMenu(tester);

      await tester.tap(find.text(AppStrings.profileTitle));
      await tester.pumpAndSettle();

      expect(find.byType(ProfileScreen), findsOneWidget);
      expect(find.text('Alice Visitor'), findsOneWidget);
      expect(find.text('alice@example.com'), findsOneWidget);
    });

    testWidgets('Sign out asks for confirmation', (tester) async {
      final auth = await pumpApp(tester);
      await openMenu(tester);

      await tester.tap(find.text(AppStrings.signOut));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.signOutConfirm), findsOneWidget);

      await tester.tap(find.text(AppStrings.profileCancel));
      await tester.pumpAndSettle();
      expect(auth.signOutCalled, isFalse);

      await openMenu(tester);
      await tester.tap(find.text(AppStrings.signOut));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.signOut));
      await tester.pumpAndSettle();
      expect(auth.signOutCalled, isTrue);
    });

    testWidgets('avatar updates immediately after a name change', (
      tester,
    ) async {
      await pumpApp(tester);

      await openMenu(tester);
      await tester.tap(find.text(AppStrings.profileTitle));
      await tester.pumpAndSettle();

      await tester.tap(find.text(AppStrings.profileEditName));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Zed');
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.profileSave),
      );
      await tester.pumpAndSettle();

      await tester.pageBack();
      await tester.pumpAndSettle();

      expect(find.byType(DashboardScreen), findsOneWidget);
      expect(find.byTooltip('Zed'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AccountAvatarButton),
          matching: find.text('Z'),
        ),
        findsOneWidget,
      );
    });
  });
}
