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
  Future<void> requestManualVentilation() {
    // Writes ONLY `true` to /system/manualToggle — never writes false, never writes whole node.
    // The ESP32 firmware owns duration, fan latch, and resets manualToggle itself.
    return _db.ref('system/manualToggle').set(true);
  }

  @override
  Stream<Map<String, dynamic>?> watchConfig() {
    return _db.ref('config').onValue.map((event) {
      final value = event.snapshot.value;
      if (value is Map) {
        return Map<String, dynamic>.from(value);
      }
      return null;
    });
  }

  @override
  Stream<bool> watchConnected() {
    return _db
        .ref('.info/connected')
        .onValue
        .map((event) => (event.snapshot.value as bool?) ?? false);
  }
}
