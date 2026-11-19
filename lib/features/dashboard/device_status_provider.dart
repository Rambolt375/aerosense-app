import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/history/history_notifier.dart';

/// Injected clock provider to allow deterministic time testing.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Device connectivity / freshness status.
enum DeviceOnlineStatus {
  /// Telemetry received within 2 missed cycles (<= 20 min).
  online,

  /// More than 2 cycles missed (> 20 min).
  offline,

  /// History empty or fetch failed; cannot determine device staleness.
  unknown,
}

/// Device freshness state derived from the latest /history timestamp.
class DeviceStatus {
  const DeviceStatus({required this.status, this.lastSeen, this.formattedTime});

  final DeviceOnlineStatus status;
  final DateTime? lastSeen;
  final String? formattedTime;

  bool get isOffline => status == DeviceOnlineStatus.offline;
  bool get isOnline => status == DeviceOnlineStatus.online;
  bool get isUnknown => status == DeviceOnlineStatus.unknown;

  /// Standard display message for the offline state.
  String get message {
    if (isOffline) {
      return formattedTime != null
          ? 'Device offline. Last data at $formattedTime'
          : 'Device offline.';
    }
    return '';
  }
}

/// Whether the ESP32 wrote a new value for any of the three live sensor
/// readings between two `/system` snapshots.
///
/// One changed reading is enough. The firmware drops `temperature` and
/// `humidity` to 0 when the DHT22 is unplugged, yet the board keeps running and
/// the MQ-135 index keeps drifting, so requiring all three to move would report
/// a working device as offline.
bool sensorReadingsChanged(SystemState previous, SystemState current) {
  return previous.temperature != current.temperature ||
      previous.humidity != current.humidity ||
      previous.airQuality != current.airQuality;
}

/// Records the last time any live `/system` sensor reading changed.
///
/// RTDB does not re-emit `onValue` when the ESP32 rewrites an identical payload,
/// so an event with different readings proves the device is alive right now.
/// The first snapshot after (re)connect is the cached value RTDB replays, so it
/// is deliberately not counted as evidence of life.
class LiveTelemetryActivityNotifier extends Notifier<DateTime?> {
  SystemState? _previous;

  @override
  DateTime? build() {
    _previous = null;
    ref.listen<AsyncValue<SystemState>>(systemStateProvider, (previous, next) {
      final snapshot = next.asData?.value;
      if (snapshot == null) return;

      final lastSnapshot = _previous;
      _previous = snapshot;
      if (lastSnapshot == null) return;

      if (sensorReadingsChanged(lastSnapshot, snapshot)) {
        // Anything tied to the firmware contract: the change time is when the
        // board pushed fresh telemetry, not when this app happened to render.
        state = ref.read(clockProvider)();
      }
    }, fireImmediately: true);
    return null;
  }
}

/// Last live telemetry change time, or null while no change has been observed.
final liveTelemetryActivityProvider =
    NotifierProvider<LiveTelemetryActivityNotifier, DateTime?>(
      LiveTelemetryActivityNotifier.new,
    );

/// Notifier that decides whether the ESP32 is currently online.
///
/// Two independent freshness signals are used; either one is enough:
/// 1. newest `/history` record (firmware archives a sample every cycle), and
/// 2. the last time any live `/system` sensor reading changed.
///
/// Rules:
/// - Evaluated every 30 seconds using an injected [clockProvider].
/// - If Demo Mode is active: always reports [DeviceOnlineStatus.online].
/// - If neither signal is available: reports [DeviceOnlineStatus.unknown] (no offline claim).
/// - Marked [DeviceOnlineStatus.offline] after 2 missed cycles = 20 minutes (2 * 10 min).
class DeviceStatusNotifier extends Notifier<DeviceStatus> {
  Timer? _timer;

  @override
  DeviceStatus build() {
    ref.onDispose(() => _timer?.cancel());

    // Schedule 30-second periodic evaluation
    _timer = Timer.periodic(AppConfig.freshnessEvaluationInterval, (_) {
      state = _calculateStatus();
    });

    return _calculateStatus();
  }

  DeviceStatus _calculateStatus() {
    final isDemo = ref.watch(demoModeProvider);
    if (isDemo) {
      return const DeviceStatus(status: DeviceOnlineStatus.online);
    }

    final historyAsync = ref.watch(historyNotifierProvider);
    final liveChangedAt = ref.watch(liveTelemetryActivityProvider);

    // Newest archived sample. A fetch error contributes nothing, but it must
    // not hide a live telemetry change (an unplugged DHT22 can also mean the
    // firmware stopped archiving, so history alone would look like a dead board).
    DateTime? newest;
    final records = historyAsync.hasError
        ? null
        : historyAsync.value?.allRecords;
    if (records != null) {
      for (final r in records) {
        if (r.timestamp != null) {
          if (newest == null || r.timestamp!.isAfter(newest)) {
            newest = r.timestamp;
          }
        }
      }
    }

    if (liveChangedAt != null &&
        (newest == null || liveChangedAt.isAfter(newest))) {
      newest = liveChangedAt;
    }

    if (newest == null) {
      return const DeviceStatus(status: DeviceOnlineStatus.unknown);
    }

    final clock = ref.read(clockProvider);
    final now = clock();
    final elapsed = now.difference(newest);
    final isOffline = elapsed > AppConfig.offlineThreshold;
    final formatted = DateFormat('HH:mm').format(newest.toLocal());

    return DeviceStatus(
      status: isOffline
          ? DeviceOnlineStatus.offline
          : DeviceOnlineStatus.online,
      lastSeen: newest,
      formattedTime: formatted,
    );
  }

  /// Manually force re-evaluation (useful in tests).
  void refresh() {
    state = _calculateStatus();
  }
}

final deviceStatusProvider =
    NotifierProvider<DeviceStatusNotifier, DeviceStatus>(
      DeviceStatusNotifier.new,
    );
