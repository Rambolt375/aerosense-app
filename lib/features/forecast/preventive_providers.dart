import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';
import 'package:aerosense_app/core/thresholds.dart';
import 'package:aerosense_app/data/models/tier.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/dashboard/device_status_provider.dart';
import 'package:aerosense_app/features/forecast/forecast_providers.dart';
import 'package:aerosense_app/features/forecast/preventive_decision.dart';

// ---------------------------------------------------------------------------
// 1. Local publishing setting
// ---------------------------------------------------------------------------

/// StateNotifier managing whether THIS physical device publishes automated
/// pre-ventilation triggers (default: false).
///
/// Ensures only one designated client (e.g. the booth laptop) ever sends commands.
class PublishPreventiveNotifier extends Notifier<bool> {
  static const String prefKey = 'publish_preventive_triggers';

  @override
  bool build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      return prefs.getBool(prefKey) ?? false;
    }
    return false;
  }

  /// Updates publishing setting and persists to SharedPreferences.
  Future<void> setPublishing(bool value) async {
    state = value;
    final prefs =
        ref.read(sharedPreferencesProvider) ??
        await SharedPreferences.getInstance();
    await prefs.setBool(prefKey, value);
  }
}

/// Provider for the local device publishing toggle.
final publishPreventiveTriggersProvider =
    NotifierProvider<PublishPreventiveNotifier, bool>(
      PublishPreventiveNotifier.new,
    );

// ---------------------------------------------------------------------------
// 2. Timestamps persistence on publishing device
// ---------------------------------------------------------------------------

/// Immutable state containing recorded trigger and peak timestamps.
class PreventiveTimestamps {
  const PreventiveTimestamps({
    this.lastTriggerTime,
    this.lastTriggeredPeakTime,
  });

  final DateTime? lastTriggerTime;
  final DateTime? lastTriggeredPeakTime;
}

/// Manages and persists `lastTriggerTime` and `lastTriggeredPeakTime` to
/// SharedPreferences on the publishing device only, preventing duplicate
/// triggers upon page reloads.
class PreventiveTimestampsNotifier extends Notifier<PreventiveTimestamps> {
  static const String prefKeyLastTrigger = 'preventive_last_trigger_time';
  static const String prefKeyLastPeak = 'preventive_last_triggered_peak_time';

  @override
  PreventiveTimestamps build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    if (prefs != null) {
      final triggerStr = prefs.getString(prefKeyLastTrigger);
      final peakStr = prefs.getString(prefKeyLastPeak);
      return PreventiveTimestamps(
        lastTriggerTime: triggerStr != null
            ? DateTime.tryParse(triggerStr)
            : null,
        lastTriggeredPeakTime: peakStr != null
            ? DateTime.tryParse(peakStr)
            : null,
      );
    }
    return const PreventiveTimestamps();
  }

  /// Records a successful pre-ventilation trigger and persists timestamps.
  Future<void> recordTrigger(DateTime triggerTime, DateTime? peakTime) async {
    state = PreventiveTimestamps(
      lastTriggerTime: triggerTime,
      lastTriggeredPeakTime: peakTime,
    );
    final prefs =
        ref.read(sharedPreferencesProvider) ??
        await SharedPreferences.getInstance();
    await prefs.setString(prefKeyLastTrigger, triggerTime.toIso8601String());
    if (peakTime != null) {
      await prefs.setString(prefKeyLastPeak, peakTime.toIso8601String());
    } else {
      await prefs.remove(prefKeyLastPeak);
    }
  }
}

/// Provider for persisted pre-ventilation timestamps.
final preventiveTimestampsProvider =
    NotifierProvider<PreventiveTimestampsNotifier, PreventiveTimestamps>(
      PreventiveTimestampsNotifier.new,
    );

// ---------------------------------------------------------------------------
// 3. Injected clock provider for testing
// ---------------------------------------------------------------------------

/// Injected clock for pre-ventilation evaluations. Defaults to [DateTime.now].
final preventiveClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

// ---------------------------------------------------------------------------
// 4. Decision Notifier (evaluated on 30 s timer + state changes)
// ---------------------------------------------------------------------------

