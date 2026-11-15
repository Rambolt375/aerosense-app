import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/dashboard/widgets/ask_about_room_card.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

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

  Widget harness() {
    return ProviderScope(
      overrides: [summaryInputProvider.overrideWithValue(input)],
      child: MaterialApp(
        theme: AeroSenseTheme.light,
        home: const Scaffold(
          body: SingleChildScrollView(child: AskAboutRoomCard()),
        ),
      ),
    );
  }

  testWidgets('renders the Summarize action and hides the assistant', (
    tester,
  ) async {
    await tester.pumpWidget(harness());

    expect(find.text(AppStrings.askAboutRoomTitle), findsOneWidget);
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
}
