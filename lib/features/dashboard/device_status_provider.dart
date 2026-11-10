import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/history_record.dart';
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

/// Notifier that checks the freshness of the newest `/history` record.
///
/// Rules:
/// - Evaluated every 30 seconds using an injected [clockProvider].
/// - If Demo Mode is active: always reports [DeviceOnlineStatus.online].
/// - If history is empty or fetch failed: reports [DeviceOnlineStatus.unknown] (no offline claim).
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
    final records = historyAsync.value?.allRecords;

    if (historyAsync.hasError || records == null || records.isEmpty) {
      return const DeviceStatus(status: DeviceOnlineStatus.unknown);
    }

    // Find the latest valid timestamp
    HistoryRecord? newest;
    for (final r in records) {
      if (r.timestamp != null) {
        if (newest == null || r.timestamp!.isAfter(newest.timestamp!)) {
          newest = r;
        }
      }
    }

    if (newest == null || newest.timestamp == null) {
      return const DeviceStatus(status: DeviceOnlineStatus.unknown);
    }

    final clock = ref.read(clockProvider);
    final now = clock();
    final elapsed = now.difference(newest.timestamp!);
    final isOffline = elapsed > AppConfig.offlineThreshold;
    final formatted = DateFormat('HH:mm').format(newest.timestamp!.toLocal());

    return DeviceStatus(
      status: isOffline
          ? DeviceOnlineStatus.offline
          : DeviceOnlineStatus.online,
      lastSeen: newest.timestamp,
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
