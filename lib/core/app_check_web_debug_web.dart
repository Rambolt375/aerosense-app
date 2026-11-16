import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// Enables the App Check debug provider for a local web run.
///
/// This is the `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true` line from the
/// official docs, kept out of `web/index.html` on purpose: anything in that
/// file is copied verbatim into `build/web`. Because this function is only
/// reached through `kDebugMode`, dart2js removes it from release builds, and
/// `tool/check_web_release_appcheck.sh` enforces that.
///
/// The resulting debug token is printed in the browser console and must be
/// registered manually in the Firebase console; it is never committed.
void enableWebAppCheckDebugToken() {
  if (!kDebugMode) return;
  final host = web.window.location.hostname;
  if (host != 'localhost' && host != '127.0.0.1') return;
  web.window.setProperty('FIREBASE_APPCHECK_DEBUG_TOKEN'.toJS, true.toJS);
}
