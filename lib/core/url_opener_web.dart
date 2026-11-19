import 'package:web/web.dart' as web;

/// Web implementation: a new tab with `noopener,noreferrer` so the destination
/// cannot navigate or read back this page through `window.opener`.
void openUrl(String url) {
  web.window.open(url, '_blank', 'noopener,noreferrer');
}
