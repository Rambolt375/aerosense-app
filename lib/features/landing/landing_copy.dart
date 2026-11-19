/// Every string on the public landing page, in one file.
///
/// The landing page is English only: it is the first thing a judge or a
/// passer-by sees on the web, and the language selector inside the app is a
/// per-device preference that a signed-out visitor has not set yet.
///
/// Voice rules from DESIGN.md §8 apply: plain, calm, factual, no exclamation
/// marks, and nothing that implies the app decides safety. No `ppm` (air
/// quality is a raw, uncalibrated index) and no savings percentages, because
/// neither is measured.
class LandingCopy {
  LandingCopy._();

  static const appName = 'AeroSense';
  static const tagline =
      "Adaptive ventilation that watches your room's air and keeps the fan off "
      'unless it is needed.';

  static const openDashboard = 'Open dashboard';
  static const tryDemo = 'Try the demo';

  static const statesTitle = 'Three states, one rule';

  static const safeTitle = 'Safe';
  static const safeBody = 'The air is fine. The fan stays off to save power.';

  static const cautionTitle = 'Caution';
  static const cautionBody =
      'The air is getting stuffy. You decide: start a timed ventilation run '
      'from the app.';

  static const dangerTitle = 'Danger';
  static const dangerBody =
      'The device forces the fan on by itself, even without internet.';

  static const statesClosing = 'The device decides. The app shows and asks.';

  static const howTitle = 'How it works';
  static const howSteps = <LandingStep>[
    LandingStep(
      title: 'Sensors',
      body: 'Temperature, humidity and air quality are read every two seconds.',
    ),
    LandingStep(
      title: 'ESP32 controller',
      body:
          'The controller applies one rule to those readings and sets the '
          'tier and the fan.',
    ),
    LandingStep(
      title: 'Cloud',
      body: 'Readings are stored so the app can show history and a forecast.',
    ),
    LandingStep(
      title: 'This app',
      body:
          'It shows what the device reports, and asks the device to run the '
          'fan when you choose to.',
    ),
  ];

  static const lowCostTitle = 'Low cost';
  static const lowCostBody =
      'About Rp 200.000 in parts. No soldering: the sensors and the controller '
      'plug together. Built for homes and boarding houses, not factories.';

  static const getAppTitle = 'Get the app';
  static const getAppBody =
      'The dashboard runs in any modern browser. Nothing to install.';
  static const apkButton = 'Get the Android app';
  static const downloadApk = 'Download APK';
  static const apkHelper =
      'Opens our GitHub releases page, where you can download the APK. '
      'Android only. Your phone may ask you to allow installs from your '
      'browser. Prototype build.';

  static const footer = 'Prototype by Team Kirkversary for Techtonic 3.0';

  /// Flat list of every user-visible string, for the copy tests.
  static List<String> get all => <String>[
    appName,
    tagline,
    openDashboard,
    tryDemo,
    statesTitle,
    safeTitle,
    safeBody,
    cautionTitle,
    cautionBody,
    dangerTitle,
    dangerBody,
    statesClosing,
    howTitle,
    for (final step in howSteps) ...<String>[step.title, step.body],
    lowCostTitle,
    lowCostBody,
    getAppTitle,
    getAppBody,
    apkButton,
    downloadApk,
    apkHelper,
    footer,
  ];
}

/// One numbered step in the "How it works" section.
class LandingStep {
  const LandingStep({required this.title, required this.body});

  final String title;
  final String body;
}
