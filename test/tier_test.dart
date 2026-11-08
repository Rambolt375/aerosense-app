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

    test('"System Safe" → safe', () {
      expect(Tier.fromStatusMessage('System Safe'), Tier.safe);
    });
    test('"SAFE:" prefix → safe', () {
      expect(
        Tier.fromStatusMessage('SAFE: Fan manually overridden ON.'),
        Tier.safe,
      );
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
        // Real firmware string observed in DATA_SAMPLE.json — differs from PRD
        // reference by omitting "The". Prefix matching handles both.
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
    });

    test('case-sensitive: "danger:" (lowercase) → null', () {
      expect(Tier.fromStatusMessage('danger: something'), isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Tier.fromValues — boundary values (PRD §10)
  // ---------------------------------------------------------------------------
  group('Tier.fromValues — temperature boundaries', () {
    test('27.9 → safe', () {
      expect(
        Tier.fromValues(temperature: 27.9, humidity: 0, airQuality: 0),
        Tier.safe,
      );
    });
    test('28.0 → medium (boundary: >= tempSafeMax)', () {
      expect(
        Tier.fromValues(temperature: 28.0, humidity: 0, airQuality: 0),
        Tier.medium,
      );
    });
    test('30.0 → medium', () {
      expect(
        Tier.fromValues(temperature: 30.0, humidity: 0, airQuality: 0),
        Tier.medium,
      );
    });
    test('32.0 → medium (not yet > tempDangerMin)', () {
      expect(
        Tier.fromValues(temperature: 32.0, humidity: 0, airQuality: 0),
        Tier.medium,
      );
    });
    test('32.1 → danger (> tempDangerMin)', () {
      expect(
        Tier.fromValues(temperature: 32.1, humidity: 0, airQuality: 0),
        Tier.danger,
      );
    });
  });

  group('Tier.fromValues — humidity boundaries', () {
    test('59.9 → safe', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 59.9, airQuality: 0),
        Tier.safe,
      );
    });
    test('60.0 → medium', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 60.0, airQuality: 0),
        Tier.medium,
      );
    });
    test('75.0 → medium', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 75.0, airQuality: 0),
        Tier.medium,
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
    test('999.9 → safe', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 999.9),
        Tier.safe,
      );
    });
    test('1000.0 → medium', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 1000.0),
        Tier.medium,
      );
    });
    test('2000.0 → medium', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 2000.0),
        Tier.medium,
      );
    });
    test('2000.1 → danger', () {
      expect(
        Tier.fromValues(temperature: 0, humidity: 0, airQuality: 2000.1),
        Tier.danger,
      );
    });
    // DATA_SAMPLE: airQuality=1128 → medium
    test('1128 (DATA_SAMPLE value) → medium', () {
      expect(
        Tier.fromValues(temperature: 24.0, humidity: 40.0, airQuality: 1128.0),
        Tier.medium,
      );
    });
  });

  group('Tier.fromValues — null and worst-indicator-wins', () {
    test('all nulls → safe', () {
      expect(Tier.fromValues(), Tier.safe);
    });
    test('only temperature null, humidity=76 → danger', () {
      expect(
        Tier.fromValues(temperature: null, humidity: 76.0, airQuality: 0),
        Tier.danger,
      );
    });
    test(
      'worst indicator wins: safe temp + danger humidity + safe aq → danger',
      () {
        expect(
          Tier.fromValues(temperature: 27.0, humidity: 76.0, airQuality: 500.0),
          Tier.danger,
        );
      },
    );
    test('medium temp + safe humidity + safe aq → medium', () {
      expect(
        Tier.fromValues(temperature: 29.0, humidity: 50.0, airQuality: 500.0),
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
      // "unknown msg" is not a recognised prefix → fromValues used
      expect(
        Tier.resolve(
          'unknown msg',
          temperature: 33.0,
          humidity: 40.0,
          airQuality: 100.0,
        ),
        Tier.danger, // temp > 32.0
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
          temperature: 35.0,
          humidity: 80.0,
          airQuality: 3000.0,
        ),
        Tier.safe,
      );
    });
    test('DATA_SAMPLE: MEDIUM message + aq=1128 (both medium) → medium', () {
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