/// Evaluates pre-ventilation decision rules on a 30-second timer and on
/// relevant state transitions.
///
/// Timers are active only when this device is designated as the publisher
/// (`publishPreventiveTriggersProvider == true`), and cancelled on dispose
/// or when the publisher is off.
class PreventiveDecisionNotifier extends Notifier<PreventiveDecision> {
  Timer? _evaluationTimer;

  @override
  PreventiveDecision build() {
    ref.onDispose(() {
      _evaluationTimer?.cancel();
      _evaluationTimer = null;
    });

    final isPublisher = ref.watch(publishPreventiveTriggersProvider);
    _evaluationTimer?.cancel();
    _evaluationTimer = null;

    if (isPublisher) {
      _evaluationTimer = Timer.periodic(const Duration(seconds: 30), (_) {
        state = _computeDecision();
      });
    }

    return _computeDecision();
  }

  PreventiveDecision _computeDecision() {
    final prefs = ref.watch(forecastPreferencesProvider).asData?.value;
    final deviceStatus = ref.watch(deviceStatusProvider);
    final systemState = ref.watch(systemStateProvider).asData?.value;
    final gate = ref.watch(forecastGateNotifierProvider);
    final fitState = ref.watch(diurnalFitProvider);
    final timestamps = ref.watch(preventiveTimestampsProvider);
    final clock = ref.watch(preventiveClockProvider);

    final aqModel = fitState.airQualityResult.model;
    final aqGateStatus = gate.aqGate.status;
    final hasPattern = aqModel?.hasClearDailyPattern ?? false;

    return evaluatePreventiveDecision(
      allowPreventive: prefs?.allowPreventive ?? false,
      aqGateStatus: aqGateStatus,
      hasClearDailyPattern: hasPattern,
      aqModel: aqModel,
      cautionThreshold: Thresholds.airQualityCautionMin,
      isDeviceOnline: !deviceStatus.isOffline,
      currentTier: systemState?.tier ?? Tier.safe,
      isPreventiveTriggerActive: prefs?.preventiveTrigger ?? false,
      isManualToggleActive: systemState?.manualToggle ?? false,
      isFanRunning: systemState?.fanOn ?? false,
      lastTriggerTime: timestamps.lastTriggerTime,
      lastTriggeredPeakTime: timestamps.lastTriggeredPeakTime,
      clock: clock,
    );
  }
}

/// Provider exposing the current [PreventiveDecision].
final preventiveDecisionProvider =
    NotifierProvider<PreventiveDecisionNotifier, PreventiveDecision>(
      PreventiveDecisionNotifier.new,
    );

// ---------------------------------------------------------------------------
// 5. Automated Trigger Coordinator (Publishing device only)
// ---------------------------------------------------------------------------

/// Coordinates automated publishing on the designated publisher device.
class PreventivePublisherNotifier extends Notifier<void> {
  @override
  void build() {
    final isPublisher = ref.watch(publishPreventiveTriggersProvider);
    final isTeam = ref.watch(isTeamAccountProvider);
    final decision = ref.watch(preventiveDecisionProvider);

    if (isPublisher && isTeam && decision.canTrigger) {
      _executeTrigger(decision);
    }
  }

  Future<void> _executeTrigger(PreventiveDecision decision) async {
    final clock = ref.read(preventiveClockProvider);
    final now = clock();

    try {
      await ref.read(systemRepositoryProvider).requestPreventiveTrigger();
      await ref
          .read(preventiveTimestampsProvider.notifier)
          .recordTrigger(now, decision.nextPeakTime);
    } catch (e) {
      debugPrint('[PreventivePublisher] Trigger request failed: $e');
    }
  }
}

/// Active publisher watcher provider.
final preventivePublisherProvider =
    NotifierProvider<PreventivePublisherNotifier, void>(
      PreventivePublisherNotifier.new,
    );

// ---------------------------------------------------------------------------
// 6. Manual Demo Run State & Controller
// ---------------------------------------------------------------------------

/// State of the "Run pre-ventilation now (demo)" action.
class RunPreVentilationState {
  const RunPreVentilationState({
    this.isPending = false,
    this.feedbackMessage,
    this.errorMessage,
  });

