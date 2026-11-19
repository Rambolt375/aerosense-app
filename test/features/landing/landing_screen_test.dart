import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/landing/landing_copy.dart';
import 'package:aerosense_app/features/landing/landing_providers.dart';
import 'package:aerosense_app/features/landing/landing_screen.dart';

class _AlwaysDemoNotifier extends DemoModeNotifier {
  @override
  bool build() => true;
}

/// Harness with a real [GoRouter] so the landing buttons can navigate.
Widget _harness({
  void Function(String url)? opener,
  double textScale = 1.0,
  bool demo = false,
  bool disableAnimations = false,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/', builder: (context, state) => const LandingScreen()),
      GoRoute(
        path: '/login',
        builder: (context, state) => const Scaffold(body: Text('login-stub')),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) =>
            const Scaffold(body: Text('dashboard-stub')),
      ),
    ],
  );
  addTearDown(router.dispose);

  return ProviderScope(
    overrides: [
      if (opener != null) urlOpenerProvider.overrideWithValue(opener),
      if (demo) demoModeProvider.overrideWith(_AlwaysDemoNotifier.new),
    ],
    child: MaterialApp.router(
      theme: AeroSenseTheme.light,
      routerConfig: router,
      builder: (context, child) {
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: disableAnimations,
          ),
          child: child ?? const SizedBox.shrink(),
        );
      },
    ),
  );
}

Finder _getStartedButton() =>
    find.widgetWithText(FilledButton, LandingCopy.openDashboard);

