import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:aerosense_app/core/app_check_web_debug_stub.dart'
    if (dart.library.js_interop) 'package:aerosense_app/core/app_check_web_debug_web.dart';
import 'package:aerosense_app/core/config.dart';

/// Result of trying to activate Firebase App Check.
enum AppCheckStatus {
  /// App Check was never activated (missing configuration or unsupported
  /// platform). Treated exactly like a failure for gating purposes.
  notConfigured,

  /// The provider activated; requests now carry an App Check token.
  active,

  /// Activation threw. The assistant stays hidden.
  failed,
}

/// Activates App Check with the attestation provider for this platform.
///
/// Called once at startup and never awaited before `runApp`: App Check must
/// never block app start. Every failure is a debug-only log, because a release
/// build without App Check simply keeps the live assistant hidden.
///
/// Web needs a project-configured reCAPTCHA Enterprise site key. Without it we
/// skip activation instead of sending unprotected requests to AI Logic (App
/// Check enforcement for AI Logic is required since 2 November 2026).
Future<AppCheckStatus> activateAppCheck() async {
  try {
    if (kIsWeb) {
      final siteKey = AppConfig.appCheckRecaptchaSiteKey;
      if (siteKey.isEmpty) {
        if (kDebugMode) {
          debugPrint(
            'App Check: no APPCHECK_RECAPTCHA_SITE_KEY define; '
            'live assistant stays disabled.',
          );
        }
        return AppCheckStatus.notConfigured;
      }
      enableWebAppCheckDebugToken();
      await FirebaseAppCheck.instance.activate(
        providerWeb: ReCaptchaEnterpriseProvider(siteKey),
      );
      return AppCheckStatus.active;
    }

    if (defaultTargetPlatform == TargetPlatform.android) {
      await FirebaseAppCheck.instance.activate(
        // Debug provider only ever ships in debug builds: release APKs must
        // attest with Play Integrity or not reach the model at all.
        providerAndroid: kDebugMode
            ? const AndroidDebugProvider()
            : const AndroidPlayIntegrityProvider(),
      );
      return AppCheckStatus.active;
    }

    return AppCheckStatus.notConfigured;
  } catch (error) {
    if (kDebugMode) debugPrint('App Check: activation failed ($error).');
    return AppCheckStatus.failed;
  }
}