  final bool isPending;
  final String? feedbackMessage;
  final String? errorMessage;

  RunPreVentilationState copyWith({
    bool? isPending,
    String? Function()? feedbackMessage,
    String? Function()? errorMessage,
  }) {
    return RunPreVentilationState(
      isPending: isPending ?? this.isPending,
      feedbackMessage: feedbackMessage != null
          ? feedbackMessage()
          : this.feedbackMessage,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

/// Notifier for the team "Run pre-ventilation now (demo)" button.
///
/// Features:
/// - Bypasses cooldown, does not touch automated bookkeeping.
/// - 5 s decline detection: if trigger returns to false within 5 s and fan is off,
///   surfaces: "The device declined (permission off or busy)".
/// - Network/permission error handling: surfaces "Could not send the request" (no retry).
class RunPreVentilationNotifier extends Notifier<RunPreVentilationState> {
  Timer? _declineCheckTimer;
  StreamSubscription? _systemSub;
  StreamSubscription? _forecastSub;
  bool _fanBecameOn = false;
  bool _sawTriggerTrue = false;

  @override
  RunPreVentilationState build() {
    ref.onDispose(() {
      _declineCheckTimer?.cancel();
      _systemSub?.cancel();
      _forecastSub?.cancel();
    });
    return const RunPreVentilationState();
  }

  /// Clears any transient feedback or error messages.
  void clearMessages() {
    state = state.copyWith(
      feedbackMessage: () => null,
      errorMessage: () => null,
    );
  }

  /// Triggers an immediate pre-ventilation cycle for demonstration.
  Future<void> runNow() async {
    if (state.isPending) return;

    state = const RunPreVentilationState(isPending: true);
    _fanBecameOn = false;
    _sawTriggerTrue = false;
    _declineCheckTimer?.cancel();
    _systemSub?.cancel();
    _forecastSub?.cancel();

    // Start 5 s decline watcher
    _declineCheckTimer = Timer(const Duration(seconds: 5), () {
      _systemSub?.cancel();
      _forecastSub?.cancel();
      if (state.isPending) {
        if (!_fanBecameOn) {
          state = state.copyWith(
            isPending: false,
            feedbackMessage: () =>
                'The device declined (permission off or busy)',
          );
        } else {
          state = state.copyWith(isPending: false);
        }
      }
    });

    // Listen to live system state
    _systemSub = ref.read(systemRepositoryProvider).watchSystemState().listen((
      s,
    ) {
      if (s.fanOn) {
        _fanBecameOn = true;
        if (state.isPending) {
          _declineCheckTimer?.cancel();
          _systemSub?.cancel();
          _forecastSub?.cancel();
          state = state.copyWith(isPending: false);
        }
      }
    });

    // Listen to live forecast node
    _forecastSub = ref
        .read(systemRepositoryProvider)
        .watchForecastPreferences()
        .listen((f) {
          if (f.preventiveTrigger) {
            _sawTriggerTrue = true;
          } else if (_sawTriggerTrue && !f.preventiveTrigger && !_fanBecameOn) {
            // Trigger reverted to false in <= 5s and fan is off -> declined by firmware
            if (state.isPending) {
              _declineCheckTimer?.cancel();
              _systemSub?.cancel();
              _forecastSub?.cancel();
              state = state.copyWith(
                isPending: false,
                feedbackMessage: () =>
                    'The device declined (permission off or busy)',
              );
            }
          }
        });

    try {
      await ref.read(systemRepositoryProvider).requestPreventiveTrigger();
    } catch (e) {
      _declineCheckTimer?.cancel();
      _systemSub?.cancel();
      _forecastSub?.cancel();
      state = state.copyWith(
        isPending: false,
        errorMessage: () => 'Could not send the request',
      );
    }
  }
}

/// Provider for the "Run pre-ventilation now (demo)" controller.
final runPreVentilationNotifierProvider =
    NotifierProvider<RunPreVentilationNotifier, RunPreVentilationState>(
      RunPreVentilationNotifier.new,
    );
