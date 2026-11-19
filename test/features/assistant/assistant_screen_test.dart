import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/assistant_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_copy.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';
import 'package:aerosense_app/features/assistant/assistant_screen.dart';
import 'package:aerosense_app/features/assistant/rate_limiter.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

class _TestClock {
  _TestClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

class _RecordingRepository implements AssistantRepository {
  _RecordingRepository({this.answer = 'The room is in Caution.', this.failure});

  final String answer;
  final Object? failure;
  final List<String> questions = [];

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) {
    questions.add(question);
    if (failure != null) return Future.error(failure!);
    return Future.value(answer);
  }
}

class _PendingRepository implements AssistantRepository {
  final Completer<String> completer = Completer<String>();

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) {
    return completer.future;
  }
}

class _DemoModeNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

SummaryInput buildSummary() {
  return SummaryInput(
    state: const SystemState(
      temperature: 34.1,
      humidity: 58,
      airQuality: 1520,
      fanOn: false,
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
}

Widget _harness({
  AssistantRepository? repository,
  SlidingWindowRateLimiter? limiter,
  _TestClock? clock,
  double textScale = 1.0,
  bool demo = false,
}) {
  final testClock = clock ?? _TestClock(DateTime(2026, 11, 15, 14, 10));
  return ProviderScope(
    overrides: [
      summaryInputProvider.overrideWithValue(buildSummary()),
      assistantRepositoryProvider.overrideWithValue(
        repository ?? _RecordingRepository(),
      ),
      assistantRateLimiterProvider.overrideWithValue(
        limiter ?? SlidingWindowRateLimiter(clock: testClock.call),
      ),
      currentUserUidProvider.overrideWithValue('uid-1'),
      deviceLocaleProvider.overrideWithValue(const Locale('en')),
      clockProvider.overrideWithValue(testClock.call),
      if (demo) demoModeProvider.overrideWith(_DemoModeNotifier.new),
    ],
    child: MaterialApp(
      theme: AeroSenseTheme.light,
      home: Builder(
        builder: (context) {
          return MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: const AssistantScreen(),
          );
        },
      ),
    ),
  );
}

Finder _sendButton() => find.descendant(
  of: find.byType(TextField),
  matching: find.byType(IconButton),
);

void main() {
  testWidgets(
    'shows chips, the short disclaimer, the info button and the composer',
    (tester) async {
      await tester.pumpWidget(_harness());

      expect(find.text(AppStrings.assistantIntro), findsOneWidget);
      expect(find.text(AppStrings.assistantChipsEnglish.first), findsOneWidget);
      expect(
        find.text(AssistantCopy(SummaryLanguage.en).disclaimerShort),
        findsOneWidget,
      );
      expect(find.byTooltip('About this assistant'), findsOneWidget);
      expect(_sendButton(), findsOneWidget);

      final send = tester.widget<IconButton>(_sendButton());
      expect(send.onPressed, isNull);
    },
  );

  testWidgets('shows the scripted disclosure in Demo Mode', (tester) async {
    await tester.pumpWidget(_harness(demo: true));

    expect(
      find.text(AssistantCopy(SummaryLanguage.en).demoScriptedNote),
      findsOneWidget,
    );
  });

  testWidgets('a suggested chip asks a question and shows the answer', (
    tester,
  ) async {
    final repository = _RecordingRepository(answer: 'It is Caution right now.');
    await tester.pumpWidget(_harness(repository: repository));

    await tester.tap(find.text(AppStrings.assistantChipsEnglish.first));
    await tester.pumpAndSettle();

    expect(repository.questions, [AppStrings.assistantChipsEnglish.first]);
    expect(find.text('It is Caution right now.'), findsOneWidget);
    expect(find.text(AppStrings.assistantChipsEnglish.first), findsWidgets);
  });

  testWidgets('shows a thinking state and disables sending while it waits', (
    tester,
  ) async {
    final repository = _PendingRepository();
    await tester.pumpWidget(_harness(repository: repository));

    await tester.tap(find.text(AppStrings.assistantChipsEnglish.first));
    await tester.pump();

    expect(find.text(AppStrings.assistantThinking), findsOneWidget);
    expect(tester.widget<IconButton>(_sendButton()).onPressed, isNull);

    repository.completer.complete('All good.');
    await tester.pumpAndSettle();

    expect(find.text('All good.'), findsOneWidget);
    expect(find.text(AppStrings.assistantThinking), findsNothing);
  });

  testWidgets('caps the question at 300 characters', (tester) async {
    final repository = _RecordingRepository();
    await tester.pumpWidget(_harness(repository: repository));

    await tester.enterText(find.byType(TextField), 'x' * 400);
    await tester.pump();

    final editable = tester.widget<EditableText>(find.byType(EditableText));
    expect(editable.controller.text.length, 300);

    await tester.tap(_sendButton());
    await tester.pumpAndSettle();

    expect(repository.questions.single.length, 300);
  });

  testWidgets('shows the rate-limit state with the deterministic summary', (
    tester,
  ) async {
    final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
    final limiter = SlidingWindowRateLimiter(clock: clock.call);
    for (var i = 0; i < 6; i++) {
      limiter.tryAcquire('uid-1');
      clock.advance(const Duration(seconds: 2));
    }
    final repository = _RecordingRepository();

    await tester.pumpWidget(
      _harness(repository: repository, limiter: limiter, clock: clock),
    );
    await tester.tap(find.text(AppStrings.assistantChipsEnglish.first));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.assistantRateLimitedTitle), findsOneWidget);
    expect(find.textContaining('You can ask again in'), findsOneWidget);
    expect(find.textContaining('Firmware tier: Caution'), findsOneWidget);
    expect(repository.questions, isEmpty);
  });

  testWidgets('shows the error state with the summary and a working retry', (
    tester,
  ) async {
    final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
    final repository = _RecordingRepository(failure: Exception('network'));
    await tester.pumpWidget(_harness(repository: repository, clock: clock));

    await tester.tap(find.text(AppStrings.assistantChipsEnglish.first));
    await tester.pumpAndSettle();

    expect(find.text(AppStrings.assistantErrorTitle), findsOneWidget);
    expect(find.text(AppStrings.assistantErrorBody), findsOneWidget);
    expect(find.textContaining('Firmware tier: Caution'), findsOneWidget);
    expect(find.text(AppStrings.assistantTryAgain), findsOneWidget);
    expect(repository.questions.length, 1);

    clock.advance(const Duration(seconds: 2));
    // The error card is taller than the test viewport, so bring the button
    // into view before tapping it.
    await tester.ensureVisible(find.text(AppStrings.assistantTryAgain));
    await tester.pumpAndSettle();
    await tester.tap(find.text(AppStrings.assistantTryAgain));
    await tester.pumpAndSettle();

    expect(repository.questions.length, 2);
  });

  testWidgets('switches the suggested chips to Indonesian', (tester) async {
    await tester.pumpWidget(_harness());
    expect(find.text(AppStrings.assistantChipsEnglish.first), findsOneWidget);

    await tester.tap(find.text(AppStrings.languageIndonesia));
    await tester.pumpAndSettle();

    expect(
      find.text(AppStrings.assistantChipsIndonesian.first),
      findsOneWidget,
    );
    expect(find.text(AppStrings.assistantChipsEnglish.first), findsNothing);
  });

  for (final size in const [Size(360, 640), Size(768, 1024), Size(1280, 800)]) {
    testWidgets(
      'renders without overflow at ${size.width.toInt()}x${size.height.toInt()} '
      'with 1.3x text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final repository = _RecordingRepository(
          answer:
              'The device reports the firmware tier as Caution. The fan is off. '
              'Temperature is 34.1 °C. Air quality index is 1520 '
              '(raw 0-4095, not ppm).',
        );
        await tester.pumpWidget(
          _harness(repository: repository, textScale: 1.3),
        );

        final chip = find.text(AppStrings.assistantChipsEnglish.first);
        await tester.scrollUntilVisible(
          chip,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.tap(chip);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.text(AssistantCopy(SummaryLanguage.en).disclaimerShort),
          findsOneWidget,
        );
        expect(find.byTooltip('About this assistant'), findsOneWidget);
      },
    );
  }
}
