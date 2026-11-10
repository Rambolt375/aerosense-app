import 'dart:async';
import 'dart:math' as math;

import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/history_repository.dart';

/// Fake [HistoryRepository] for Demo Mode.
///
/// Generates 7 days (2016 records, 5-minute intervals) of synthetic telemetry
/// following a diurnal sinusoidal wave with noise and seeded anomalies.
///
/// NOTE on Air Quality: Synthetic air quality has an engineered dominant 24-hour
/// sinusoidal component to enable linear least-squares model fitting for the
/// Phase 5 diurnal forecast layer (PRD §FR-6). In a real home, indoor air
/// quality is episodic and messier (cooking, cleaning, ventilation transients).
class FakeHistoryRepository implements HistoryRepository {
  FakeHistoryRepository({
    this.anchor,
    this.includeAnomalies = true,
    this.seed = 42,
  });

  /// Reference time anchor. If null, uses the current time rounded to a
  /// 5-minute boundary.
  final DateTime? anchor;

  /// Whether to inject deterministic anomaly events (smoke spike and heat wave).
  final bool includeAnomalies;

  /// Seed for random noise to ensure deterministic test generation.
  final int seed;

  /// Rounds a [DateTime] down to the nearest 5-minute boundary.
  static DateTime roundToFiveMinutes(DateTime dt) {
    const bucketMillis = 5 * 60 * 1000;
    final millis = dt.millisecondsSinceEpoch;
    final roundedMillis = millis - (millis % bucketMillis);
    return DateTime.fromMillisecondsSinceEpoch(roundedMillis, isUtc: dt.isUtc);
  }

  /// Generates a deterministic 7-day synthetic history dataset.
  ///
  /// - [anchor]: End timestamp (defaults to current time rounded to 5 min).
  /// - [count]: Total records (default 2016 = 7 days at 5-minute intervals).
  /// - [interval]: Time step between records (default 5 minutes).
  /// - [includeAnomalies]: Injects cooking smoke and heat anomalies when true.
  /// - [seed]: Random seed for deterministic reproducibility.
  static List<HistoryRecord> generateHistory({
    DateTime? anchor,
    int count = 2016,
    Duration interval = const Duration(minutes: 5),
    bool includeAnomalies = true,
    int seed = 42,
  }) {
    final roundedAnchor = roundToFiveMinutes(anchor ?? DateTime.now());
    final random = math.Random(seed);
    final records = <HistoryRecord>[];

    // Anomaly index windows relative to count:
    // Smoke anomaly: ~3.5 days before anchor, 6 samples (30 min duration)
    final smokeStart = count - 1008;
    final smokeEnd = smokeStart + 6;

    // Heat anomaly: ~1.5 days before anchor, 8 samples (40 min duration)
    final heatStart = count - 432;
    final heatEnd = heatStart + 8;

    for (var i = 0; i < count; i++) {
      // Oldest record at index 0, newest record at index count - 1 (anchor)
      final time = roundedAnchor.subtract(interval * (count - 1 - i));

      // Time-of-day in local time for diurnal wave
      final secondsSinceMidnight =
          time.hour * 3600 + time.minute * 60 + time.second;
      final theta = 2 * math.pi * (secondsSinceMidnight / 86400.0);
      final hourOfDay = secondsSinceMidnight / 3600.0;

      // 1. Temperature: Peak at ~15:00 (~29.5 °C), trough at ~03:00 (~20.5 °C)
      // Phase angle: theta_15:00 = 1.25 pi -> sin(theta - 0.75 pi) = 1 at 15:00
      final tempNoise = (random.nextDouble() - 0.5) * 0.5;
      var temp = 25.0 + 4.5 * math.sin(theta - 0.75 * math.pi) + tempNoise;

      // 2. Humidity: Inverse diurnal cycle (peaks at night, drops in afternoon heat)
      final humNoise = (random.nextDouble() - 0.5) * 1.5;
      var hum = 55.0 - 12.0 * math.sin(theta - 0.75 * math.pi) + humNoise;

      // 3. Air Quality:
      // Dominant 24-hour sinusoidal component peaking in the evening (~18:00):
      // theta_18:00 = 1.5 pi -> sin(theta - pi) = 1 at 18:00
      final aqSinWave = 750.0 + 180.0 * math.sin(theta - math.pi);

      // Morning bump (~08:30) and evening cooking bump (~19:30)
      final morningBump = 100.0 * math.exp(-math.pow(hourOfDay - 8.5, 2) / 2.0);
      final eveningBump =
          140.0 * math.exp(-math.pow(hourOfDay - 19.5, 2) / 2.0);
      final aqNoise = (random.nextDouble() - 0.5) * 30.0;

      var aq = aqSinWave + morningBump + eveningBump + aqNoise;

      // 4. Injected anomalies (if enabled)
      if (includeAnomalies) {
        if (i >= smokeStart && i < smokeEnd) {
          // Kitchen smoke spike into Danger tier (> 2000)
          final smokePeak = 2450.0 + (random.nextDouble() - 0.5) * 80.0;
          aq = smokePeak;
        }

        if (i >= heatStart && i < heatEnd) {
          // Heat anomaly into Danger tier (> 32 °C)
          temp = 33.5 + (random.nextDouble() - 0.5) * 0.6;
        }
      }

      // Clamping to physical bounds
      temp = temp.clamp(15.0, 42.0);
      hum = hum.clamp(10.0, 95.0);
      aq = aq.clamp(100.0, 4095.0);

      records.add(
        HistoryRecord(
          pushKey: 'fake-hist-${i.toString().padLeft(4, '0')}',
          timestamp: time,
          temperature: double.parse(temp.toStringAsFixed(1)),
          humidity: double.parse(hum.toStringAsFixed(1)),
          airQuality: double.parse(aq.toStringAsFixed(0)),
        ),
      );
    }

    return records;
  }

  @override
  Future<List<HistoryRecord>> fetchHistory({int limit = 288}) async {
    final all = generateHistory(
      anchor: anchor,
      count: 2016,
      includeAnomalies: includeAnomalies,
      seed: seed,
    );
    if (limit >= all.length) return all;
    return all.sublist(all.length - limit);
  }

  final _newRecordsController = StreamController<HistoryRecord>.broadcast();

  /// Emits a new record to [watchNewRecords] subscribers.
  void emitNewRecord(HistoryRecord record) {
    if (!_newRecordsController.isClosed) {
      _newRecordsController.add(record);
    }
  }

  /// Closes internal stream controllers.
  void dispose() {
    _newRecordsController.close();
  }

  @override
  Stream<HistoryRecord> watchNewRecords() => _newRecordsController.stream;
}
