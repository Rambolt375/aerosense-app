import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/app.dart';
import 'package:aerosense_app/data/repositories/fake_auth_repository.dart';
import 'package:aerosense_app/data/repositories/fake_history_repository.dart';
import 'package:aerosense_app/data/repositories/fake_system_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_screen.dart';

class _AlwaysDemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

void main() {
  testWidgets('/assistant is a top-level route without the bottom navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoModeProvider.overrideWith(() => _AlwaysDemoNotifier()),
          authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
          systemRepositoryProvider.overrideWithValue(FakeSystemRepository()),
          historyRepositoryProvider.overrideWithValue(FakeHistoryRepository()),
        ],
        child: const AeroSenseApp(),
      ),
    );
    await tester.pumpAndSettle();

    final router = ProviderScope.containerOf(
      tester.element(find.byType(AeroSenseApp)),
    ).read(routerProvider);
    router.go('/assistant');
    await tester.pumpAndSettle();

    expect(find.byType(AssistantScreen), findsOneWidget);
    expect(find.byType(NavigationBar), findsNothing);
    expect(find.byType(NavigationRail), findsNothing);
  });
}
