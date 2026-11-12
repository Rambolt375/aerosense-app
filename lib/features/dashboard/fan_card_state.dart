import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/data/models/tier.dart';

/// Exhaustive UI states for the FanCard component.
enum FanCardUiState {
  appOffline,
  deviceOffline,
  danger,
  safe,
  dangerLatched,
  waitingForDevice,
  running,
  pending,
  idle,
}

/// Pure state derivation function for the FanCard.
///
/// Priority:
/// 1. App offline
/// 2. Device offline
/// 3. Danger tier (safety override)
/// 4. Safe tier (fan off, manual disabled)
/// 5. Medium tier:
///    a. Danger latch (fan on, toggle false, latch active)
///    b. Running / Waiting for device (fanOn && manualToggle)
///    c. Pending (write request in flight)
///    d. Idle (ready for user action)
FanCardUiState deriveFanCardUiState({
  required Tier tier,
  required bool fanOn,
  required bool manualToggle,
  required bool appConnected,
  required bool deviceOffline,
  required bool isPending,
  required bool dangerLatchActive,
  required bool isWaitingForDevice,
}) {
  if (!appConnected) return FanCardUiState.appOffline;
  if (deviceOffline) return FanCardUiState.deviceOffline;
  if (tier == Tier.danger) return FanCardUiState.danger;
  if (tier == Tier.safe) return FanCardUiState.safe;

  // Medium (Caution) tier
  if (dangerLatchActive) return FanCardUiState.dangerLatched;
  if (fanOn && manualToggle) {
    if (isWaitingForDevice) return FanCardUiState.waitingForDevice;
    return FanCardUiState.running;
  }
  if (isPending) return FanCardUiState.pending;
  return FanCardUiState.idle;
}

/// Evaluates whether the Danger latch is active in Medium tier.
///
/// Per confirmed firmware behavior:
/// - If Danger occurred, the fan stays on through Caution until the room is Safe.
/// - To avoid flashing latch text when a normal run ends (fan spin-down lag),
///   latch is active ONLY if:
///     1. Danger was observed since the last Safe state, OR
///     2. The unlatched condition (Medium, fanOn, !manualToggle) has held continuously for >= 6 s.
bool evaluateDangerLatch({
  required Tier tier,
  required bool fanOn,
  required bool manualToggle,
  required bool dangerObservedSinceSafe,
  required Duration? unlatchedCautionHeldDuration,
}) {
  if (tier != Tier.medium || !fanOn || manualToggle) {
    return false;
  }
  if (dangerObservedSinceSafe) {
    return true;
  }
  if (unlatchedCautionHeldDuration != null &&
      unlatchedCautionHeldDuration >= const Duration(seconds: 6)) {
    return true;
  }
  return false;
}

/// Evaluates whether the system is waiting for the device to turn off the fan.
///
/// If `manualToggle` is still true 30 s after the end time, returns true.
bool evaluateWaitingForDevice({
  required bool manualToggle,
  required DateTime? endsAt,
  required DateTime now,
}) {
  if (!manualToggle || endsAt == null) return false;
  return now.isAfter(endsAt.add(const Duration(seconds: 30)));
}

/// Clamps [manualEndsAt] against [now] and [knownDuration].
///
/// If remaining < 0 or > 2 x the known/default duration, returns null
/// so the UI can fall back to "Fan running" without a countdown.
DateTime? clampManualEndsAt({
  required DateTime? manualEndsAt,
  required DateTime now,
  Duration? knownDuration,
}) {
  if (manualEndsAt == null) return null;
  final remaining = manualEndsAt.difference(now);
  final maxAllowed = (knownDuration ?? AppConfig.defaultManualDuration) * 2;
  if (remaining < Duration.zero || remaining > maxAllowed) {
    return null;
  }
  return manualEndsAt;
}

/// Formats a duration as `M:SS`.
String formatCountdown(Duration duration) {
  final totalSeconds = duration.inSeconds.clamp(0, 86400);
  final m = totalSeconds ~/ 60;
  final s = (totalSeconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// Returns whether the ventilation button is enabled for user interaction.
bool isFanButtonEnabled(FanCardUiState state) => state == FanCardUiState.idle;

/// Returns the primary button label for the fan card based on the current state.
String fanButtonLabel({
  required FanCardUiState state,
  Duration? manualDuration,
  Duration? remainingTime,
}) {
  switch (state) {
    case FanCardUiState.idle:
      if (manualDuration != null) {
        return 'Ventilate for ${manualDuration.inMinutes} min';
      }
      return 'Ventilate';
    case FanCardUiState.pending:
      return 'Starting fan...';
    case FanCardUiState.running:
      if (remainingTime != null) {
        return 'Fan running, ${formatCountdown(remainingTime)} left';
      }
      return 'Fan running';
    case FanCardUiState.waitingForDevice:
      return 'Waiting for the device...';
    case FanCardUiState.safe:
    case FanCardUiState.danger:
    case FanCardUiState.dangerLatched:
    case FanCardUiState.appOffline:
    case FanCardUiState.deviceOffline:
      if (manualDuration != null) {
        return 'Ventilate for ${manualDuration.inMinutes} min';
      }
      return 'Ventilate';
  }
}

/// Returns the helper text displayed below the button.
String fanCardHelperText({
  required FanCardUiState state,
  Duration? manualDuration,
}) {
  switch (state) {
    case FanCardUiState.appOffline:
      return 'App is offline. Fan control unavailable.';
    case FanCardUiState.deviceOffline:
      return 'Device offline. Fan control unavailable.';
    case FanCardUiState.safe:
      return 'The fan stays off while the room is safe. Manual ventilation is available when the room gets stuffy.';
    case FanCardUiState.danger:
      return 'Safety override active. The fan is forced on and manual control is bypassed.';
    case FanCardUiState.dangerLatched:
      return 'Fan stays on until the room is safe.';
    case FanCardUiState.waitingForDevice:
      return 'Waiting for the device to turn off the fan.';
    case FanCardUiState.running:
      return 'Manual ventilation is on. The fan is running.';
    case FanCardUiState.pending:
      return 'Sending request to device...';
    case FanCardUiState.idle:
      if (manualDuration != null) {
        return 'Room is stuffy. The fan stays off unless you turn it on.';
      }
      return 'The fan runs for a fixed time set by the device.';
  }
}
