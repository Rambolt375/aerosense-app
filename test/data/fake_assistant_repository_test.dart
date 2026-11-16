import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/fake_assistant_repository.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';

SummaryInput buildInput({
  SummaryLanguage language = SummaryLanguage.en,
  SystemState state = const SystemState(
    temperature: 34.1,
    humidity: 58,
    airQuality: 1520,
    fanOn: false,
    statusMessage: 'CAUTION',
    tier: Tier.medium,
  ),
  ForecastSummary forecast = const ForecastSummary(
    status: ForecastSummaryStatus.active,
    temperaturePeak: '15:00',
  ),
}) {
  return SummaryInput(
    state: state,
    thresholds: ThresholdPreset.firmware,
    device: const DeviceSummary(state: DeviceSummaryState.online),
    forecast: forecast,
    history: const HistoryStats24h(sampleCount: 143),
    language: language,
    now: DateTime(2026, 11, 15, 14, 10),
  );
}

Future<String> askWith(
  FakeAssistantRepository repository, {
  String question = 'How is the room?',
}) {
  return repository.ask(
    systemInstruction: 'instruction',
    history: const <AssistantMessage>[],
    question: question,
  );
}

void main() {
  test('answers after the approved 300 ms demo delay', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(),
    );

    expect(repository.latency, const Duration(milliseconds: 300));

    final stopwatch = Stopwatch()..start();
    await askWith(repository);
    stopwatch.stop();

    expect(stopwatch.elapsedMilliseconds, greaterThanOrEqualTo(300));
  });

  test('quotes the firmware tier when the device sent one', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(),
    );

    final answer = await askWith(repository);

    expect(answer, contains('The device reports the firmware tier as Caution'));
    expect(answer, contains('The device controls the fan'));
    expect(answer, isNot(contains('estimates')));
  });

  test('says the tier is estimated when the device sent no tier', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(
        state: const SystemState(
          temperature: 34.1,
          humidity: 58,
          airQuality: 1520,
          statusMessage: '',
          tier: Tier.medium,
        ),
      ),
    );

    final answer = await askWith(repository);

    expect(answer, contains('did not send a tier'));
    expect(answer, contains('estimates Caution from the readings'));
  });

  test('quotes a descriptive firmware status message', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(
        state: const SystemState(
          temperature: 34.1,
          airQuality: 1520,
          statusMessage: 'CAUTION: The environment is stuffy.',
          tier: Tier.medium,
        ),
      ),
    );

    final answer = await askWith(repository);

    expect(answer, contains('CAUTION: The environment is stuffy.'));
  });

  test('reports live readings without inventing missing data', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(
        state: const SystemState(statusMessage: 'CAUTION', tier: Tier.medium),
      ),
    );

    final answer = await askWith(repository);

    expect(answer, contains('Temperature has no reading'));
    expect(answer, contains('Air quality has no reading'));
    expect(answer, isNot(contains('°C.')));
  });

  test('explains thresholds when asked why', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(),
    );

    final answer = await askWith(repository, question: 'Why is it in Caution?');

    expect(answer, contains('Caution starts at 33.5 °C'));
    expect(answer, contains('Danger at 36.0 °C'));
  });

  test('mentions the predicted peak when asked when it is warmest', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(),
    );

    final answer = await askWith(repository, question: 'When is it warmest?');

    expect(answer, contains('peak around 15:00'));
  });

  test('labels air quality as a raw index, never ppm', () async {
    final repository = FakeAssistantRepository(
      summaryInput: () => buildInput(),
    );

    final answer = await askWith(repository);

    expect(answer, contains('1520'));
    expect(answer, contains('not ppm'));
    expect('ppm'.allMatches(answer).length, 1);
  });

  test(
    'answers in Indonesian when the summary language is Indonesian',
    () async {
      final repository = FakeAssistantRepository(
        summaryInput: () => buildInput(language: SummaryLanguage.id),
      );

      final answer = await askWith(repository);

      expect(answer, contains('Perangkat melaporkan tingkat firmware Caution'));
      expect(answer, contains('Perangkat yang mengendalikan kipas'));
      expect(answer, isNot(contains('The device controls the fan')));
    },
  );

  test('fails honestly when there is no telemetry summary yet', () async {
    final repository = FakeAssistantRepository(summaryInput: () => null);

    await expectLater(askWith(repository), throwsStateError);
  });
}
