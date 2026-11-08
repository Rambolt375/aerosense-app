import 'package:firebase_database/firebase_database.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';

/// Firebase Realtime Database implementation of [SystemRepository].
class FirebaseSystemRepository implements SystemRepository {
  FirebaseSystemRepository({FirebaseDatabase? db})
    : _db = db ?? FirebaseDatabase.instance;

  final FirebaseDatabase _db;

  @override
  Stream<SystemState> watchSystemState() {
    return _db
        .ref('system')
        .onValue
        .map((event) => SystemState.fromJson(event.snapshot.value));
  }

  @override
  Stream<Object?> watchRawSystem() {
    return _db.ref('system').onValue.map((event) => event.snapshot.value);
  }

  @override
  Future<void> setManualToggle(bool value) {
    // Writes ONLY to /system/manualToggle — never the whole /system node.
    // The ESP32 owns every other field under /system.
    return _db.ref('system/manualToggle').set(value);
  }

  @override
  Stream<bool> watchConnected() {
    return _db
        .ref('.info/connected')
        .onValue
        .map((event) => (event.snapshot.value as bool?) ?? false);
  }
}
