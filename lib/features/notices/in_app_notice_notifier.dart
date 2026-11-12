import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';

/// Type of in-app notice event.
enum NoticeType { caution, danger, deviceOffline, deviceOnline }

/// Representation of an active in-app notice.
class InAppNotice {
  const InAppNotice({
    required this.type,
    required this.message,
    required this.timestamp,
    this.tier,
  });

  final NoticeType type;
  final String message;
  final DateTime timestamp;
  final Tier? tier;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InAppNotice &&
          runtimeType == other.runtimeType &&
          type == other.type &&
          message == other.message &&
          timestamp == other.timestamp &&
          tier == other.tier;

  @override
  int get hashCode => Object.hash(type, message, timestamp, tier);
}

/// Pure notifier managing in-app notice generation, cooldowns, and auto-clearing.
///
/// Rules:
/// - No notice for the first value after launch.
/// - Danger cooldown is 2 minutes; others (caution, offline, online) are 10 minutes.
/// - Caution and Danger notices auto-clear when the tier returns to Safe.
/// - Danger is never dismissed by time alone.
/// - Dismissible by the user.
class InAppNoticeNotifier extends Notifier<InAppNotice?> {
  final Map<NoticeType, DateTime> _lastEmittedTimes = {};
  Tier? _previousTier;
  DeviceOnlineStatus? _previousDeviceStatus;
  bool _isFirstTierSample = true;
  bool _isFirstDeviceStatusSample = true;

  @override
  InAppNotice? build() {
    // Listen to live system state changes
    ref.listen<AsyncValue<SystemState>>(systemStateProvider, (prev, next) {
      final state = next.asData?.value;
      if (state != null) {
        handleSystemState(state);
      }
    });

    // Listen to device status changes
    ref.listen<DeviceStatus>(deviceStatusProvider, (prev, next) {
      handleDeviceStatus(next);
    });

    // Prime baseline if data already exists synchronously without firing notice
    final initialSystem = ref.read(systemStateProvider).asData?.value;
    if (initialSystem != null) {
      _previousTier = initialSystem.tier;
      _isFirstTierSample = false;
    }

    final initialDevice = ref.read(deviceStatusProvider);
    _previousDeviceStatus = initialDevice.status;
    _isFirstDeviceStatusSample = false;

    return null;
  }

  /// Processes live telemetry and evaluates tier transitions.
  void handleSystemState(SystemState systemState) {
    final currentTier = systemState.tier;

    if (_isFirstTierSample) {
      _isFirstTierSample = false;
      _previousTier = currentTier;
      return;
    }

    final clock = ref.read(clockProvider);
    final now = clock();

    // Auto-clear Caution/Danger notices when returning to Safe
    if (currentTier == Tier.safe) {
      if (state != null &&
          (state!.type == NoticeType.caution ||
              state!.type == NoticeType.danger)) {
        state = null;
      }
    }

    // Trigger Caution notice when transitioning into Medium/Caution from non-Medium
    if (currentTier == Tier.medium && _previousTier != Tier.medium) {
      const cooldown = Duration(minutes: 10);
      final lastTime = _lastEmittedTimes[NoticeType.caution];
      if (lastTime == null || now.difference(lastTime) >= cooldown) {
        _lastEmittedTimes[NoticeType.caution] = now;
        state = InAppNotice(
          type: NoticeType.caution,
          message: 'Room is getting stuffy. Manual ventilation is available.',
          timestamp: now,
          tier: Tier.medium,
        );
      }
    }

    // Trigger Danger notice when transitioning into Danger from non-Danger (2 min cooldown)
    if (currentTier == Tier.danger && _previousTier != Tier.danger) {
      const cooldown = Duration(minutes: 2);
      final lastTime = _lastEmittedTimes[NoticeType.danger];
      if (lastTime == null || now.difference(lastTime) >= cooldown) {
        _lastEmittedTimes[NoticeType.danger] = now;
        state = InAppNotice(
          type: NoticeType.danger,
          message: 'Hazardous air detected. Fan automatically forced on.',
          timestamp: now,
          tier: Tier.danger,
        );
      }
    }

    _previousTier = currentTier;
  }

  /// Processes device connection/staleness changes.
  void handleDeviceStatus(DeviceStatus deviceStatus) {
    final status = deviceStatus.status;

    if (_isFirstDeviceStatusSample) {
      _isFirstDeviceStatusSample = false;
      _previousDeviceStatus = status;
      return;
    }

    final clock = ref.read(clockProvider);
    final now = clock();

    // Transition to offline
    if (status == DeviceOnlineStatus.offline &&
        _previousDeviceStatus != DeviceOnlineStatus.offline) {
      const cooldown = Duration(minutes: 10);
      final lastTime = _lastEmittedTimes[NoticeType.deviceOffline];
      if (lastTime == null || now.difference(lastTime) >= cooldown) {
        _lastEmittedTimes[NoticeType.deviceOffline] = now;
        state = InAppNotice(
          type: NoticeType.deviceOffline,
          message: 'Device offline. Fan control unavailable.',
          timestamp: now,
        );
      }
    }
    // Transition back to online
    else if (status == DeviceOnlineStatus.online &&
        _previousDeviceStatus == DeviceOnlineStatus.offline) {
      const cooldown = Duration(minutes: 10);
      final lastTime = _lastEmittedTimes[NoticeType.deviceOnline];
      if (lastTime == null || now.difference(lastTime) >= cooldown) {
        _lastEmittedTimes[NoticeType.deviceOnline] = now;
        state = InAppNotice(
          type: NoticeType.deviceOnline,
          message: 'Device reconnected.',
          timestamp: now,
        );
      }
    }

    _previousDeviceStatus = status;
  }

  /// Dismisses the active notice.
  void dismiss() {
    state = null;
  }
}

/// In-app notice provider.
final inAppNoticeProvider = NotifierProvider<InAppNoticeNotifier, InAppNotice?>(
  InAppNoticeNotifier.new,
);
