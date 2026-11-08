import 'package:aerosense_app/data/models/history_record.dart';

/// Contract for reading archived telemetry from `/history`.
abstract class HistoryRepository {
  /// Fetches the latest [limit] history records, ordered chronologically.
  ///
  /// Returns an empty list when the node does not exist yet.
  Future<List<HistoryRecord>> fetchHistory({int limit = 288});

  /// Stream of records appended since the listener was attached.
  Stream<HistoryRecord> watchNewRecords();
}
