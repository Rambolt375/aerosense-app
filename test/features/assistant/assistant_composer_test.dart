import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/config.dart';
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

/// Fails the first call, succeeds afterwards.
class _FlakyRepository implements AssistantRepository {
  _FlakyRepository();

  static const String answer = 'Second answer';
  int calls = 0;
  final List<List<AssistantMessage>> histories = [];

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) {
    calls++;
    histories.add(List.of(history));
    if (calls == 1) return Future.error(Exception('network'));
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

class _EchoRepository implements AssistantRepository {
  final List<String> questions = [];

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    questions.add(question);
    return 'Answer to $question';
  }
}

class _DemoModeNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

SummaryInput _buildSummary() {
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
  required AssistantRepository repository,
  _TestClock? clock,
  SlidingWindowRateLimiter? limiter,
  double textScale = 1.0,
  bool demo = false,
}) {
  final testClock = clock ?? _TestClock(DateTime(2026, 11, 15, 14, 10));
  return ProviderScope(
    overrides: [
      summaryInputProvider.overrideWithValue(_buildSummary()),
      assistantRepositoryProvider.overrideWithValue(repository),
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

Finder _field() => find.byType(TextField);

Finder _sendButton() =>
    find.descendant(of: _field(), matching: find.byType(IconButton));

Future<void> _pressEnter(WidgetTester tester, {bool shift = false}) async {
  if (shift) {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  if (shift) {
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  }
  await tester.pump();
}

void main() {
  group('Composer layout', () {
    testWidgets('Send lives inside the field as a 48 dp icon button', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(repository: _EchoRepository()));

      final send = _sendButton();
      expect(send, findsOneWidget);
      expect(find.byType(IconButton), findsWidgets);

      final size = tester.getSize(send);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));

      // No separate send button outside the field.
      expect(
        find.descendant(
          of: find.byType(Scaffold),
          matching: find.widgetWithText(FilledButton, 'Send'),
        ),
        findsNothing,
      );
    });

    testWidgets(
      'Send is disabled while empty and while a request is in flight',
      (tester) async {
        final repository = _PendingRepository();
        await tester.pumpWidget(_harness(repository: repository));

        IconButton sendWidget() =>
            tester.widget<IconButton>(_sendButton().first);

        expect(sendWidget().onPressed, isNull);

        await tester.enterText(_field(), 'Is the room OK?');
        await tester.pump();
        expect(sendWidget().onPressed, isNotNull);

        await tester.tap(_sendButton());
        await tester.pump();
        expect(sendWidget().onPressed, isNull);

        repository.completer.complete('It is Caution.');
        await tester.pumpAndSettle();
      },
    );

    testWidgets('the field is multiline up to four lines', (tester) async {
      await tester.pumpWidget(_harness(repository: _EchoRepository()));

      final field = tester.widget<TextField>(_field());
      expect(field.minLines, 1);
      expect(field.maxLines, 4);
      expect(field.maxLength, AppConfig.assistantMaxInputChars);
    });

    for (final size in const [
      Size(360, 640),
      Size(768, 1024),
      Size(1280, 800),
    ]) {
      testWidgets('the field spans the content width at ${size.width.toInt()}x'
          '${size.height.toInt()} with 1.3x text', (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(
          _harness(repository: _EchoRepository(), textScale: 1.3),
        );
        await tester.pumpAndSettle();

        final pagePadding = size.width < 600 ? 16.0 : 24.0;
        final contentWidth = size.width < 840
            ? size.width - pagePadding * 2
            : 840 - pagePadding * 2;

        expect(tester.getSize(_field()).width, closeTo(contentWidth, 1.0));
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('Composer keyboard and counter', () {
    testWidgets('Enter sends and clears the field', (tester) async {
      final repository = _EchoRepository();
      await tester.pumpWidget(_harness(repository: repository));

      await tester.enterText(_field(), 'Is the room OK?');
      await tester.pump();
      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(repository.questions, ['Is the room OK?']);
      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, isEmpty);
      // Focus stays in the field so the visitor can ask again.
      expect(editable.focusNode.hasFocus, isTrue);
    });

    testWidgets('Shift+Enter inserts a newline instead of sending', (
      tester,
    ) async {
      final repository = _EchoRepository();
      await tester.pumpWidget(_harness(repository: repository));

      await tester.enterText(_field(), 'First line');
      await tester.pump();
      await _pressEnter(tester, shift: true);
      await tester.pump();

      final editable = tester.widget<EditableText>(find.byType(EditableText));
      expect(editable.controller.text, 'First line\n');
      expect(repository.questions, isEmpty);

      await tester.enterText(_field(), 'First line\nSecond line');
      await tester.pump();
      await _pressEnter(tester);
      await tester.pumpAndSettle();

      expect(repository.questions, ['First line\nSecond line']);
    });

    testWidgets('the counter appears only above 240 characters', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(repository: _EchoRepository()));

      await tester.enterText(_field(), 'x' * 240);
      await tester.pump();
      expect(
        find.text('240/${AppConfig.assistantMaxInputChars}'),
        findsNothing,
      );

      await tester.enterText(_field(), 'x' * 241);
      await tester.pump();
      expect(
        find.text('241/${AppConfig.assistantMaxInputChars}'),
        findsOneWidget,
      );

      await tester.enterText(_field(), 'x' * 300);
      await tester.pump();
      expect(
        find.text('300/${AppConfig.assistantMaxInputChars}'),
        findsOneWidget,
      );
    });
  });

  group('Transcript', () {
    testWidgets('the visitor bubble appears before the thinking bubble', (
      tester,
    ) async {
      final repository = _PendingRepository();
      await tester.pumpWidget(_harness(repository: repository));

      await tester.enterText(_field(), 'Is the room OK?');
      await tester.pump();
      await _pressEnter(tester);
      await tester.pump();

      final visitor = find.text('Is the room OK?');
      final thinking = find.text('Thinking...');
      expect(visitor, findsOneWidget);
      expect(thinking, findsOneWidget);
      expect(
        tester.getTopLeft(visitor).dy,
        lessThan(tester.getTopLeft(thinking).dy),
      );

      repository.completer.complete('It is Caution.');
      await tester.pumpAndSettle();

      expect(find.text('It is Caution.'), findsOneWidget);
      expect(find.text('Thinking...'), findsNothing);
      // The answer replaces the thinking bubble; the question stays once.
      expect(find.text('Is the room OK?'), findsOneWidget);
    });

    testWidgets('a chip tap shows the question immediately', (tester) async {
      final repository = _PendingRepository();
      await tester.pumpWidget(_harness(repository: repository));

      final chip = find.text('Is the room OK right now?');
      await tester.tap(chip);
      await tester.pump();

      expect(find.text('Is the room OK right now?'), findsNWidgets(2));
      expect(find.text('Thinking...'), findsOneWidget);

      repository.completer.complete('It is Caution.');
      await tester.pumpAndSettle();
    });

    testWidgets(
      'an error keeps the visitor bubble and retry does not duplicate',
      (tester) async {
        tester.view.physicalSize = const Size(500, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
        final repository = _FlakyRepository();
        await tester.pumpWidget(_harness(repository: repository, clock: clock));

        await tester.enterText(_field(), 'Why is it stuffy?');
        await tester.pump();
        await _pressEnter(tester);
        await tester.pumpAndSettle();

        expect(find.text("The assistant couldn't answer"), findsOneWidget);
        expect(find.text('Why is it stuffy?'), findsOneWidget);
        // The error card sits below the visitor bubble.
        expect(
          tester.getTopLeft(find.text('Why is it stuffy?')).dy,
          lessThan(
            tester.getTopLeft(find.text("The assistant couldn't answer")).dy,
          ),
        );

        clock.advance(const Duration(seconds: 2));
        await tester.tap(find.text('Try again'));
        await tester.pumpAndSettle();

        expect(repository.calls, 2);
        expect(find.text('Why is it stuffy?'), findsOneWidget);
        expect(find.text('Second answer'), findsOneWidget);
        expect(find.text("The assistant couldn't answer"), findsNothing);

        // The retried question never entered the history it was sent with.
        for (final history in repository.histories) {
          expect(history.any((m) => m.text == 'Why is it stuffy?'), isFalse);
        }
      },
    );

    testWidgets('the transcript scrolls to the newest message', (tester) async {
      tester.view.physicalSize = const Size(360, 500);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = _EchoRepository();
      await tester.pumpWidget(_harness(repository: repository));

      for (var i = 0; i < 3; i++) {
        await tester.enterText(_field(), 'Question $i');
        await tester.pump();
        await _pressEnter(tester);
        await tester.pumpAndSettle();
      }

      final scrollable = tester.widget<Scrollable>(
        find.byType(Scrollable).first,
      );
      expect(scrollable.controller!.offset, greaterThan(0));
    });
  });

  group('Footer', () {
    testWidgets('shows the one-line disclaimer in English', (tester) async {
      await tester.pumpWidget(_harness(repository: _EchoRepository()));

      expect(
        find.text(AssistantCopy(SummaryLanguage.en).disclaimerShort),
        findsOneWidget,
      );
      expect(
        find.textContaining("Don't type personal information"),
        findsNothing,
      );
    });

    testWidgets('shows the one-line disclaimer in Indonesian', (tester) async {
      await tester.pumpWidget(_harness(repository: _EchoRepository()));

      await tester.tap(find.text('Indonesia'));
      await tester.pumpAndSettle();

      expect(
        find.text(AssistantCopy(SummaryLanguage.id).disclaimerShort),
        findsOneWidget,
      );
    });

    testWidgets('the info sheet holds the full previous wording', (
      tester,
    ) async {
      await tester.pumpWidget(_harness(repository: _EchoRepository()));

      await tester.tap(find.byTooltip('About this assistant'));
      await tester.pumpAndSettle();

      expect(find.text('About this assistant'), findsWidgets);
      expect(
        find.text(
          'AI-generated, may be wrong. The device alert is authoritative.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          "Questions are sent to Google's Gemini service. "
          "Don't type personal information.",
        ),
        findsOneWidget,
      );
      // The scripted note belongs to Demo Mode only.
      expect(find.textContaining('scripted'), findsNothing);
    });

    testWidgets('the info sheet notes scripted answers in Demo Mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(repository: _EchoRepository(), demo: true),
      );

      await tester.tap(find.byTooltip('About this assistant'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byKey(const Key('assistant-about-sheet')),
          matching: find.textContaining('scripted'),
        ),
        findsOneWidget,
      );
    });
  });
}
