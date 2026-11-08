import 'package:firebase_database/firebase_database.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/history_repository.dart';

/// Firebase Realtime Database implementation of [HistoryRepository].
///
/// Note: /history does not yet exist in real data. This implementation is
/// correct for when it does. See PRD §5.2.
class FirebaseHistoryRepository implements HistoryRepository {
  FirebaseHistoryRepository({FirebaseDatabase? db})
    : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  @override
  Future<List<HistoryRecord>> fetchHistory({int limit = 288}) async {
    final snapshot = await _db
        .ref('history')
        .orderByKey()
        .limitToLast(limit)
        .get();
    if (!snapshot.exists) return [];

    // Children are in RTDB's natural key order (ascending push-key = ascending time).
    return snapshot.children
        .map(
          (child) => HistoryRecord.fromSnapshot(child.key ?? '', child.value),
        )
        .toList();
  }

  @override
  Stream<HistoryRecord> watchNewRecords() {
    return _db
        .ref('history')
        .orderByKey()
        .limitToLast(1)
        .onChildAdded
        .map(
          (event) => HistoryRecord.fromSnapshot(
            event.snapshot.key ?? '',
            event.snapshot.value,
          ),
        );
  }
}
