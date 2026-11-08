import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/data/repositories/providers.dart';

/// State for the manual toggle: current value + pending write indicator.
class ManualToggleState {
  const ManualToggleState({required this.value, required this.isPending});

  final bool value;
  final bool isPending;
}

/// Notifier managing the optimistic manual fan toggle state.
///
/// Handles the write-pending → stream-reconciliation flow:
/// 1. User flips switch → optimistically update local state (`isPending: true`)
/// 2. Write to `/system/manualToggle` via repository
/// 3. While pending, ignore incoming stream values until confirmed or ~5 s timeout
/// 4. After confirmation or timeout, stream is source of truth (`isPending: false`)
/// 5. If stream reverts the value after timeout, local state follows and logs
class ManualToggleNotifier extends Notifier<ManualToggleState> {
  DateTime? _writeStartedAt;
  bool? _pendingValue;
  Timer? _timeoutTimer;

  @override
  ManualToggleState build() {
    ref.onDispose(() => _timeoutTimer?.cancel());

    // Watch the system state stream for the toggle value
    final systemState = ref.watch(systemStateProvider);

    return systemState.when(
      data: (state) {
        final streamValue = state.manualToggle;

        // If a write is pending
        if (_writeStartedAt != null) {
          final elapsed = DateTime.now().difference(_writeStartedAt!);
          if (elapsed.inSeconds < 5) {
            // If the stream now matches our pending value, it settled!
            if (streamValue == _pendingValue) {
              _cancelPending();
              return ManualToggleState(value: streamValue, isPending: false);
            }
            // Stream has not yet caught up: continue ignoring it
            return ManualToggleState(
              value: _pendingValue ?? streamValue,
              isPending: true,
            );
          }

          // 5s elapsed: timeout, reconcile to stream
          _handleTimeout(streamValue);
        }

        return ManualToggleState(value: streamValue, isPending: false);
      },
      loading: () => const ManualToggleState(value: false, isPending: false),
      error: (_, _) => const ManualToggleState(value: false, isPending: false),
    );
  }

  /// Sets the toggle value optimistically and writes to RTDB.
  Future<void> setToggle(bool value) async {
    _pendingValue = value;
    _writeStartedAt = DateTime.now();
    state = ManualToggleState(value: value, isPending: true);

    // Schedule 5 s timeout to reconcile to stream if it never echoes
    _timeoutTimer?.cancel();
    _timeoutTimer = Timer(const Duration(seconds: 5), () {
      if (_writeStartedAt != null) {
        final currentStreamValue =
            ref.read(systemStateProvider).asData?.value.manualToggle ?? false;
        _handleTimeout(currentStreamValue);
        state = ManualToggleState(value: currentStreamValue, isPending: false);
      }
    });

    try {
      await ref.read(systemRepositoryProvider).setManualToggle(value);
    } catch (e) {
      // Revert immediately on write failure
      _cancelPending();
      final currentStreamValue =
          ref.read(systemStateProvider).asData?.value.manualToggle ?? false;
      state = ManualToggleState(value: currentStreamValue, isPending: false);
      rethrow;
    }
  }

  void _handleTimeout(bool streamValue) {
    if (_pendingValue != null && _pendingValue != streamValue) {
      debugPrint(
        'ManualToggleNotifier: stream reverted pending value '
        '($_pendingValue → $streamValue). Using stream value.',
      );
    }
    _cancelPending();
  }

  void _cancelPending() {
    _timeoutTimer?.cancel();
    _timeoutTimer = null;
    _writeStartedAt = null;
    _pendingValue = null;
  }
}

/// Provider for the manual toggle notifier.
final manualToggleProvider =
    NotifierProvider<ManualToggleNotifier, ManualToggleState>(
      ManualToggleNotifier.new,
    );
