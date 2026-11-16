import 'package:aerosense_app/features/summary/summary_models.dart';

/// All English and Indonesian summary content in one place.
///
/// Tier words stay canonical in both languages. Air quality is always a raw
/// ADC index and the only mention of ppm is the explicit "not ppm" unit note.
class SummaryCopy {
  const SummaryCopy(this.language);

  final SummaryLanguage language;

  bool get _isId => language == SummaryLanguage.id;

  // --- Headings ---

  String get statusHeading => 'Status';

  /// Heading for the live readings block.
  ///
  /// When the device is offline the block is stale, so the heading says
  /// "Last reading" instead of implying a live snapshot. The time is included
  /// when the provider knows it.
  String readingsHeading({bool deviceOffline = false, String? lastDataLabel}) {
    if (!deviceOffline) {
      return _isId ? 'Saat ini' : 'Right now';
    }
    if (lastDataLabel == null || lastDataLabel.isEmpty) {
      return _isId ? 'Pembacaan terakhir' : 'Last reading';
    }
    return _isId
        ? 'Pembacaan terakhir ($lastDataLabel)'
        : 'Last reading ($lastDataLabel)';
  }

  String get forecastHeading => _isId ? 'Perkiraan' : 'Forecast';

  String historyHeading(int? sampleCount) {
    if (sampleCount == null || sampleCount <= 0) {
      return _isId ? '24 jam terakhir' : 'Last 24 hours';
    }
    if (_isId) return '24 jam terakhir ($sampleCount pembacaan)';
    final unit = sampleCount == 1 ? 'reading' : 'readings';
    return 'Last 24 hours ($sampleCount $unit)';
  }

  // --- Status ---

  String firmwareTier(String tier) =>
      _isId ? 'Tingkat firmware: $tier' : 'Firmware tier: $tier';

  String displayedTier(String tier) => _isId
      ? 'Tingkat yang ditampilkan: $tier '
            '(diperkirakan dari pembacaan; perangkat tidak mengirim tingkat)'
      : 'Displayed tier: $tier '
            '(estimated from readings; the device did not send a tier)';

  String statusMessage(String message) => _isId
      ? 'Pesan status perangkat: "$message"'
      : 'Device status message: "$message"';

  /// Fan state line.
  ///
  /// [lastReported] is used while the device is offline: the fan state is the
  /// last value the device published, not a live command, so the copy must not
  /// imply the app is controlling it now.
  String fanLine(bool fanOn, {bool lastReported = false}) {
    if (lastReported) {
      return _isId
          ? 'Kipas: terakhir dilaporkan ${fanOn ? 'menyala' : 'mati'}.'
          : 'Fan: last reported ${fanOn ? 'on' : 'off'}.';
    }
    return _isId
        ? 'Kipas: ${fanOn ? 'menyala' : 'mati'}. '
              'Perangkat yang mengendalikan kipas.'
        : 'Fan: ${fanOn ? 'on' : 'off'}. The device controls the fan.';
  }

  List<String> deviceLines(DeviceSummary device) {
    switch (device.state) {
      case DeviceSummaryState.online:
        return [_isId ? 'Perangkat: online.' : 'Device: online.'];
      case DeviceSummaryState.offline:
        final label = device.lastDataLabel;
        if (label == null || label.isEmpty) {
          return [
            _isId
                ? 'Perangkat: offline. Waktu data terakhir tidak diketahui.'
                : 'Device: offline. Last data time unknown.',
          ];
        }
        return [
          _isId
              ? 'Perangkat: offline. Data terakhir $label.'
              : 'Device: offline. Last data at $label.',
          _isId
              ? 'Pembacaan berasal dari waktu tersebut.'
              : 'Readings are from that time.',
        ];
      case DeviceSummaryState.unknown:
        return [
          _isId
              ? 'Status perangkat tidak diketahui.'
              : 'Device: status unknown.',
        ];
    }
  }

  String get appOffline => _isId
      ? 'Aplikasi offline. Menampilkan data terakhir yang diterima.'
      : 'The app is offline. Showing the last data received.';

  // --- Live readings ---

  String get temperatureNoReading =>
      _isId ? 'Suhu: tidak ada pembacaan' : 'Temperature: no reading';

  String get humidityNoReading =>
      _isId ? 'Kelembapan: tidak ada pembacaan' : 'Humidity: no reading';

  String get airQualityNoReading =>
      _isId ? 'Kualitas udara: tidak ada pembacaan' : 'Air quality: no reading';

