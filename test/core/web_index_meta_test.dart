import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guards the static web shell: the link preview and the browser chrome.
void main() {
  late String html;

  setUpAll(() {
    html = File('web/index.html').readAsStringSync();
  });

  test('declares a meta description that describes the product', () {
    expect(html, contains('<meta name="description"'));
    expect(html.toLowerCase(), isNot(contains('companion app"')));
  });

  test('sets the theme color to the deep navy surface', () {
    expect(html, contains('<meta name="theme-color" content="#06293D">'));
  });

  test('carries Open Graph tags with the hosted icon', () {
    expect(html, contains('property="og:title"'));
    expect(html, contains('property="og:description"'));
    expect(
      html,
      contains(
        '<meta property="og:image" '
        'content="https://aerosense-502de.web.app/icons/Icon-512.png">',
      ),
    );
  });
}
