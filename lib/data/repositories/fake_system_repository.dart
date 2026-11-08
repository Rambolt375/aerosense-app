import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/system_repository.dart';

/// Fake [SystemRepository] for Demo Mode.
///
/// Emits a plausible static SystemState. The sinusoidal simulation and
/// scripted Danger spike are added in Phase 3 (Demo Mode).
class FakeSystemRepository implements SystemRepository {
  static const _state = SystemState(
    temperature: 27.0,
    humidity: 55.0,
    airQuality: 820.0,
    fanOn: false,
    manualToggle: false,
    statusMessage: 'System Safe',
  );

  @override
  Stream<SystemState> watchSystemState() =>
      Stream.periodic(const Duration(seconds: 2), (_) => _state);

  @override
  Stream<Object?> watchRawSystem() => Stream.periodic(
    const Duration(seconds: 2),
    (_) => <String, dynamic>{
      'temperature': 27.0,
      'humidity': 55.0,
      'airQuality': 820.0,
      'fanStatus': 'OFF',
      'manualToggle': false,
      'statusMessage': 'System Safe',
    },
  );

  @override
  Future<void> setManualToggle(bool value) async {
    // No-op in demo; Phase 3 will simulate the toggle effect.
  }

  @override
  Stream<bool> watchConnected() => Stream.value(true);
}
