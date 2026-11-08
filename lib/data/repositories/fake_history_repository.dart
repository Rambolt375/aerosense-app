import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/history_repository.dart';

/// Fake [HistoryRepository] for Demo Mode.
///
/// Returns 12 synthetic records (1 hour of 5-minute data) with stable values.
/// Phase 3 (Demo Mode) will replace this with a sinusoidal simulation.
class FakeHistoryRepository implements HistoryRepository {
  @override
  Future<List<HistoryRecord>> fetchHistory({int limit = 288}) async {
    final now = DateTime.now();
    return List.generate(12, (i) {
      final t = now.subtract(Duration(minutes: (11 - i) * 5));
      return HistoryRecord(
        pushKey: 'fake-${i.toString().padLeft(2, '0')}',
        timestamp: t,
        temperature: 27.0,
        humidity: 55.0,
        airQuality: 820.0,
      );
    });
  }

  @override
  Stream<HistoryRecord> watchNewRecords() => const Stream.empty();
}
