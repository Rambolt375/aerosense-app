import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/sensor_validation.dart';
import 'package:aerosense_app/data/models/assistant_message.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/assistant_repository.dart';
import 'package:aerosense_app/features/summary/summary_builder.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';

/// Scripted Demo Mode assistant. No network, no SDK, no invented telemetry.
///
/// Answers are derived from the same [SummaryInput] the deterministic summary
/// uses, so the fake can never claim a tier, fan state or reading the demo
/// device did not report.
class FakeAssistantRepository implements AssistantRepository {
  FakeAssistantRepository({
    required this.summaryInput,
    this.latency = AppConfig.assistantFakeLatency,
  });

  /// Reads the summary lazily so each answer reflects the live demo state.
  final SummaryInput? Function() summaryInput;

  /// Artificial latency so the thinking state is exercised in Demo Mode.
  final Duration latency;

  @override
  Future<String> ask({
    required String systemInstruction,
    required List<AssistantMessage> history,
    required String question,
  }) async {
    await Future<void>.delayed(latency);

    final input = summaryInput();
    if (input == null) {
      // No first /system snapshot yet: fail honestly instead of inventing data.
      throw StateError('No telemetry summary is available yet.');
    }

    return _buildAnswer(input, question);
  }

  String _buildAnswer(SummaryInput input, String question) {
    final isId = input.language == SummaryLanguage.id;
    final state = input.state;
    final firmwareTier = Tier.fromStatusMessage(state.statusMessage);
    final tier = tierWord(firmwareTier ?? state.tier);
    final readings = validateSensorReadings(
      temperature: state.temperature,
      humidity: state.humidity,
      airQuality: state.airQuality,
    );

    final lower = question.toLowerCase();
    final asksWhy = RegExp(r'why|caution|stuffy|mengapa|kenapa|pengap')
        .hasMatch(lower);
    final asksWhen = RegExp(r'warm|hot|peak|when|kapan|hangat|panas|puncak')
        .hasMatch(lower);

    final lines = <String>[];

    if (firmwareTier != null) {
      lines.add(
        isId
            ? 'Perangkat melaporkan tingkat firmware $tier.'
            : 'The device reports the firmware tier as $tier.',
      );
      final message = state.statusMessage.trim();
      if (message.isNotEmpty && !isBareTierKeyword(message)) {
        lines.add(
          isId
              ? 'Pesan status perangkat: "$message"'
              : 'Device status message: "$message"',
        );
      }
    } else {
      lines.add(
        isId
            ? 'Perangkat tidak mengirim tingkat. '
                  'Aplikasi memperkirakan $tier dari pembacaan.'
            : 'The device did not send a tier. '
                  'The app estimates $tier from the readings.',
      );
    }

    if (asksWhy) {
      final thresholds = input.thresholds;
      lines.add(
        isId
            ? 'Caution mulai pada ${_one(thresholds.tempCautionMin)} °C, '
                  'Danger pada ${_one(thresholds.tempDangerMin)} °C.'
            : 'Caution starts at ${_one(thresholds.tempCautionMin)} °C, '
                  'Danger at ${_one(thresholds.tempDangerMin)} °C.',
      );
    }

    final temperature = readings.temperature;
    lines.add(
      temperature == null
          ? (isId ? 'Suhu tidak ada pembacaan.' : 'Temperature has no reading.')
          : (isId
                ? 'Suhu ${_one(temperature)} °C.'
                : 'Temperature is ${_one(temperature)} °C.'),
    );

    final airQuality = readings.airQuality;
    lines.add(
      airQuality == null
          ? (isId
                ? 'Kualitas udara tidak ada pembacaan.'
                : 'Air quality has no reading.')
          : (isId
                ? 'Indeks kualitas udara ${_zero(airQuality)} '
                      '(mentah 0-4095, bukan ppm).'
                : 'Air quality index is ${_zero(airQuality)} '
                      '(raw 0-4095, not ppm).'),
    );

    lines.add(
      state.fanOn
          ? (isId
                ? 'Kipas menyala. Perangkat yang mengendalikan kipas.'
                : 'The fan is on. The device controls the fan.')
          : (isId
                ? 'Kipas mati. Perangkat yang mengendalikan kipas.'
                : 'The fan is off. The device controls the fan.'),
    );

    final forecast = input.forecast;
    final peak = forecast.temperaturePeak;
    if (asksWhen &&
        forecast.status == ForecastSummaryStatus.active &&
        peak != null) {
      lines.add(
        isId
            ? 'Perkiraan puncak suhu sekitar $peak.'
            : 'The forecast predicts the temperature peak around $peak.',
      );
    }

    return lines.join(' ');
  }

  static String _one(double value) => value.toStringAsFixed(1);

  static String _zero(double value) => value.toStringAsFixed(0);
}
