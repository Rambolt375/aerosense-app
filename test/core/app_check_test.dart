import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/app_check.dart';
import 'package:aerosense_app/core/config.dart';

void main() {
  test('the web site key comes from --dart-define, never from source', () {
    // Defaults to empty so a build without the define keeps the assistant
    // hidden instead of shipping an unconfigured App Check provider.
    expect(AppConfig.appCheckRecaptchaSiteKey, isEmpty);
    expect(
      AppConfig.appCheckRecaptchaSiteKey,
      isNot(contains('6Lf')),
      reason: 'The reCAPTCHA site key must be passed at build time.',
    );
  });

  test('activation never throws when Firebase is not configured', () async {
    // No Firebase app in the test environment: activation must degrade to a
    // failure instead of crashing the app or blocking startup.
    expect(await activateAppCheck(), AppCheckStatus.failed);
  });
}
