import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/data/models/tier.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Tier.fromStatusMessage
  // ---------------------------------------------------------------------------
  group('Tier.fromStatusMessage', () {
    test('null → null', () => expect(Tier.fromStatusMessage(null), isNull));
    test('empty → null', () => expect(Tier.fromStatusMessage(''), isNull));
    test(
      'unrecognised → null',
      () => expect(Tier.fromStatusMessage('OK fine'), isNull),
    );

    // Bare keywords (case-insensitive)
    test('bare "NORMAL" / "normal" / "Normal" → safe', () {
      expect(Tier.fromStatusMessage('NORMAL'), Tier.safe);
      expect(Tier.fromStatusMessage('normal'), Tier.safe);
      expect(Tier.fromStatusMessage('Normal'), Tier.safe);
    });
    test('bare "SAFE" / "safe" → safe', () {
      expect(Tier.fromStatusMessage('SAFE'), Tier.safe);
      expect(Tier.fromStatusMessage('safe'), Tier.safe);
    });
    test('bare "CAUTION" / "caution" / "Caution" → medium', () {
      expect(Tier.fromStatusMessage('CAUTION'), Tier.medium);
      expect(Tier.fromStatusMessage('caution'), Tier.medium);
      expect(Tier.fromStatusMessage('Caution'), Tier.medium);
    });
    test('bare "MEDIUM" / "medium" → medium', () {
      expect(Tier.fromStatusMessage('MEDIUM'), Tier.medium);
      expect(Tier.fromStatusMessage('medium'), Tier.medium);
    });
    test('bare "DANGER" / "danger" / "Danger" → danger', () {
      expect(Tier.fromStatusMessage('DANGER'), Tier.danger);
      expect(Tier.fromStatusMessage('danger'), Tier.danger);
      expect(Tier.fromStatusMessage('Danger'), Tier.danger);
    });

    // Keywords with colons or trailing text
    test('"NORMAL:" with trailing text → safe', () {
      expect(Tier.fromStatusMessage('NORMAL: All parameters fine.'), Tier.safe);
      expect(Tier.fromStatusMessage('normal: all fine'), Tier.safe);
    });
    test('"System Safe" (case-insensitive) → safe', () {
      expect(Tier.fromStatusMessage('System Safe'), Tier.safe);
      expect(Tier.fromStatusMessage('system safe'), Tier.safe);
    });
    test('"SAFE:" prefix → safe', () {
      expect(
        Tier.fromStatusMessage('SAFE: Fan manually overridden ON.'),
        Tier.safe,
      );
      expect(
        Tier.fromStatusMessage('safe: fan manually overridden on.'),
        Tier.safe,
      );
    });
    test('"CAUTION:" prefix → medium', () {
      expect(Tier.fromStatusMessage('CAUTION: Room is stuffy.'), Tier.medium);
      expect(Tier.fromStatusMessage('caution: stuffy'), Tier.medium);
    });
    test('"MEDIUM:" prefix → medium (PRD reference string)', () {
      expect(
        Tier.fromStatusMessage(
          'MEDIUM: The environment is stuffy. Manual toggle available.',
        ),
        Tier.medium,
      );
    });
    test(
      '"MEDIUM:" prefix → medium (actual firmware string from DATA_SAMPLE)',
      () {
        expect(
          Tier.fromStatusMessage(
            'MEDIUM: Environment is stuffy. Manual toggle available.',
          ),
          Tier.medium,
        );
      },
    );
    test('"MEDIUM:" prefix → medium (manual fan variant)', () {
      expect(
        Tier.fromStatusMessage('MEDIUM: Fan manually turned ON by user.'),
        Tier.medium,
      );
    });
    test('"DANGER:" prefix → danger', () {
      expect(
        Tier.fromStatusMessage(
          'DANGER: High thresholds breached! Auto-fan activated.',
        ),
        Tier.danger,
      );
      expect(Tier.fromStatusMessage('danger: alert!'), Tier.danger);
    });
  });

  // ---------------------------------------------------------------------------
  // Tier.fromValues — boundary values (Firmware real thresholds)
  // ---------------------------------------------------------------------------
  group('Tier.fromValues — temperature boundaries', () {
    test('33.4 → safe', () {
      expect(
        Tier.fromValues(temperature: 33.4, humidity: 0, airQuality: 0),
        Tier.safe,
      );
    });
    test('33.5 → medium (boundary: >= tempSafeMax)', () {
      expect(
        Tier.fromValues(temperature: 33.5, humidity: 0, airQuality: 0),
        Tier.medium,
      );
    });
    test('35.0 → medium', () {
      expect(
        Tier.fromValues(temperature: 35.0, humidity: 0, airQuality: 0),
        Tier.medium,
      );
    });
    test('35.9 → medium (below tempDangerMin 36.0)', () {
      expect(
        Tier.fromValues(temperature: 35.9, humidity: 0, airQuality: 0),
        Tier.medium,
      );
    });
    test('36.0 → danger (boundary: >= tempDangerMin)', () {
      expect(
        Tier.fromValues(temperature: 36.0, humidity: 0, airQuality: 0),
        Tier.danger,
      );
    });
    test('36.1 → danger (> tempDangerMin)', () {
      expect(
        Tier.fromValues(temperature: 36.1, humidity: 0, airQuality: 0),
        Tier.danger,
      );
    });
  });

  group('Tier.fromValues — humidity boundaries (TODO: confirm)', () {
    test('59.9 → safe', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 59.9, airQuality: 0),
        Tier.safe,
      );
    });
    test('60.0 → medium (boundary: >= humiditySafeMax)', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 60.0, airQuality: 0),
        Tier.medium,
      );
    });
    test('74.9 → medium', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 74.9, airQuality: 0),
        Tier.medium,
      );
    });
    test('75.0 → danger (boundary: >= humidityDangerMin)', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 75.0, airQuality: 0),
        Tier.danger,
      );
    });
    test('75.1 → danger', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 75.1, airQuality: 0),
        Tier.danger,
      );
    });
  });

  group('Tier.fromValues — air quality boundaries', () {
    test('1399.9 → safe', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 1399.9),
        Tier.safe,
      );
    });
    test('1400.0 → medium (boundary: >= airQualitySafeMax)', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 1400.0),
        Tier.medium,
      );
    });
    test('1999.9 → medium', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 1999.9),
        Tier.medium,
      );
    });
    test('2000.0 → danger (boundary: >= airQualityDangerMin)', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 2000.0),
        Tier.danger,
      );
    });
    test('2000.1 → danger', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 2000.1),
        Tier.danger,
      );
    });
    test('1128 (DATA_SAMPLE value) → safe under new 1400 threshold', () {
      expect(
        Tier.fromValues(temperature: 24.0, humidity: 40.0, airQuality: 1128.0),
        Tier.safe,
      );
    });
  });

  group('Tier.fromValues — null and worst-indicator-wins', () {
    test('all nulls → safe', () {
      expect(Tier.fromValues(), Tier.safe);
    });
    test('only temperature null, humidity=75 → danger', () {
      expect(
        Tier.fromValues(temperature: null, humidity: 75.0, airQuality: 0),
        Tier.danger,
      );
    });
    test(
      'worst indicator wins: safe temp + danger humidity + safe aq → danger',
      () {
        expect(
          Tier.fromValues(temperature: 27.0, humidity: 75.0, airQuality: 500.0),
          Tier.danger,
        );
      },
    );
    test('medium temp + safe humidity + safe aq → medium', () {
      expect(
        Tier.fromValues(temperature: 33.5, humidity: 50.0, airQuality: 500.0),
        Tier.medium,
      );
    });
  });

  // ---------------------------------------------------------------------------
  // Tier.resolve — message takes priority; fallback when unrecognised
  // ---------------------------------------------------------------------------
  group('Tier.resolve', () {
    test('recognised DANGER message overrides safe values', () {
      expect(
        Tier.resolve(
          'DANGER: High thresholds breached! Auto-fan activated.',
          temperature: 20.0,
          humidity: 40.0,
          airQuality: 100.0,
        ),
        Tier.danger,
      );
    });
    test('recognised MEDIUM message overrides safe values', () {
      expect(
        Tier.resolve(
          'MEDIUM: Environment is stuffy. Manual toggle available.',
          temperature: 20.0,
          humidity: 40.0,
          airQuality: 100.0,
        ),
        Tier.medium,
      );
    });
    test('unrecognised message falls back to fromValues', () {
      expect(
        Tier.resolve(
          'unknown msg',
          temperature: 36.0,
          humidity: 40.0,
          airQuality: 100.0,
        ),
        Tier.danger, // temp >= 36.0
      );
    });
    test('null message falls back to fromValues (safe)', () {
      expect(
        Tier.resolve(
          null,
          temperature: 20.0,
          humidity: 40.0,
          airQuality: 100.0,
        ),
        Tier.safe,
      );
    });
    test('recognised SAFE message overrides danger values', () {
      // firmware says safe but values say danger → trust firmware
      expect(
        Tier.resolve(
          'System Safe',
          temperature: 38.0,
          humidity: 80.0,
          airQuality: 3000.0,
        ),
        Tier.safe,
      );
    });
    test('DATA_SAMPLE: MEDIUM message takes precedence even if aq=1128 is value-safe', () {
      expect(
        Tier.resolve(
          'MEDIUM: Environment is stuffy. Manual toggle available.',
          temperature: 24.0,
          humidity: 40.0,
          airQuality: 1128.0,
        ),
        Tier.medium,
      );
    });
  });
}
