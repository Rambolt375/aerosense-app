import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Guard for the App Check debug token.
///
/// Local web runs need `self.FIREBASE_APPCHECK_DEBUG_TOKEN = true`, which is a
/// browser global that disables App Check attestation. It must exist in debug
/// runs only: if it ever reaches the release web bundle, anyone could bypass
/// App Check for Firebase AI Logic.
///
/// The flag therefore lives in a `kDebugMode`-gated Dart shim instead of
/// `web/index.html`, and this test fails if it shows up anywhere it should not.
/// `tool/check_web_release_appcheck.sh` runs the same checks on a built
/// `build/web` directory.
const _token = 'FIREBASE_APPCHECK_DEBUG_TOKEN';

/// The only source file allowed to mention the browser global.
const _allowedSourceFile = 'lib/core/app_check_web_debug_web.dart';

/// `firebase_app_check_web` ships its own debug-provider branch, so its
/// property name is always present in the compiled bundle. Those two statements
/// are gated behind a `WebDebugProvider` type check in the plugin and never run
/// for the `ReCaptchaEnterpriseProvider` this app activates. Any *extra*
/// occurrence means app code started setting the global, which is the thing
/// this guard must catch.
const _vendorDebugBranchOccurrences = 2;

int _countOccurrences(File file, String needle) {
  // Read bytes: the bundle directory also holds .wasm/.png assets that are not
  // valid UTF-8.
  final bytes = file.readAsBytesSync();
  final pattern = needle.codeUnits;
  var count = 0;
  for (var i = 0; i + pattern.length <= bytes.length; i++) {
    var matches = true;
    for (var j = 0; j < pattern.length; j++) {
      if (bytes[i + j] != pattern[j]) {
        matches = false;
        break;
      }
    }
    if (matches) count++;
  }
  return count;
}

void main() {
  test('only the debug-only web shim mentions the debug token global', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      if (_countOccurrences(entity, _token) == 0) continue;
      final relative = entity.path.replaceAll(r'\', '/');
      if (!relative.endsWith(_allowedSourceFile)) offenders.add(relative);
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'The App Check debug token may only be set from '
          '$_allowedSourceFile, which is kDebugMode-only.',
    );
  });

  test('web/index.html never ships the debug token flag', () {
    final index = File('web/index.html');
    expect(index.existsSync(), isTrue);

    expect(
      _countOccurrences(index, _token),
      0,
      reason:
          'Do not add self.FIREBASE_APPCHECK_DEBUG_TOKEN to web/index.html: '
          'that file is copied verbatim into every release build.',
    );
  });

  test('the release web bundle does not enable the debug provider', () {
    final buildDir = Directory('build/web');
    if (!buildDir.existsSync()) {
      // Never built locally. The shell script enforces the same rule after a
      // build, and CI should run that after `flutter build web --release`.
      return;
    }

    final offenders = <String>[];
    for (final entity in buildDir.listSync(recursive: true)) {
      if (entity is! File) continue;
      final count = _countOccurrences(entity, _token);
      if (count == 0) continue;

      final relative = entity.path.replaceAll(r'\', '/');
      if (relative.endsWith('main.dart.js') &&
          count == _vendorDebugBranchOccurrences) {
        continue;
      }
      offenders.add('$relative ($count)');
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Found the App Check debug token outside the known '
          'firebase_app_check_web branch. Re-audit the release bundle, then '
          'update _vendorDebugBranchOccurrences if the plugin changed.',
    );
  });
}
