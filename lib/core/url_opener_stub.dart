/// Stub for non-web platforms. The Android download button is web-only, so this
/// never runs on Android; it exists so `dart:js_interop` is not imported there.
void openUrl(String url) {}
