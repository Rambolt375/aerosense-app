import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/features/summary/summary_builder.dart';
import 'package:aerosense_app/features/summary/summary_models.dart';

void main() {
  final now = DateTime(2026, 11, 15, 14, 10);

  SummaryInput buildInput({
    SystemState? state,
    ThresholdPreset? thresholds,
    DeviceSummary? device,
    ForecastSummary? forecast,
    HistoryStats24h? history,
    HistoryAvailability historyAvailability = HistoryAvailability.ready,
    SummaryLanguage language = SummaryLanguage.en,
    bool appConnected = true,
  }) {
    return SummaryInput(
      state:
          state ??
          const SystemState(
            temperature: 34.1,
            humidity: 58.0,
            airQuality: 1520,
            fanOn: false,
            statusMessage: 'CAUTION: The environment is stuffy.',
            tier: Tier.medium,
          ),
      thresholds: thresholds ?? ThresholdPreset.firmware,
      device:
          device ??
          const DeviceSummary(
            state: DeviceSummaryState.online,
            lastDataLabel: '14:05',
          ),
      forecast:
          forecast ??
          const ForecastSummary(
            status: ForecastSummaryStatus.active,
            temperaturePeak: '15:00',
            airQualityPeak: '15:10',
          ),
      history:
          history ??
          const HistoryStats24h(
            sampleCount: 143,
            temperature: MetricStats(min: 27.8, max: 34.9, mean: 31.4),
            humidity: MetricStats(min: 51.0, max: 64.0, mean: 57.0),
            airQuality: MetricStats(min: 820, max: 1610, mean: 1180),
          ),
      language: language,
      now: now,
      historyAvailability: historyAvailability,
      appConnected: appConnected,
    );
  }

  String textFor(SummaryInput input) => buildSummary(input).plainText;

  group('buildSummary English', () {
    test('quotes the firmware tier and the descriptive status message', () {
      final text = textFor(buildInput());

      expect(text, contains('Firmware tier: Caution'));
      expect(
        text,
        contains(
          'Device status message: "CAUTION: The environment is stuffy."',
        ),
      );
      expect(text, contains('Fan: off. The device controls the fan.'));
    });

    test('renders live readings with preset-driven thresholds', () {
      final text = textFor(buildInput());

      expect(
        text,
        contains(
          'Temperature: 34.1 °C (Caution at 33.5 °C, Danger at 36.0 °C)',
        ),
      );
      expect(text, contains('Humidity: 58.0 % RH'));
      expect(
        text,
        contains(
          'Air quality: index 1520 (uncalibrated 0–4095, not ppm; '
          'Caution at 1400, Danger at 2000)',
        ),
      );
    });

    test('never labels air quality as ppm', () {
      final text = textFor(buildInput()).toLowerCase();
      // The unit note itself says "not ppm"; no other occurrence is allowed.
      expect('ppm'.allMatches(text).length, 1);
    });

    test('renders 24 hour stats with sample count', () {
      final text = textFor(buildInput());

      expect(text, contains('Last 24 hours (143 readings)'));
      expect(
        text,
        contains('Temperature: min 27.8 °C, mean 31.4 °C, max 34.9 °C'),
      );
      expect(
        text,
        contains('Humidity: min 51.0 % RH, mean 57.0 % RH, max 64.0 % RH'),
      );
      expect(text, contains('Air quality: min 820, mean 1180, max 1610'));
    });

    test('renders forecast peaks with the approved label', () {
      final text = textFor(buildInput());

      expect(text, contains('Forecast is active.'));
      expect(text, contains('Predicted temperature peak around 15:00.'));
      expect(text, contains('Predicted air quality peak around 15:10.'));
    });

    test('quotes a bare keyword tier but does not quote the message', () {
      final text = textFor(
        buildInput(
          state: const SystemState(
            temperature: 34.1,
            statusMessage: 'CAUTION',
            tier: Tier.medium,
          ),
        ),
      );

      expect(text, contains('Firmware tier: Caution'));
      expect(text, isNot(contains('"CAUTION"')));
      expect(text, isNot(contains('Device status message')));
    });

    test('treats SAFE, DANGER, NORMAL and MEDIUM as bare keywords', () {
      expect(isBareTierKeyword('SAFE'), isTrue);
      expect(isBareTierKeyword(' danger '), isTrue);
      expect(isBareTierKeyword('NORMAL'), isTrue);
      expect(isBareTierKeyword('MEDIUM'), isTrue);
      expect(isBareTierKeyword('CAUTION: The environment is stuffy.'), isFalse);
      expect(isBareTierKeyword('System Safe'), isFalse);
      expect(isBareTierKeyword(''), isFalse);
    });

    test('reports an estimated tier when the device sent no tier', () {
      final text = textFor(
        buildInput(
          state: const SystemState(
            temperature: 34.1,
            statusMessage: 'Something unexpected',
            tier: Tier.medium,
          ),
        ),
      );

      expect(text, contains('Displayed tier: Caution'));
      expect(text, contains('estimated from readings'));
      expect(text, isNot(contains('Firmware tier')));
      expect(text, contains('Device status message: "Something unexpected"'));
    });

    test('does not quote an empty status message', () {
      final text = textFor(
        buildInput(
          state: const SystemState(statusMessage: '', tier: Tier.safe),
        ),
      );

      expect(text, isNot(contains('Device status message')));
    });

    test('quotes the Danger tier from the firmware', () {
      final text = textFor(
        buildInput(
          state: const SystemState(
            temperature: 36.5,
            airQuality: 2100,
            statusMessage: 'DANGER',
            tier: Tier.danger,
          ),
        ),
      );

      expect(text, contains('Firmware tier: Danger'));
      expect(text, isNot(contains('"DANGER"')));
    });

    test('renders missing readings as "no reading"', () {
      final text = textFor(
        buildInput(
          state: const SystemState(statusMessage: 'SAFE', tier: Tier.safe),
          history: const HistoryStats24h(),
        ),
      );

      expect(text, contains('Temperature: no reading'));
      expect(text, contains('Humidity: no reading'));
      expect(text, contains('Air quality: no reading'));
      expect(text, isNot(contains('NaN')));
      expect(text, isNot(contains('null')));
    });

    test('leads with the offline device line and marks stale readings', () {
      final text = textFor(
        buildInput(
          device: const DeviceSummary(
            state: DeviceSummaryState.offline,
            lastDataLabel: '12:40',
          ),
        ),
      );

      final lines = text.split('\n');
      expect(lines[1], 'Device: offline. Last data at 12:40.');
      expect(text, contains('Readings are from that time.'));
      expect(text, contains('Last reading (12:40)'));
      expect(text, contains('Fan: last reported off.'));
      expect(text, isNot(contains('Right now')));
      expect(text, isNot(contains('The device controls the fan')));
    });

    test('uses the last-reported fan line when the device is offline', () {
      final text = textFor(
        buildInput(
          state: const SystemState(fanOn: true, statusMessage: 'SAFE'),
          device: const DeviceSummary(
            state: DeviceSummaryState.offline,
            lastDataLabel: '12:40',
          ),
        ),
      );

      expect(text, contains('Fan: last reported on.'));
    });

    test('handles an offline device with an unknown last data time', () {
      final text = textFor(
        buildInput(
          device: const DeviceSummary(state: DeviceSummaryState.offline),
        ),
      );

      expect(text, contains('Last data time unknown.'));
      expect(text, isNot(contains('Last data at')));
      expect(text, contains('Last reading'));
      expect(text, isNot(contains('Last reading (')));
      expect(text, contains('Fan: last reported off.'));
    });

    test('reports an unknown device state without claiming offline', () {
      final text = textFor(
        buildInput(
          device: const DeviceSummary(state: DeviceSummaryState.unknown),
        ),
      );

      expect(text, contains('Device: status unknown.'));
      expect(text, isNot(contains('offline')));
    });

    test('adds an app offline line', () {
      final text = textFor(buildInput(appConnected: false));

      expect(
        text,
        contains('The app is offline. Showing the last data received.'),
      );
    });

    test('reports empty history instead of inventing values', () {
      final text = textFor(buildInput(history: const HistoryStats24h()));

      expect(text, contains('No timestamped readings in the last 24 hours.'));
      expect(text, isNot(contains('mean')));
    });

    test('does not claim empty history while it is loading', () {
      final text = textFor(
        buildInput(
          history: const HistoryStats24h(),
          historyAvailability: HistoryAvailability.loading,
        ),
      );

      expect(text, contains('Loading 24-hour history'));
      expect(text, isNot(contains('No timestamped readings')));
    });

    test('reports unavailable history', () {
      final text = textFor(
        buildInput(
          history: const HistoryStats24h(),
          historyAvailability: HistoryAvailability.unavailable,
        ),
      );

      expect(text, contains('24-hour history is unavailable.'));
      expect(text, isNot(contains('No timestamped readings')));
    });

    test('marks sparse history', () {
      final text = textFor(
        buildInput(
          history: const HistoryStats24h(
            sampleCount: 3,
            temperature: MetricStats(min: 30, max: 31, mean: 30.5),
          ),
        ),
      );

      expect(text, contains('Limited data.'));
      expect(text, contains('Last 24 hours (3 readings)'));
    });

    test('does not present humidity limits as firmware thresholds', () {
      final text = textFor(buildInput());

      expect(
        text,
        contains('Humidity thresholds: not used by the device yet.'),
      );
      expect(text, isNot(contains('Caution at 60.0 % RH')));
    });

    test('shows humidity limits once the preset is confirmed', () {
      const confirmed = ThresholdPreset(
        name: 'confirmed',
        tempCautionMin: 33.5,
        tempDangerMin: 36.0,
        airQualityCautionMin: 1400,
        airQualityDangerMin: 2000,
        airQualityRecovery: 1250,
        humidityCautionMin: 60.0,
        humidityDangerMin: 75.0,
        humidityConfirmedByFirmware: true,
      );

      final text = textFor(buildInput(thresholds: confirmed));

      expect(
        text,
        contains(
          'Humidity: 58.0 % RH (Caution at 60.0 % RH, Danger at 75.0 % RH)',
        ),
      );
      expect(text, isNot(contains('not used by the device yet')));
    });

    test('uses thresholds from the active preset, not hard-coded values', () {
      final demoText = textFor(buildInput(thresholds: ThresholdPreset.demo));
      final firmwareText = textFor(buildInput());

      expect(demoText, contains('Caution at 28.0 °C'));
      expect(demoText, contains('Caution at 1000'));
      expect(firmwareText, contains('Caution at 33.5 °C'));
      expect(firmwareText, isNot(contains('Caution at 28.0 °C')));
    });

    test('renders locked out forecast state', () {
      final text = textFor(
        buildInput(
          forecast: const ForecastSummary(
            status: ForecastSummaryStatus.lockedOut,
          ),
        ),
      );

      expect(
        text,
        contains(
          'Forecast is locked out. Safety decisions come from the device.',
        ),
      );
      expect(text, isNot(contains('Predicted')));
    });

    test('renders the paused forecast state while the device is offline', () {
      final text = textFor(
        buildInput(
          forecast: const ForecastSummary(status: ForecastSummaryStatus.paused),
        ),
      );

      expect(text, contains('Forecast is paused while the device is offline.'));
      expect(text, isNot(contains('locked out')));
      expect(text, isNot(contains('Predicted')));
    });

    test('renders learning forecast state with progress', () {
      final text = textFor(
        buildInput(
          forecast: const ForecastSummary(
            status: ForecastSummaryStatus.learning,
            learningPercent: 42,
          ),
        ),
      );

      expect(text, contains('The forecast is still learning.'));
      expect(text, contains('Learning progress: 42%.'));
    });

    test('renders waiting-for-timestamps and unavailable forecast states', () {
      final waiting = textFor(
        buildInput(
          forecast: const ForecastSummary(
            status: ForecastSummaryStatus.waitingForTimestamps,
          ),
        ),
      );
      final unavailable = textFor(
        buildInput(
          forecast: const ForecastSummary(
            status: ForecastSummaryStatus.unavailable,
          ),
        ),
      );

      expect(waiting, contains('waiting for real device timestamps'));
      expect(unavailable, contains('No forecast data.'));
    });

    test('gives no safety advice or fan instruction', () {
      final text = textFor(buildInput()).toLowerCase();

      expect(text, isNot(contains('you should')));
      expect(text, isNot(contains('open a window')));
      expect(text, isNot(contains('turn on the fan')));
      expect(text, isNot(contains('recommend')));
    });
  });

  group('buildSummary Indonesian', () {
    test('renders Indonesian headings and content', () {
      final text = textFor(buildInput(language: SummaryLanguage.id));

      expect(text, contains('Tingkat firmware: Caution'));
      expect(text, contains('Saat ini'));
      expect(text, contains('24 jam terakhir (143 pembacaan)'));
      expect(text, contains('Suhu: 34.1 °C'));
      expect(text, contains('bukan ppm'));
      expect(text, contains('Perkiraan puncak suhu sekitar 15:00.'));
      expect(text, contains('Perkiraan puncak kualitas udara sekitar 15:10.'));
      expect(text, contains('Perangkat yang mengendalikan kipas.'));
    });

    test('keeps the canonical tier words in Indonesian', () {
      final text = textFor(buildInput(language: SummaryLanguage.id));

      expect(text, contains('Caution'));
      expect(text, isNot(contains('Hati-hati')));
    });

    test('renders Indonesian offline copy and heading', () {
      final text = textFor(
        buildInput(
          language: SummaryLanguage.id,
          device: const DeviceSummary(
            state: DeviceSummaryState.offline,
            lastDataLabel: '12:40',
          ),
          history: const HistoryStats24h(),
        ),
      );

      final lines = text.split('\n');
      expect(lines[1], 'Perangkat: offline. Data terakhir 12:40.');
      expect(text, contains('Pembacaan berasal dari waktu tersebut.'));
      expect(text, contains('Pembacaan terakhir (12:40)'));
      expect(text, contains('Kipas: terakhir dilaporkan mati.'));
      expect(text, isNot(contains('Saat ini')));
      expect(
        text,
        contains('Tidak ada pembacaan bertanda waktu dalam 24 jam terakhir.'),
      );
      expect(
        text,
        contains('Ambang kelembapan: belum digunakan oleh perangkat.'),
      );
    });

    test('renders the Indonesian paused forecast state', () {
      final text = textFor(
        buildInput(
          language: SummaryLanguage.id,
          forecast: const ForecastSummary(status: ForecastSummaryStatus.paused),
        ),
      );

      expect(text, contains('Perkiraan dijeda selama perangkat offline.'));
      expect(text, isNot(contains('terkunci')));
    });
  });
}
