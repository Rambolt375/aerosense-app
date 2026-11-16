import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/widgets/ask_about_room_card.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

class _AlwaysDemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

void main() {
  final input = SummaryInput(
    state: const SystemState(
      temperature: 34.1,
      humidity: 58,
      airQuality: 1520,
      statusMessage: 'CAUTION',
      tier: Tier.medium,
    ),
    thresholds: ThresholdPreset.firmware,
    device: const DeviceSummary(state: DeviceSummaryState.online),
    forecast: const ForecastSummary(status: ForecastSummaryStatus.active),
    history: const HistoryStats24h(sampleCount: 143),
    language: SummaryLanguage.en,
    now: DateTime(2026, 11, 15, 14, 10),
  );

  Widget harness({bool demo = false}) {
    return ProviderScope(
      overrides: [
        if (demo) demoModeProvider.overrideWith(() => _AlwaysDemoNotifier()),
        summaryInputProvider.overrideWithValue(input),
      ],
      child: MaterialApp(
        theme: AeroSenseTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(child: AskAboutRoomCard()),
        ),
      ),
    );
  }

  testWidgets('hides the assistant action while it is not enabled', (
    tester,
  ) async {
    expect(AppConfig.assistantEnabled, isFalse);

    await tester.pumpWidget(harness());

    expect(find.text(AppStrings.roomSummaryTitle), findsOneWidget);
    expect(find.text(AppStrings.askAboutRoomTitle), findsNothing);
    expect(find.text(AppStrings.summarize), findsOneWidget);
    expect(find.text(AppStrings.askAeroSense), findsNothing);
  });

  testWidgets('opens the summary sheet from the dashboard card', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    await tester.tap(find.text(AppStrings.summarize));
    await tester.pumpAndSettle();

    expect(find.textContaining('Firmware tier: Caution'), findsOneWidget);
    expect(find.text(AppStrings.summaryDisclaimer), findsOneWidget);
  });

  testWidgets('shows the assistant action in Demo Mode', (tester) async {
    await tester.pumpWidget(harness(demo: true));

    expect(find.text(AppStrings.askAboutRoomTitle), findsOneWidget);
    expect(find.text(AppStrings.askAeroSense), findsOneWidget);
    expect(find.text(AppStrings.summarize), findsOneWidget);
  });

  testWidgets('the assistant action opens the /assistant route', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: SingleChildScrollView(child: AskAboutRoomCard()),
          ),
        ),
        GoRoute(
          path: '/assistant',
          builder: (context, state) =>
              const Scaffold(body: Text('assistant-route')),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          demoModeProvider.overrideWith(() => _AlwaysDemoNotifier()),
          summaryInputProvider.overrideWithValue(input),
        ],
        child: MaterialApp.router(
          theme: AeroSenseTheme.light,
          routerConfig: router,
        ),
      ),
    );

    await tester.tap(find.text(AppStrings.askAeroSense));
    await tester.pumpAndSettle();

    expect(find.text('assistant-route'), findsOneWidget);
  });
}
