import 'package:aerosense_app/core/browser_utils_stub.dart'
    if (dart.library.js_interop) 'package:aerosense_app/core/browser_utils_web.dart';

/// Detects if the provided [userAgent] string belongs to a known in-app browser
/// (such as Instagram, Facebook, Line, WhatsApp, TikTok, or generic Android WebView).
///
/// Google OAuth blocks authorization in embedded WebViews, throwing a
/// disallowed_useragent error.
bool isInAppBrowser(String? userAgent) {
  if (userAgent == null || userAgent.trim().isEmpty) return false;
  final ua = userAgent.toLowerCase();

  // Facebook In-App Browser
  if (ua.contains('fban') || ua.contains('fbav') || ua.contains('fb_iab')) {
    return true;
  }

  // Instagram
  if (ua.contains('instagram')) {
    return true;
  }

  // Line
  if (ua.contains('line/')) {
    return true;
  }

  // WhatsApp
  if (ua.contains('whatsapp')) {
    return true;
  }

  // TikTok
  if (ua.contains('tiktok') ||
      ua.contains('musical_ly') ||
      ua.contains('bytelocale')) {
    return true;
  }

  // Generic Android WebView:
  // Android WebViews include '; wv' in the device info string, or 'version/X.X ... chrome/X.X'.
  if (RegExp(r';\s*wv[\);]').hasMatch(ua) ||
      RegExp(r'\bwv\b').hasMatch(ua) ||
      RegExp(r'version\/[\d.]+\s+chrome\/[\d.]+').hasMatch(ua)) {
    return true;
  }

  return false;
}

/// Convenience function returning whether the current browser environment
/// is an in-app browser.
bool isCurrentBrowserInApp() => isInAppBrowser(getCurrentUserAgent());
