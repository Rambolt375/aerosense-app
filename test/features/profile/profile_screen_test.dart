import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/repositories/auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/profile/profile_screen.dart';
import 'package:aerosense_app/shared/account_avatar.dart';

import '../../support/test_auth_repository.dart';

class _AlwaysDemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget harness(ProviderContainer container) {
    return UncontrolledProviderScope(
      container: container,
      child: const MaterialApp(home: ProfileScreen()),
    );
  }

  Future<ProviderContainer> pumpProfile(
    WidgetTester tester, {
    required AuthRepository auth,
    bool demo = false,
  }) async {
    tester.view.physicalSize = const Size(420, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(auth),
        if (demo) demoModeProvider.overrideWith(() => _AlwaysDemoNotifier()),
      ],
    );
    addTearDown(container.dispose);
    if (auth is TestAuthRepository) addTearDown(auth.dispose);
    if (auth is FakeAuthRepository) addTearDown(auth.dispose);

    await tester.pumpWidget(harness(container));
    await tester.pumpAndSettle();
    return container;
  }

  group('ProfileScreen account summary', () {
    testWidgets(
      'shows avatar initial, name, read-only email and provider chip',
      (tester) async {
        await pumpProfile(tester, auth: TestAuthRepository());

        expect(
          find.descendant(
            of: find.byType(AccountAvatar),
            matching: find.text('A'),
          ),
          findsOneWidget,
        );
        expect(find.text('Alice Visitor'), findsOneWidget);
        expect(find.text('alice@example.com'), findsOneWidget);
        expect(find.text(AppStrings.profileUidLabel), findsOneWidget);
        expect(find.text('test-uid'), findsOneWidget);
        expect(find.text(AppStrings.providerGoogle), findsOneWidget);
        expect(find.text(AppStrings.profileCaption), findsOneWidget);
        expect(find.text(AppStrings.profileEditName), findsOneWidget);
        expect(find.text(AppStrings.signOut), findsOneWidget);

        // Top-level route: no bottom navigation, and only the name is editable.
        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(TextField), findsNothing);
      },
    );

    testWidgets('labels a team account', (tester) async {
      await pumpProfile(
        tester,
        auth: TestAuthRepository(
          user: TestAuthUser(
            displayName: 'Budi',
            email: 'budi@aerosense.local',
            providerId: null,
          ),
        ),
      );

      expect(find.text(AppStrings.providerTeam), findsOneWidget);
      expect(find.text('Budi'), findsOneWidget);
    });

    testWidgets('falls back to the initial when the photo cannot load', (
      tester,
    ) async {
      await pumpProfile(
        tester,
        auth: TestAuthRepository(
          user: TestAuthUser(
            displayName: 'Carol Danvers',
            email: 'carol@example.com',
            photoURL: 'https://example.invalid/carol-${DateTime.now()}.png',
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Image.network cannot resolve in tests, so the error builder must have
      // replaced the photo with the initial instead of an error box.
      expect(tester.takeException(), isNull);
      expect(
        find.descendant(
          of: find.byType(AccountAvatar),
          matching: find.text('C'),
        ),
        findsOneWidget,
      );
    });
  });

  group('Inline name editing', () {
    testWidgets('saves a cleaned name and confirms with a snackbar', (
      tester,
    ) async {
      final auth = TestAuthRepository();
      await pumpProfile(tester, auth: auth);

      await tester.tap(find.text(AppStrings.profileEditName));
      await tester.pumpAndSettle();
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '  Bob   Builder ');
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.profileSave),
      );
      await tester.pumpAndSettle();

      expect(auth.lastUpdateAttempt, 'Bob Builder');
      expect(find.text('Bob Builder'), findsOneWidget);
      expect(find.text(AppStrings.profileNameSaved), findsOneWidget);
      expect(find.byType(TextField), findsNothing);
      expect(
        find.descendant(
          of: find.byType(AccountAvatar),
          matching: find.text('B'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('rejects an empty name without calling the repository', (
      tester,
    ) async {
      final auth = TestAuthRepository();
      await pumpProfile(tester, auth: auth);

      await tester.tap(find.text(AppStrings.profileEditName));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '   ');
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.profileSave),
      );
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.profileNameInvalid), findsOneWidget);
      expect(auth.updateCalls, 0);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('shows the friendly error when the save fails', (tester) async {
      final auth = TestAuthRepository()
        ..failure = const AuthFailure(AppStrings.profileNameSaveFailed);
      await pumpProfile(tester, auth: auth);

      await tester.tap(find.text(AppStrings.profileEditName));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'New Name');
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.profileSave),
      );
      await tester.pumpAndSettle();

      expect(auth.updateCalls, 1);
      expect(find.text(AppStrings.profileNameSaveFailed), findsOneWidget);
      // The editor stays open so the visitor can retry.
      expect(find.byType(TextField), findsOneWidget);
      expect(find.text('Alice Visitor'), findsOneWidget);
    });

    testWidgets('cancel discards the edit', (tester) async {
      final auth = TestAuthRepository();
      await pumpProfile(tester, auth: auth);

      await tester.tap(find.text(AppStrings.profileEditName));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Discarded');
      await tester.tap(find.text(AppStrings.profileCancel));
      await tester.pumpAndSettle();

      expect(find.byType(TextField), findsNothing);
      expect(find.text('Alice Visitor'), findsOneWidget);
      expect(auth.updateCalls, 0);
    });
  });

  group('Demo Mode', () {
    testWidgets('shows the Demo chip and labels edits as not saved', (
      tester,
    ) async {
      await pumpProfile(tester, auth: FakeAuthRepository(), demo: true);

      expect(find.text(AppStrings.providerDemo), findsOneWidget);
      expect(find.text(AppStrings.profileDemoNotSaved), findsOneWidget);
      expect(find.text('Demo User'), findsOneWidget);
      expect(find.text('demo-uid'), findsOneWidget);
    });

    testWidgets('edits the fake profile in memory only', (tester) async {
      await pumpProfile(tester, auth: FakeAuthRepository(), demo: true);

      await tester.tap(find.text(AppStrings.profileEditName));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Booth Helper');
      await tester.tap(
        find.widgetWithText(FilledButton, AppStrings.profileSave),
      );
      await tester.pumpAndSettle();

      expect(find.text('Booth Helper'), findsOneWidget);
      expect(find.text(AppStrings.profileNameSaved), findsOneWidget);
      expect(find.text(AppStrings.profileDemoNotSaved), findsOneWidget);
    });
  });

  group('Sign out', () {
    testWidgets('asks for confirmation before signing out', (tester) async {
      final auth = TestAuthRepository();
      await pumpProfile(tester, auth: auth);

      await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.signOut));
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.signOutConfirm), findsOneWidget);

      await tester.tap(find.text(AppStrings.profileCancel));
      await tester.pumpAndSettle();
      expect(auth.signOutCalled, isFalse);

      await tester.tap(find.widgetWithText(OutlinedButton, AppStrings.signOut));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, AppStrings.signOut));
      await tester.pumpAndSettle();
      expect(auth.signOutCalled, isTrue);
    });
  });
}
