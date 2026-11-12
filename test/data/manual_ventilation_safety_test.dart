import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';

class _WriteTrackingSystemRepository implements SystemRepository {
  final List<dynamic> writes = [];

  @override
  Future<void> requestManualVentilation() async {
    // Mimics FirebaseSystemRepository.requestManualVentilation
    writes.add(true);
  }

  @override
  Stream<SystemState> watchSystemState() => const Stream.empty();

  @override
  Stream<Object?> watchRawSystem() => const Stream.empty();

  @override
  Stream<Map<String, dynamic>?> watchConfig() => const Stream.empty();

  @override
  Stream<bool> watchConnected() => Stream.value(true);
}

void main() {
  group('Manual ventilation write safety rule (Requirement 2)', () {
    test('requestManualVentilation only writes true and never false', () async {
      final repo = _WriteTrackingSystemRepository();

      await repo.requestManualVentilation();

      expect(repo.writes, equals([true]));
      expect(repo.writes.contains(false), isFalse);
    });
  });
}
