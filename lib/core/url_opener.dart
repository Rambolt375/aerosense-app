import 'package:aerosense_app/core/url_opener_stub.dart'
    if (dart.library.js_interop) 'package:aerosense_app/core/url_opener_web.dart';

/// Opens [url] in a new browser tab, without handing the opener any reference
/// back to this page.
///
/// Used by the landing page's "Get the Android app" button, which redirects to
/// the GitHub Releases page rather than serving a file. On non-web platforms
/// this is a no-op: that button only exists on the web landing page.
void openExternalUrl(String url) => openUrl(url);
