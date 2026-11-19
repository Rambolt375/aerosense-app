import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The APK link is a plain `window.open` with `noopener,noreferrer`.
///
/// It cannot be exercised in the Dart VM (there is no browser), so the source is
/// checked directly: the guard is that the only implementation that touches the
/// DOM is the web-only one and it passes both flags.
void main() {
  test('the web opener opens a new tab with noopener and noreferrer', () {
    final source = File('lib/core/url_opener_web.dart').readAsStringSync();

    expect(
      source,
      contains("web.window.open(url, '_blank', 'noopener,noreferrer')"),
    );
  });

  test('the stub is a no-op so Android never imports dart:js_interop', () {
    final stub = File('lib/core/url_opener_stub.dart').readAsStringSync();
    final facade = File('lib/core/url_opener.dart').readAsStringSync();

    expect(stub, isNot(contains("import 'dart:js_interop'")));
    expect(stub, isNot(contains("import 'package:web")));
    expect(facade, contains('url_opener_stub.dart'));
    expect(facade, contains("if (dart.library.js_interop)"));
  });

  test('url_launcher was not added for the APK link', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    expect(pubspec, isNot(contains('url_launcher')));
  });
}
