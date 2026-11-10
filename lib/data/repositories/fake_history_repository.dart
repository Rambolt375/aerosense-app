import 'dart:async';
import 'dart:math' as math;

import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/fake_diurnal_generator.dart';
import 'package:aerosense_app/data/repositories/history_repository.dart';

/// Fake [HistoryRepository] for Demo Mode.
///
/// Generates 7 days (1008 records, 10-minute intervals) of synthetic telemetry
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
  /// 10-minute boundary.
  final DateTime? anchor;

  /// Whether to inject deterministic anomaly events (smoke spike and heat wave).
  final bool includeAnomalies;

  /// Seed for random noise to ensure deterministic test generation.
  final int seed;

  /// Rounds a [DateTime] down to the nearest 10-minute boundary.
  static DateTime roundToTenMinutes(DateTime dt) {
    const bucketMillis = 10 * 60 * 1000;
    final millis = dt.millisecondsSinceEpoch;
    final roundedMillis = millis - (millis % bucketMillis);
    return DateTime.fromMillisecondsSinceEpoch(roundedMillis, isUtc: dt.isUtc);
  }

  /// Compatibility alias for [roundToTenMinutes].
  static DateTime roundToFiveMinutes(DateTime dt) => roundToTenMinutes(dt);

  /// Generates a deterministic 7-day synthetic history dataset.
  ///
  /// - [anchor]: End timestamp (defaults to current time rounded to 10 min).
  /// - [count]: Total records (default 1008 = 7 days at 10-minute intervals).
  /// - [interval]: Time step between records (default 10 minutes).
  /// - [includeAnomalies]: Injects cooking smoke and heat anomalies when true.
  /// - [seed]: Random seed for deterministic reproducibility.
  static List<HistoryRecord> generateHistory({
    DateTime? anchor,
    int count = 1008,
    Duration interval = const Duration(minutes: 10),
    bool includeAnomalies = true,
    int seed = 42,
  }) {
    final roundedAnchor = roundToTenMinutes(anchor ?? DateTime.now());
    final random = math.Random(seed);
    final records = <HistoryRecord>[];

    // Anomaly index windows relative to count:
    // Smoke anomaly: ~3.5 days before anchor, 3 samples (30 min duration)
    final smokeStart = count - 504;
    final smokeEnd = smokeStart + 3;

    // Heat anomaly: ~1.5 days before anchor, 4 samples (40 min duration)
    final heatStart = count - 216;
    final heatEnd = heatStart + 4;

    for (var i = 0; i < count; i++) {
      // Oldest record at index 0, newest record at index count - 1 (anchor)
      final time = roundedAnchor.subtract(interval * (count - 1 - i));

      final base = generateDiurnalSample(time, random: random, addNoise: true);
      var temp = base.temperature;
      var hum = base.humidity;
      var aq = base.airQuality;

      // Injected anomalies (if enabled)
      if (includeAnomalies) {
        if (i >= smokeStart && i < smokeEnd) {
          // Kitchen smoke spike into Danger tier (>= 2000)
          final smokePeak = 2450.0 + (random.nextDouble() - 0.5) * 80.0;
          aq = smokePeak;
        }

        if (i >= heatStart && i < heatEnd) {
          // Heat anomaly into Danger tier (>= 36.0 °C)
          temp = 36.8 + (random.nextDouble() - 0.5) * 0.6;
        }
      }

      temp = temp.clamp(15.0, 45.0);
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
  Future<List<HistoryRecord>> fetchHistory({int limit = 144}) async {
    final all = generateHistory(
      anchor: anchor,
      count: 1008,
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
