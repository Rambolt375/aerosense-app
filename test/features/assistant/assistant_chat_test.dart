import 'dart:async';
import 'dart:ui' show Locale;

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/assistant_repository.dart';
import 'package:aerosense_app/data/repositories/fake_assistant_repository.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/assistant/assistant_models.dart';
import 'package:aerosense_app/features/assistant/assistant_providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';
import 'package:aerosense_app/features/summary/summary_providers.dart';

class _TestClock {
  _TestClock(this.now);

  DateTime now;

  DateTime call() => now;

  void advance(Duration duration) => now = now.add(duration);
}

class _Call {
  _Call(this.systemInstruction, this.history, this.question);

  final String systemInstruction;
  final List<AssistantMessage> history;
  final String question;
}

class _RecordingRepository implements AssistantRepository {
  _RecordingRepository({this.answer = 'It is Caution.', this.failure});

  final String answer;
  final Object? failure;
  final List<_Call> calls = [];

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) {
    calls.add(_Call(systemInstruction, List.of(history), question));
    if (failure != null) return Future.error(failure!);
    return Future.value(answer);
  }
}

class _FlakyRepository implements AssistantRepository {
  int calls = 0;

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) {
    calls++;
    if (calls == 1) return Future.error(Exception('network'));
    return Future.value('Second answer');
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

class _DefaultRepository implements AssistantRepository {
  const _DefaultRepository();

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    return 'Default answer';
  }
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

ProviderContainer _container({
  AssistantRepository? repository = const _DefaultRepository(),
  SummaryInput? summary,
  bool includeSummary = true,
  Duration? timeout,
  _TestClock? clock,
}) {
  final testClock = clock ?? _TestClock(DateTime(2026, 11, 15, 14, 10));
  final container = ProviderContainer(
    overrides: [
      summaryInputProvider.overrideWithValue(
        includeSummary ? (summary ?? _buildSummary()) : null,
      ),
      assistantRepositoryProvider.overrideWithValue(repository),
      currentUserUidProvider.overrideWithValue('uid-1'),
      deviceLocaleProvider.overrideWithValue(const Locale('en')),
      clockProvider.overrideWithValue(testClock.call),
      if (timeout != null) assistantTimeoutProvider.overrideWithValue(timeout),
    ],
  );
  // Keep the auto-disposed chat provider alive for the whole test.
  final subscription = container.listen(assistantChatProvider, (_, _) {});
  addTearDown(() {
    subscription.close();
    container.dispose();
  });
  return container;
}

void main() {
  test('starts idle with no messages', () {
    final container = _container();
    final state = container.read(assistantChatProvider);

    expect(state.status, AssistantStatus.idle);
    expect(state.messages, isEmpty);
  });

  test('adds the visitor question and the answer to the transcript', () async {
    final repository = _RecordingRepository(answer: 'The room is in Caution.');
    final container = _container(repository: repository);

    await container.read(assistantChatProvider.notifier).ask('How is it?');

    final state = container.read(assistantChatProvider);
    expect(state.status, AssistantStatus.answered);
    expect(state.messages.length, 2);
    expect(state.messages.first.role, AssistantRole.visitor);
    expect(state.messages.first.text, 'How is it?');
    expect(state.messages.last.role, AssistantRole.assistant);
    expect(state.messages.last.text, 'The room is in Caution.');
  });

  test('keeps the last four messages and sends them as history', () async {
    final repository = _RecordingRepository();
    final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
    final container = _container(repository: repository, clock: clock);
    final notifier = container.read(assistantChatProvider.notifier);

    for (var i = 0; i < 3; i++) {
      clock.advance(const Duration(seconds: 2));
      await notifier.ask('question $i');
    }

    expect(repository.calls[1].history.length, 2);
    expect(repository.calls[1].history.first.text, 'question 0');
    expect(repository.calls[2].history.length, 4);
    expect(repository.calls[2].history.first.text, 'question 0');

    final state = container.read(assistantChatProvider);
    expect(state.messages.length, AppConfig.assistantMaxMessages);
    expect(state.messages.first.text, 'question 1');
  });

  test(
    'exposes the in-flight question but never sends it as history',
    () async {
      final repository = _PendingRepository();
      final container = _container(repository: repository);
      final notifier = container.read(assistantChatProvider.notifier);

      final pending = notifier.ask('How is it?');
      // The visitor bubble is available immediately, before the answer.
      final thinking = container.read(assistantChatProvider);
      expect(thinking.status, AssistantStatus.thinking);
      expect(thinking.pendingQuestion, 'How is it?');
      expect(thinking.messages, isEmpty);

      repository.completer.complete('It is Caution.');
      await pending;

      final answered = container.read(assistantChatProvider);
      expect(answered.pendingQuestion, isNull);
      expect(answered.messages.length, 2);
    },
  );

  test(
    'history holds previous messages only, capped at the last four',
    () async {
      final repository = _RecordingRepository();
      final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
      final container = _container(repository: repository, clock: clock);
      final notifier = container.read(assistantChatProvider.notifier);

      for (var i = 0; i < 4; i++) {
        clock.advance(const Duration(seconds: 2));
        await notifier.ask('question $i');
      }

      for (final call in repository.calls) {
        expect(
          call.history.length,
          lessThanOrEqualTo(AppConfig.assistantMaxMessages),
        );
        expect(
          call.history.any((m) => m.text == call.question),
          isFalse,
          reason: 'the in-flight question must not be part of the history',
        );
      }
    },
  );

  test('rejects questions faster than the minimum spacing', () async {
    final repository = _RecordingRepository();
    final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
    final container = _container(repository: repository, clock: clock);
    final notifier = container.read(assistantChatProvider.notifier);

    await notifier.ask('first');
    await notifier.ask('second');

    final state = container.read(assistantChatProvider);
    expect(state.status, AssistantStatus.rateLimited);
    expect(state.retryAfter, isNotNull);
    expect(repository.calls.length, 1);
    expect(state.messages.length, 2);
  });

  test('rate limits after six questions in ten minutes', () async {
    final repository = _RecordingRepository();
    final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
    final container = _container(repository: repository, clock: clock);
    final notifier = container.read(assistantChatProvider.notifier);

    for (var i = 0; i < 6; i++) {
      clock.advance(const Duration(seconds: 2));
      await notifier.ask('question $i');
    }
    expect(repository.calls.length, 6);

    await notifier.ask('seventh');

    final state = container.read(assistantChatProvider);
    expect(state.status, AssistantStatus.rateLimited);
    expect(repository.calls.length, 6);
    expect(state.lastQuestion, 'seventh');
  });

  test('falls into the error state without retrying on its own', () async {
    final repository = _RecordingRepository(failure: Exception('boom'));
    final container = _container(repository: repository);

    await container.read(assistantChatProvider.notifier).ask('How is it?');

    final state = container.read(assistantChatProvider);
    expect(state.status, AssistantStatus.error);
    expect(state.errorMessage, AppStrings.assistantErrorBody);
    expect(state.messages, isEmpty);
    expect(repository.calls.length, 1);
  });

  test('maps a timeout to the error state', () async {
    final repository = _PendingRepository();
    final container = _container(
      repository: repository,
      timeout: const Duration(milliseconds: 10),
    );

    await container.read(assistantChatProvider.notifier).ask('How is it?');

    expect(container.read(assistantChatProvider).status, AssistantStatus.error);
  });

  test('retry asks again and respects the limiter', () async {
    final repository = _FlakyRepository();
    final clock = _TestClock(DateTime(2026, 11, 15, 14, 10));
    final container = _container(repository: repository, clock: clock);
    final notifier = container.read(assistantChatProvider.notifier);

    await notifier.ask('How is it?');
    expect(container.read(assistantChatProvider).status, AssistantStatus.error);

    await notifier.retry();
    expect(
      container.read(assistantChatProvider).status,
      AssistantStatus.rateLimited,
    );
    expect(repository.calls, 1);

    clock.advance(const Duration(seconds: 2));
    await notifier.retry();

    final state = container.read(assistantChatProvider);
    expect(state.status, AssistantStatus.answered);
    expect(repository.calls, 2);
    expect(state.messages.last.text, 'Second answer');
  });

  test(
    'reports the assistant as unavailable when no repository exists',
    () async {
      final container = _container(repository: null);

      await container.read(assistantChatProvider.notifier).ask('How is it?');

      final state = container.read(assistantChatProvider);
      expect(state.status, AssistantStatus.error);
      expect(state.errorMessage, AppStrings.assistantUnavailableBody);
    },
  );

  test('reports no data before the first telemetry snapshot', () async {
    final repository = _RecordingRepository();
    final container = _container(repository: repository, includeSummary: false);

    await container.read(assistantChatProvider.notifier).ask('How is it?');

    final state = container.read(assistantChatProvider);
    expect(state.status, AssistantStatus.error);
    expect(state.errorMessage, AppStrings.summaryNoDataBody);
    expect(repository.calls, isEmpty);
  });

  test('passes the selected language to the system instruction', () async {
    final repository = _RecordingRepository();
    final container = _container(repository: repository);
    container.read(summaryLanguageProvider.notifier).select(SummaryLanguage.id);

    await container.read(assistantChatProvider.notifier).ask('Apa kabar?');

    expect(
      repository.calls.single.systemInstruction,
      contains('Answer in Indonesian'),
    );
  });

  test('never puts the question inside the system instruction', () async {
    final repository = _RecordingRepository();
    final container = _container(repository: repository);

    await container
        .read(assistantChatProvider.notifier)
        .ask('  What is my account email?  ');

    final call = repository.calls.single;
    expect(call.question, 'What is my account email?');
    expect(call.systemInstruction, isNot(contains('account email')));
  });

  group('assistantRepositoryProvider', () {
    test('uses scripted answers in Demo Mode and nothing outside it', () {
      final container = ProviderContainer(
        overrides: [summaryInputProvider.overrideWithValue(_buildSummary())],
      );
      addTearDown(container.dispose);

      container.read(demoModeProvider.notifier).setDemo(false);
      expect(container.read(assistantRepositoryProvider), isNull);

      container.read(demoModeProvider.notifier).setDemo(true);
      expect(
        container.read(assistantRepositoryProvider),
        isA<FakeAssistantRepository>(),
      );

      container.read(demoModeProvider.notifier).setDemo(false);
      expect(container.read(assistantRepositoryProvider), isNull);
    });
  });
}