  String temperatureReading(double value, double caution, double danger) =>
      _isId
      ? 'Suhu: ${_one(value)} °C '
            '(Caution pada ${_one(caution)} °C, '
            'Danger pada ${_one(danger)} °C)'
      : 'Temperature: ${_one(value)} °C '
            '(Caution at ${_one(caution)} °C, '
            'Danger at ${_one(danger)} °C)';

  String humidityReading(
    double value,
    double caution,
    double danger, {
    required bool confirmedByFirmware,
  }) {
    if (!confirmedByFirmware) {
      return _isId
          ? 'Kelembapan: ${_one(value)} % RH'
          : 'Humidity: ${_one(value)} % RH';
    }
    return _isId
        ? 'Kelembapan: ${_one(value)} % RH '
              '(Caution pada ${_one(caution)} % RH, '
              'Danger pada ${_one(danger)} % RH)'
        : 'Humidity: ${_one(value)} % RH '
              '(Caution at ${_one(caution)} % RH, '
              'Danger at ${_one(danger)} % RH)';
  }

  String get humidityNotUsed => _isId
      ? 'Ambang kelembapan: belum digunakan oleh perangkat.'
      : 'Humidity thresholds: not used by the device yet.';

  String airQualityReading(double value, double caution, double danger) => _isId
      ? 'Kualitas udara: indeks ${_zero(value)} '
            '(tidak terkalibrasi 0–4095, bukan ppm; '
            'Caution pada ${_zero(caution)}, '
            'Danger pada ${_zero(danger)})'
      : 'Air quality: index ${_zero(value)} '
            '(uncalibrated 0–4095, not ppm; '
            'Caution at ${_zero(caution)}, '
            'Danger at ${_zero(danger)})';

  // --- 24-hour history ---

  String get limitedData => _isId ? 'Data terbatas.' : 'Limited data.';

  String get noHistory => _isId
      ? 'Tidak ada pembacaan bertanda waktu dalam 24 jam terakhir.'
      : 'No timestamped readings in the last 24 hours.';

  String get loadingHistory =>
      _isId ? 'Memuat riwayat 24 jam...' : 'Loading 24-hour history...';

  String get historyUnavailable => _isId
      ? 'Riwayat 24 jam tidak tersedia.'
      : '24-hour history is unavailable.';

  String temperatureStats(double min, double max, double mean) => _isId
      ? 'Suhu: min ${_one(min)} °C, rata-rata ${_one(mean)} °C, '
            'maks ${_one(max)} °C'
      : 'Temperature: min ${_one(min)} °C, mean ${_one(mean)} °C, '
            'max ${_one(max)} °C';

  String humidityStats(double min, double max, double mean) => _isId
      ? 'Kelembapan: min ${_one(min)} % RH, '
            'rata-rata ${_one(mean)} % RH, maks ${_one(max)} % RH'
      : 'Humidity: min ${_one(min)} % RH, '
            'mean ${_one(mean)} % RH, max ${_one(max)} % RH';

  String airQualityStats(double min, double max, double mean) => _isId
      ? 'Kualitas udara: min ${_zero(min)}, '
            'rata-rata ${_zero(mean)}, maks ${_zero(max)}'
      : 'Air quality: min ${_zero(min)}, '
            'mean ${_zero(mean)}, max ${_zero(max)}';

  // --- Forecast ---

  String get forecastActive =>
      _isId ? 'Perkiraan aktif.' : 'Forecast is active.';

  String temperaturePeak(String time) => _isId
      ? 'Perkiraan puncak suhu sekitar $time.'
      : 'Predicted temperature peak around $time.';

  String airQualityPeak(String time) => _isId
      ? 'Perkiraan puncak kualitas udara sekitar $time.'
      : 'Predicted air quality peak around $time.';

  String get forecastLockedOut => _isId
      ? 'Perkiraan terkunci. Keputusan keselamatan berasal dari perangkat.'
      : 'Forecast is locked out. '
            'Safety decisions come from the device.';

  String get forecastPaused => _isId
      ? 'Perkiraan dijeda selama perangkat offline.'
      : 'Forecast is paused while the device is offline.';

  String get forecastLearning => _isId
      ? 'Perkiraan masih dalam pembelajaran.'
      : 'The forecast is still learning.';

  String learningProgress(int percent) => _isId
      ? 'Kemajuan pembelajaran: $percent%.'
      : 'Learning progress: $percent%.';

  String get forecastWaiting => _isId
      ? 'Perkiraan menunggu tanda waktu asli dari perangkat.'
      : 'The forecast is waiting for real device timestamps.';

  String get forecastUnavailable =>
      _isId ? 'Tidak ada data perkiraan.' : 'No forecast data.';

  // --- Formatting ---

  static String _one(double value) => value.toStringAsFixed(1);

  static String _zero(double value) => value.toStringAsFixed(0);
}
