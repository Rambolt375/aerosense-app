import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/url_opener.dart';

/// Whether the signed-out public landing page is served at `/`.
///
/// True on web, false on Android (which keeps going straight to `/login`).
/// Injectable so the redirect table can be tested for both platforms without a
/// real browser or device.
final webLandingEnabledProvider = Provider<bool>((ref) => kIsWeb);

/// Where the "Get the app" section sends people for the Android build.
///
/// The GitHub Releases page, so the button is a plain redirect and the visitor
/// picks the APK there. Injectable so tests never open a real tab.
final apkDownloadUrlProvider = Provider<String>(
  (ref) => AppConfig.apkReleasesUrl,
);

/// How the landing page opens the APK URL.
///
/// Overridden in tests so no test opens a real tab.
final urlOpenerProvider = Provider<UrlOpener>((ref) => openExternalUrl);

/// Signature for opening a URL, so tests can record calls.
typedef UrlOpener = void Function(String url);
