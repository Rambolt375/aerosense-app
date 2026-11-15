import 'package:flutter_test/flutter_test.dart';
import 'package:aerosense_app/core/browser_utils.dart';

void main() {
  group('isInAppBrowser', () {
    test('returns false for null or empty user agent', () {
      expect(isInAppBrowser(null), isFalse);
      expect(isInAppBrowser(''), isFalse);
      expect(isInAppBrowser('   '), isFalse);
    });

    test('returns false for standard desktop and mobile browsers', () {
      // Chrome on Linux / Windows
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        ),
        isFalse,
      );

      // Chrome on Android
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (Linux; Android 13; Pixel 7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.6099.43 Mobile Safari/537.36',
        ),
        isFalse,
      );

      // Safari on iOS
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 17_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.1 Mobile/15E148 Safari/604.1',
        ),
        isFalse,
      );

      // Firefox on Android
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (Android 13; Mobile; rv:120.0) Gecko/120.0 Firefox/120.0',
        ),
        isFalse,
      );
    });

    test('detects Instagram in-app browser', () {
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 289.0.0.25.49',
        ),
        isTrue,
      );
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (Linux; Android 12; SM-G991B Build/SP1A.210812.016; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/100.0.4896.127 Mobile Safari/537.36 Instagram 231.0.0.19.114',
        ),
        isTrue,
      );
    });

    test('detects Facebook in-app browser (FBAN, FBAV, FB_IAB)', () {
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 [FBAN/FBIOS;FBDV/iPhone13,2;FBMD/iPhone;FBSN/iOS;FBSV/16.5;FBSS/3;FBID/phone;FBLC/en_US;FBOP/5]',
        ),
        isTrue,
      );
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (Linux; Android 12; Pixel 6 Build/SQ3A.220705.004; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/103.0.5060.71 Mobile Safari/537.36 [FB_IAB/FB4A;FBAV/375.1.0.28.111;]',
        ),
        isTrue,
      );
    });

    test('detects Line in-app browser', () {
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Line/12.19.1',
        ),
        isTrue,
      );
    });

    test('detects WhatsApp in-app browser', () {
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 16_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 WhatsApp/2.22.24.81',
        ),
        isTrue,
      );
    });

    test('detects TikTok in-app browser', () {
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (Linux; Android 10; SM-A505FN Build/QP1A.190711.020; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/80.0.3987.162 Mobile Safari/537.36 TikTok 18.2.3',
        ),
        isTrue,
      );
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (iPhone; CPU iPhone OS 15_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 musical_ly_23.4.0',
        ),
        isTrue,
      );
    });

    test('detects generic Android WebView', () {
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (Linux; U; Android 4.4.2; en-us; LGMS323 Build/KOT49I.MS32310c) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/30.0.0.0 Mobile Safari/537.36',
        ),
        isTrue,
      );
      expect(
        isInAppBrowser(
          'Mozilla/5.0 (Linux; Android 13; Pixel 6 Build/TP1A.220624.014; wv) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/103.0.5060.71 Mobile Safari/537.36',
        ),
        isTrue,
      );
    });
  });
}
