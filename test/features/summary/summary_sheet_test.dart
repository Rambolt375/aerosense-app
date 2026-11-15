import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';
import 'package:aerosense_app/features/summary/widgets/summary_sheet.dart';

void main() {
  final input = SummaryInput(
    state: const SystemState(
      temperature: 34.1,
      humidity: 58,
      airQuality: 1520,
      fanOn: false,
      statusMessage: 'CAUTION: The environment is stuffy.',
      tier: Tier.medium,
    ),
    thresholds: ThresholdPreset.firmware,
    device: const DeviceSummary(
      state: DeviceSummaryState.online,
      lastDataLabel: '14:05',
    ),
    forecast: const ForecastSummary(
      status: ForecastSummaryStatus.active,
      temperaturePeak: '15:00',
      airQualityPeak: '15:10',
    ),
    history: const HistoryStats24h(
      sampleCount: 143,
      temperature: MetricStats(min: 27.8, max: 34.9, mean: 31.4),
    ),
    language: SummaryLanguage.en,
    now: DateTime(2026, 11, 15, 14, 10),
  );

  Widget harness(SummaryInput? value, {TextScaler? textScaler}) {
    return ProviderScope(
      overrides: [summaryInputProvider.overrideWithValue(value)],
      child: MaterialApp(
        theme: AeroSenseTheme.light,
        home: Builder(
          builder: (context) {
            final media = MediaQuery.of(context);
            return MediaQuery(
              data: media.copyWith(
                textScaler: textScaler ?? TextScaler.noScaling,
              ),
              child: const Scaffold(body: SummarySheet()),
            );
          },
        ),
      ),
    );
  }

  testWidgets('renders the summary sections and the disclaimer', (
    tester,
  ) async {
    await tester.pumpWidget(harness(input));

    expect(find.textContaining('Firmware tier: Caution'), findsOneWidget);
    expect(find.textContaining('Last 24 hours (143 readings)'), findsOneWidget);
    expect(find.text(AppStrings.summaryDisclaimer), findsOneWidget);
    expect(find.text(AppStrings.summaryCopy), findsOneWidget);
  });

  testWidgets('switches the summary language to Indonesian', (tester) async {
    await tester.pumpWidget(harness(input));

    await tester.tap(find.text('Indonesia'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Tingkat firmware: Caution'), findsOneWidget);
    expect(find.textContaining('Saat ini'), findsOneWidget);
    expect(find.textContaining('Firmware tier'), findsNothing);
  });

  testWidgets('copies the plain-text summary to the clipboard', (tester) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call);
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    await tester.pumpWidget(harness(input));
    await tester.tap(find.text(AppStrings.summaryCopy));
    await tester.pump();

    final clipboardCall = calls.firstWhere(
      (call) => call.method == 'Clipboard.setData',
    );
    final text = (clipboardCall.arguments as Map)['text'] as String;
    expect(text, contains('Firmware tier: Caution'));
    expect(text, contains('Predicted temperature peak around 15:00.'));
    expect(find.text(AppStrings.summaryCopied), findsOneWidget);
  });

  testWidgets('shows a no-data state when there is no device reading', (
    tester,
  ) async {
    await tester.pumpWidget(harness(null));

    expect(find.text(AppStrings.summaryNoDataTitle), findsOneWidget);
    expect(find.text(AppStrings.summaryNoDataBody), findsOneWidget);
    expect(find.textContaining('Firmware tier'), findsNothing);
  });

  testWidgets('does not overflow at 360 px with 1.3x text', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      harness(input, textScaler: const TextScaler.linear(1.3)),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.textContaining('Firmware tier: Caution'), findsOneWidget);
    expect(find.text(AppStrings.summaryDisclaimer), findsOneWidget);
  });
}
