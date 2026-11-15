import 'package:web/web.dart' as web;

/// Returns the browser User Agent on Web platforms.
String? getCurrentUserAgent() => web.window.navigator.userAgent;
