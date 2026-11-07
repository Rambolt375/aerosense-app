// File generated/configured for AeroSense Firebase connection.
// TODO(human): Run `flutterfire configure` to generate the complete Android/iOS options
// with your registered package name and SHA fingerprints.

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

/// Default [FirebaseOptions] for use with your Firebase apps.
class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      default:
        throw UnsupportedError(
          'DefaultFirebaseOptions are not supported for this platform.',
        );
    }
  }

  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA0M3Ar3xY7-8Dn0hQPP0WpWprfREc2X1k',
    appId: '1:803962149882:web:085d2ac5e2046ec232a243',
    messagingSenderId: '803962149882',
    projectId: 'aerosense-502de',
    authDomain: 'aerosense-502de.firebaseapp.com',
    databaseURL: 'https://aerosense-502de-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'aerosense-502de.firebasestorage.app',
  );

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyDc8MyHjOKl5U3DzbPpTq2tCBoiFGWUHLI',
    appId: '1:803962149882:android:7e19d606063534d332a243',
    messagingSenderId: '803962149882',
    projectId: 'aerosense-502de',
    databaseURL: 'https://aerosense-502de-default-rtdb.asia-southeast1.firebasedatabase.app',
    storageBucket: 'aerosense-502de.firebasestorage.app',
  );
}
