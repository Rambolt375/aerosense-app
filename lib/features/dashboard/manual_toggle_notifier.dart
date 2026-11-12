import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/strings.dart';
import 'package:aerosense_app/data/models/system_state.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/providers.dart';

/// State of the manual ventilation controller.
class ManualVentilationState {
  const ManualVentilationState({
    this.isPending = false,
    this.errorMessage,
    this.dangerObservedSinceSafe = false,
    this.unlatchedCautionHeldDuration,
    this.observedRunStartedAt,
  });

  /// True when the user pressed the button and the app is awaiting stream confirmation.
  final bool isPending;

  /// User-facing message when write fails, times out, or returns to false immediately.
  final String? errorMessage;

  /// Whether a Danger tier event was observed since the last Safe state.
  final bool dangerObservedSinceSafe;

  /// Continuous duration (tier == medium && fanOn && !manualToggle) has been held.
  final Duration? unlatchedCautionHeldDuration;

  /// Timestamp when the app observed manualToggle become true.
  final DateTime? observedRunStartedAt;

  ManualVentilationState copyWith({
    bool? isPending,
    String? Function()? errorMessage,
    bool? dangerObservedSinceSafe,
    Duration? Function()? unlatchedCautionHeldDuration,
    DateTime? Function()? observedRunStartedAt,
  }) {
    return ManualVentilationState(
      isPending: isPending ?? this.isPending,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
      dangerObservedSinceSafe:
          dangerObservedSinceSafe ?? this.dangerObservedSinceSafe,
      unlatchedCautionHeldDuration: unlatchedCautionHeldDuration != null
          ? unlatchedCautionHeldDuration()
          : this.unlatchedCautionHeldDuration,
      observedRunStartedAt: observedRunStartedAt != null
          ? observedRunStartedAt()
          : this.observedRunStartedAt,
    );
  }
}

/// Notifier managing the manual ventilation actuation lifecycle.
///
/// Features (Phase 6a):
/// - Debounces double taps.
/// - Requests ventilation via `systemRepository.requestManualVentilation()`.
/// - 5 s confirmation timeout; if device does not confirm or reverts immediately,
///   sets error message: "The device didn't start the fan. The room may no longer be in the stuffy range."
/// - Tracks Danger-observed flag and unlatched Caution duration for latch detection.
/// - Records client-observed run start timestamp when duration is known.
class ManualVentilationNotifier extends Notifier<ManualVentilationState> {
  ManualVentilationNotifier({DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final DateTime Function() _clock;
  Timer? _timeoutTimer;

  bool _isPending = false;
  String? _errorMessage;
  bool _dangerObserved = false;
  DateTime? _unlatchedHeldSince;
  DateTime? _observedRunStartedAt;
  DateTime? _runConfirmedAt;
  bool _lastManualToggle = false;
  bool _hasReceivedInitialEvent = false;

  @override
  ManualVentilationState build() {
    ref.onDispose(() {
      _timeoutTimer?.cancel();
    });

    final systemStateAsync = ref.watch(systemStateProvider);
    return systemStateAsync.when(
      data: (systemState) {
        _processSystemState(systemState);
        return _buildState();
      },
      loading: () => _buildState(),
      error: (_, _) => _buildState(),
    );
  }

  void _processSystemState(SystemState state) {
    final isInitial = !_hasReceivedInitialEvent;
    _hasReceivedInitialEvent = true;

    // 1. Tier tracking for Danger latch
    if (state.tier == Tier.safe) {
      _dangerObserved = false;
      _unlatchedHeldSince = null;
    } else if (state.tier == Tier.danger) {
      _dangerObserved = true;
      _unlatchedHeldSince = null;
    } else if (state.tier == Tier.medium) {
      if (state.fanOn && !state.manualToggle) {
        _unlatchedHeldSince ??= _clock();
      } else {
        _unlatchedHeldSince = null;
      }
    }

    // 2. Manual toggle state transitions
    if (state.manualToggle) {
      if (_isPending) {
        // Stream confirmed our request!
        _timeoutTimer?.cancel();
        _timeoutTimer = null;
        _isPending = false;
        _runConfirmedAt = _clock();
        _observedRunStartedAt ??= _clock();
      } else if (!isInitial && !_lastManualToggle) {
        // App observed stream transition from false to true while open
        _runConfirmedAt = _clock();
        _observedRunStartedAt = _clock();
      }
      _lastManualToggle = true;
    } else {
      if (_lastManualToggle) {
        // Was running, now stopped. Check for immediate rejection (< 5 s):
        if (_runConfirmedAt != null &&
            _clock().difference(_runConfirmedAt!) <
                const Duration(seconds: 5)) {
          _errorMessage = AppStrings.fanErrorStartFailed;
        }
        _runConfirmedAt = null;
        _observedRunStartedAt = null;
        _lastManualToggle = false;
      }
    }
  }

  ManualVentilationState _buildState() {
    final heldDuration = _unlatchedHeldSince != null
        ? _clock().difference(_unlatchedHeldSince!)
        : null;

    return ManualVentilationState(
      isPending: _isPending,
      errorMessage: _errorMessage,
      dangerObservedSinceSafe: _dangerObserved,
      unlatchedCautionHeldDuration: heldDuration,
      observedRunStartedAt: _observedRunStartedAt,
    );
  }

  /// Initiates a manual ventilation run.
  Future<void> startVentilation() async {
    final currentToggle =
        ref.read(systemStateProvider).asData?.value.manualToggle ?? false;

    // Debounce double taps and ignore if already running or pending
    if (_isPending || currentToggle) return;

    _isPending = true;
    _errorMessage = null;
    state = _buildState();

    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(AppConfig.manualToggleConfirmTimeout, () {
      if (_isPending) {
        _isPending = false;
        _errorMessage = AppStrings.fanErrorStartFailed;
        state = _buildState();
      }
    });

    try {
      await ref.read(systemRepositoryProvider).requestManualVentilation();
    } catch (e) {
      _timeoutTimer?.cancel();
      _isPending = false;
      _errorMessage = AppStrings.fanErrorConnection;
      state = _buildState();
      rethrow;
    }
  }

  /// Clears any one-off error message once shown.
  void clearErrorMessage() {
    if (_errorMessage != null) {
      _errorMessage = null;
      state = _buildState();
    }
  }
}

/// Provider for the manual ventilation controller.
final manualVentilationProvider =
    NotifierProvider<ManualVentilationNotifier, ManualVentilationState>(
      ManualVentilationNotifier.new,
    );

/// Deprecated alias kept for backwards compatibility.
final manualToggleProvider = manualVentilationProvider;
