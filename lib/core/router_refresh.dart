import 'package:flutter/foundation.dart';

/// A [ChangeNotifier] driven by explicit calls instead of a stream.
///
/// The router reads the auth state inside its `redirect` and is refreshed
/// through this notifier, so an auth event re-runs the redirect without
/// rebuilding the router. Rebuilding would create a new router at the initial
/// location and lose both the current page and a pending deep link.
class RouterRefreshNotifier extends ChangeNotifier {
  /// Re-runs the router's `redirect` callback.
  void refresh() => notifyListeners();
}