void main() {
  testWidgets('shows the hero with the name, the one line and both actions', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text(LandingCopy.appName), findsWidgets);
    expect(find.text(LandingCopy.tagline), findsOneWidget);
    expect(_getStartedButton(), findsOneWidget);
    expect(
      find.widgetWithText(OutlinedButton, LandingCopy.tryDemo),
      findsOneWidget,
    );
    expect(
      find.widgetWithText(OutlinedButton, LandingCopy.downloadApk),
      findsOneWidget,
    );
  });

  testWidgets('shows the three states with icon and text plus the rule', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text(LandingCopy.statesTitle), findsOneWidget);
    for (final title in const [
      LandingCopy.safeTitle,
      LandingCopy.cautionTitle,
      LandingCopy.dangerTitle,
    ]) {
      expect(find.text(title), findsOneWidget);
    }
    expect(find.text(LandingCopy.safeBody), findsOneWidget);
    expect(find.text(LandingCopy.cautionBody), findsOneWidget);
    expect(find.text(LandingCopy.dangerBody), findsOneWidget);
    expect(find.text(LandingCopy.statesClosing), findsOneWidget);

    // Tier is never shown by colour alone: each card carries its own icon.
    expect(find.byIcon(Icons.check_circle_outline), findsOneWidget);
    expect(find.byIcon(Icons.warning_amber_outlined), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
  });

  testWidgets('shows the four how-it-works steps in order', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text(LandingCopy.howTitle), findsOneWidget);
    expect(LandingCopy.howSteps, hasLength(4));
    for (final step in LandingCopy.howSteps) {
      expect(find.text(step.title), findsOneWidget);
    }
  });

  testWidgets('shows the low-cost section', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text(LandingCopy.lowCostTitle), findsOneWidget);
    expect(find.text(LandingCopy.lowCostBody), findsOneWidget);
    expect(LandingCopy.lowCostBody, contains('Rp 200.000'));
  });

  testWidgets('always shows the Android button and its helper text', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text(LandingCopy.getAppTitle), findsOneWidget);
    expect(find.text(LandingCopy.getAppBody), findsOneWidget);
    expect(find.text(LandingCopy.apkButton), findsOneWidget);
    expect(find.text(LandingCopy.apkHelper), findsOneWidget);
  });

  testWidgets('the Get the app button is primary and uses the Android logo', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    // Same primary treatment as "Open dashboard", not an outlined button.
    final button = find.widgetWithText(FilledButton, LandingCopy.apkButton);
    expect(button, findsOneWidget);
    expect(
      find.ancestor(
        of: find.text(LandingCopy.apkButton),
        matching: find.byType(OutlinedButton),
      ),
      findsNothing,
    );
    expect(
      find.descendant(of: button, matching: find.byIcon(Icons.android)),
      findsOneWidget,
    );
  });

  testWidgets(
    'the hero Download APK button scrolls to the Get the app section',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final opened = <String>[];
      await tester.pumpWidget(_harness(opener: opened.add));
      await tester.pumpAndSettle();

      // The section starts off screen on a phone-sized viewport.
      final section = find.text(LandingCopy.getAppTitle);
      expect(tester.getTopLeft(section).dy, greaterThan(640));

      final heroButton = find.widgetWithText(
        OutlinedButton,
        LandingCopy.downloadApk,
      );
      expect(heroButton, findsOneWidget);
      await tester.tap(heroButton);
      await tester.pumpAndSettle();

      // It scrolls, and it does not open GitHub by itself.
      expect(tester.getTopLeft(section).dy, lessThan(640));
      expect(opened, isEmpty);
    },
  );

  testWidgets('the Android button opens the GitHub releases page', (
    tester,
  ) async {
    final opened = <String>[];
    await tester.pumpWidget(_harness(opener: opened.add));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text(LandingCopy.apkButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text(LandingCopy.apkButton));
    await tester.pumpAndSettle();

    // A redirect to the releases page, not a direct APK file.
    expect(opened, ['https://github.com/Rambolt375/aerosense-app/releases']);
    expect(opened.single, isNot(endsWith('.apk')));
  });

  testWidgets('shows the prototype footer with the version', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.text(LandingCopy.footer), findsOneWidget);
    expect(find.textContaining(AppConfig.appVersion), findsOneWidget);
  });

  testWidgets('Open dashboard navigates to the login route', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    await tester.tap(_getStartedButton());
    await tester.pumpAndSettle();

    expect(find.text('login-stub'), findsOneWidget);
  });

  testWidgets('Try the demo turns Demo Mode on and opens the dashboard', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(LandingScreen)),
    );
    expect(container.read(demoModeProvider), isFalse);

    await tester.tap(find.text(LandingCopy.tryDemo));
    await tester.pumpAndSettle();

    expect(container.read(demoModeProvider), isTrue);
    expect(find.text('dashboard-stub'), findsOneWidget);
  });

  testWidgets('copy never claims ppm or percentage savings', (tester) async {
    for (final text in LandingCopy.all) {
      expect(
        text.toLowerCase(),
        isNot(contains('ppm')),
        reason: 'Air quality is a raw index, never ppm: "$text"',
      );
      expect(
        text,
        isNot(contains('%')),
        reason: 'No unmeasured savings percentages: "$text"',
      );
    }
  });

  testWidgets('hero is two columns at 1280 and one column at 360', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final wideLogo = tester.getTopLeft(find.byType(Image).first);
    final wideText = tester.getTopLeft(find.text(LandingCopy.tagline));
    expect(wideLogo.dx, greaterThan(wideText.dx));

    tester.view.physicalSize = const Size(360, 640);
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    final narrowLogo = tester.getTopLeft(find.byType(Image).first);
    final narrowText = tester.getTopLeft(find.text(LandingCopy.tagline));
    expect(narrowLogo.dy, lessThan(narrowText.dy));
  });

  testWidgets('skips the entrance animation when animations are disabled', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(disableAnimations: true));
    await tester.pump();

    expect(find.byType(TweenAnimationBuilder<double>), findsNothing);

    await tester.pumpWidget(_harness());
    await tester.pump();

    expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    await tester.pumpAndSettle();
  });

  testWidgets('section headings are marked as headers for screen readers', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    for (final title in const [
      LandingCopy.appName,
      LandingCopy.statesTitle,
      LandingCopy.howTitle,
      LandingCopy.lowCostTitle,
      LandingCopy.getAppTitle,
    ]) {
      final data = tester
          .getSemantics(find.text(title).first)
          .getSemanticsData();
      expect(
        data.flagsCollection.isHeader,
        isTrue,
        reason: '"$title" must be a heading for screen readers',
      );
    }

    handle.dispose();
  });

  testWidgets('renders in the dark theme with the tier containers', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AeroSenseTheme.dark,
          home: const LandingScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(LandingCopy.safeBody), findsOneWidget);
    expect(find.text(LandingCopy.dangerBody), findsOneWidget);
  });

  for (final size in const [Size(360, 640), Size(768, 1024), Size(1280, 800)]) {
    testWidgets(
      'renders without overflow at ${size.width.toInt()}x${size.height.toInt()} '
      'with 1.3x text',
      (tester) async {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        await tester.pumpWidget(_harness(textScale: 1.3));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text(LandingCopy.tagline), findsOneWidget);
        expect(find.text(LandingCopy.statesClosing), findsOneWidget);
      },
    );
  }
}
