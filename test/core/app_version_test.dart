import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/config.dart';

void main() {
  test('AppConfig.appVersion matches pubspec.yaml version', () {
    final pubspecFile = File('pubspec.yaml');
    expect(pubspecFile.existsSync(), isTrue);
    final content = pubspecFile.readAsStringSync();
    final match = RegExp(
      r'^version:\s*([^\s]+)',
      multiLine: true,
    ).firstMatch(content);
    expect(match, isNotNull);
    final pubspecVersion = match!.group(1)!.trim();
    expect(AppConfig.appVersion, equals(pubspecVersion));
  });
}
