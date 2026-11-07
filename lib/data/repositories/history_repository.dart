import 'package:aerosense_app/data/models/history_record.dart';

/// Abstract contract for reading archived telemetry records from `/history`.
abstract class HistoryRepository {
  /// Fetches historical records up to [limit] entries (ordered chronologically).
  Future<List<HistoryRecord>> fetchHistory({int limit = 288});

  /// Stream of newly appended records.
  Stream<HistoryRecord> watchNewRecords();
}
