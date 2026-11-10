import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/history_record.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/history/history_notifier.dart';

void main() {
  group('DeviceStatusNotifier', () {
    test('empty history reports unknown status (no false offline claim)', () {
      final container = ProviderContainer(
        overrides: [
          demoModeProvider.overrideWith(() => _FakeDemoModeNotifier(false)),
          historyNotifierProvider.overrideWith(
            () => _FakeHistoryNotifier(
              const AsyncData(HistoryState(allRecords: [])),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = container.read(deviceStatusProvider);
      expect(status.status, equals(DeviceOnlineStatus.unknown));
      expect(status.isUnknown, isTrue);
      expect(status.isOffline, isFalse);
      expect(status.isOnline, isFalse);
    });

    test('history error reports unknown status', () {
      final container = ProviderContainer(
        overrides: [
          demoModeProvider.overrideWith(() => _FakeDemoModeNotifier(false)),
          historyNotifierProvider.overrideWith(
            () => _FakeHistoryNotifier(
              AsyncError('Fetch failed', StackTrace.empty),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = container.read(deviceStatusProvider);
      expect(status.status, equals(DeviceOnlineStatus.unknown));
      expect(status.isUnknown, isTrue);
    });

    test('recent record (<= 20 min) reports online', () async {
      final now = DateTime(2026, 11, 10, 14, 30);
      final recordTime = now.subtract(
        const Duration(minutes: 10),
      ); // 1 cycle ago

      final container = ProviderContainer(
        overrides: [
          demoModeProvider.overrideWith(() => _FakeDemoModeNotifier(false)),
          clockProvider.overrideWithValue(() => now),
          historyNotifierProvider.overrideWith(
            () => _FakeHistoryNotifier(
              AsyncData(
                HistoryState(
                  allRecords: [
                    HistoryRecord(
                      pushKey: 'rec-1',
                      timestamp: recordTime,
                      temperature: 25.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(historyNotifierProvider.future);

      final status = container.read(deviceStatusProvider);
      expect(status.status, equals(DeviceOnlineStatus.online));
      expect(status.isOnline, isTrue);
      expect(status.isOffline, isFalse);
      expect(status.lastSeen, equals(recordTime));
    });

    test('stale record (> 20 min / 2 missed cycles) reports offline with formatted time', () async {
      final now = DateTime(2026, 11, 10, 14, 30);
      final recordTime = now.subtract(const Duration(minutes: 21));

      final container = ProviderContainer(
        overrides: [
          demoModeProvider.overrideWith(() => _FakeDemoModeNotifier(false)),
          clockProvider.overrideWithValue(() => now),
          historyNotifierProvider.overrideWith(
            () => _FakeHistoryNotifier(
              AsyncData(
                HistoryState(
                  allRecords: [
                    HistoryRecord(
                      pushKey: 'rec-1',
                      timestamp: recordTime,
                      temperature: 25.0,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container.read(historyNotifierProvider.future);

      final status = container.read(deviceStatusProvider);
      expect(status.status, equals(DeviceOnlineStatus.offline));
      expect(status.isOffline, isTrue);
      expect(status.message, contains('Device offline. Last data at'));
    });

    test(
      'boundary test: exactly 20 min is online, 20 min 1 s is offline',
      () async {
        final now = DateTime(2026, 11, 10, 14, 30);
        final exact20Min = now.subtract(AppConfig.offlineThreshold);
        final past20Min = now.subtract(
          AppConfig.offlineThreshold + const Duration(seconds: 1),
        );

        // Test exact 20 min
        final container1 = ProviderContainer(
          overrides: [
            demoModeProvider.overrideWith(() => _FakeDemoModeNotifier(false)),
            clockProvider.overrideWithValue(() => now),
            historyNotifierProvider.overrideWith(
              () => _FakeHistoryNotifier(
                AsyncData(
                  HistoryState(
                    allRecords: [
                      HistoryRecord(
                        pushKey: 'rec-1',
                        timestamp: exact20Min,
                        temperature: 25.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        await container1.read(historyNotifierProvider.future);
        expect(
          container1.read(deviceStatusProvider).status,
          equals(DeviceOnlineStatus.online),
        );
        container1.dispose();

        // Test 20 min + 1 s
        final container2 = ProviderContainer(
          overrides: [
            demoModeProvider.overrideWith(() => _FakeDemoModeNotifier(false)),
            clockProvider.overrideWithValue(() => now),
            historyNotifierProvider.overrideWith(
              () => _FakeHistoryNotifier(
                AsyncData(
                  HistoryState(
                    allRecords: [
                      HistoryRecord(
                        pushKey: 'rec-1',
                        timestamp: past20Min,
                        temperature: 25.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
        await container2.read(historyNotifierProvider.future);
        expect(
          container2.read(deviceStatusProvider).status,
          equals(DeviceOnlineStatus.offline),
        );
        container2.dispose();
      },
    );

    test('Demo Mode always reports online even if history is empty or old', () {
      final container = ProviderContainer(
        overrides: [
          demoModeProvider.overrideWith(() => _FakeDemoModeNotifier(true)),
          historyNotifierProvider.overrideWith(
            () => _FakeHistoryNotifier(
              const AsyncData(HistoryState(allRecords: [])),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      final status = container.read(deviceStatusProvider);
      expect(status.status, equals(DeviceOnlineStatus.online));
      expect(status.isOnline, isTrue);
    });
  });
}

class _FakeDemoModeNotifier extends DemoModeNotifier {
  _FakeDemoModeNotifier(this._initial);
  final bool _initial;
  @override
  bool build() => _initial;
}

class _FakeHistoryNotifier extends HistoryNotifier {
  _FakeHistoryNotifier(this._initial);

  final AsyncValue<HistoryState> _initial;

  @override
  Future<HistoryState> build() async {
    if (_initial.hasError) {
      throw _initial.error!;
    }
    return _initial.value!;
  }
}
