import 'dart:async';

import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] that calls [notifyListeners] on each stream event.
///
/// Used to wire a [Stream] to [GoRouter.refreshListenable] so the router
/// re-evaluates its redirect callback whenever the auth state changes.
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    _subscription = stream.listen((_) => notifyListeners());
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
