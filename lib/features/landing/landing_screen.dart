import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/config.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/landing/landing_copy.dart';
import 'package:aerosense_app/features/landing/landing_providers.dart';

/// Public landing page served at `/` on the web only.
///
/// Registered for every platform, but the redirect sends Android straight to
/// `/login`, so this is what a judge or a passer-by sees before signing in. It
/// is static: no Firebase read, no device data, no claims the firmware cannot
/// back up.
class LandingScreen extends ConsumerStatefulWidget {
  const LandingScreen({super.key});

  /// Page content width, per DESIGN.md §4 (web desktop gutter rule).
  static const double maxContentWidth = 1100;

  /// Hero switches from one column to two at this width.
  static const double heroBreakpoint = 900;

  @override
  ConsumerState<LandingScreen> createState() => _LandingScreenState();
}

class _LandingScreenState extends ConsumerState<LandingScreen> {
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _getAppSectionKey = GlobalKey();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  /// Scrolls to the "Get the app" section instead of downloading from the hero.
  ///
  /// The hero button is a shortcut, not a second download: the section explains
  /// what the APK is and that it comes from GitHub, so the visitor reads that
  /// before leaving the page.
  void _scrollToGetApp() {
    final context = _getAppSectionKey.currentContext;
    if (context == null) return;
    Scrollable.ensureVisible(
      context,
      duration: MediaQuery.maybeDisableAnimationsOf(context) ?? false
          ? Duration.zero
          : const Duration(milliseconds: 250),
      curve: Curves.easeOut,
      alignment: 0.05,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final pagePadding = width < 600 ? 16.0 : 24.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: LandingScreen.maxContentWidth,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: pagePadding,
                  vertical: 24,
                ),
                child: _Entrance(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _Hero(
                        wide: width >= LandingScreen.heroBreakpoint,
                        onOpenDashboard: () => context.go('/login'),
                        onTryDemo: () {
                          ref.read(demoModeProvider.notifier).setDemo(true);
                          context.go('/dashboard');
                        },
                        onDownloadApk: _scrollToGetApp,
                      ),
                      const SizedBox(height: 48),
                      const _StatesSection(),
                      const SizedBox(height: 48),
                      const _HowSection(),
                      const SizedBox(height: 48),
                      const _LowCostSection(),
                      const SizedBox(height: 48),
                      _GetAppSection(key: _getAppSectionKey),
                      const SizedBox(height: 32),
                      const _Footer(),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Single, light entrance animation; skipped when animations are disabled.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final disableAnimations =
        MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (disableAnimations) return child;

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, (1 - value) * 8),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.wide,
    required this.onOpenDashboard,
    required this.onTryDemo,
    required this.onDownloadApk,
  });

  final bool wide;
  final VoidCallback onOpenDashboard;
  final VoidCallback onTryDemo;
  final VoidCallback onDownloadApk;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final logo = ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Image.asset(
        'assets/icon/icon.png',
        width: 144,
        height: 144,
        semanticLabel: 'AeroSense app icon',
      ),
    );

    final copy = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            LandingCopy.appName,
            style: theme.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: theme.colorScheme.onSurface,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          LandingCopy.tagline,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 24),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              onPressed: onOpenDashboard,
              child: const Text(LandingCopy.openDashboard),
            ),
            OutlinedButton(
              onPressed: onTryDemo,
              child: const Text(LandingCopy.tryDemo),
            ),
            // Shortcut only: it scrolls to the "Get the app" section so the
            // visitor reads what the APK is before leaving for GitHub.
            OutlinedButton.icon(
              onPressed: onDownloadApk,
              icon: const Icon(Icons.android, size: 20),
              label: const Text(LandingCopy.downloadApk),
            ),
          ],
        ),
      ],
    );

    if (!wide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [logo, const SizedBox(height: 24), copy],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 3, child: copy),
        const SizedBox(width: 32),
        Expanded(flex: 2, child: Center(child: logo)),
      ],
    );
  }
}

/// One heading style for every section, so the page reads as one document.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(text, style: Theme.of(context).textTheme.headlineSmall),
    );
  }
}

class _StatesSection extends StatelessWidget {
  const _StatesSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tierColors = context.tierColors;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(LandingCopy.statesTitle),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final cards = [
              _StateCard(
                icon: Icons.check_circle_outline,
                title: LandingCopy.safeTitle,
                body: LandingCopy.safeBody,
                solid: tierColors.safe,
                container: tierColors.safeContainer,
              ),
              _StateCard(
                icon: Icons.warning_amber_outlined,
                title: LandingCopy.cautionTitle,
                body: LandingCopy.cautionBody,
                solid: tierColors.medium,
                container: tierColors.mediumContainer,
              ),
              _StateCard(
                icon: Icons.error_outline,
                title: LandingCopy.dangerTitle,
                body: LandingCopy.dangerBody,
                solid: tierColors.danger,
                container: tierColors.dangerContainer,
              ),
            ];

            if (constraints.maxWidth < 720) {
              return Column(
                children: [
                  for (final card in cards)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: card,
                    ),
                ],
              );
            }

            return IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < cards.length; i++) ...[
                    if (i > 0) const SizedBox(width: 16),
                    Expanded(child: cards[i]),
                  ],
                ],
              ),
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          LandingCopy.statesClosing,
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Tier card. Colour is never the only signal: every card carries icon + word.
class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.body,
    required this.solid,
    required this.container,
  });

  final IconData icon;
  final String title;
  final String body;
  final Color solid;
  final Color container;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: container,
        border: Border.all(color: solid, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: solid),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _HowSection extends StatelessWidget {
  const _HowSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(LandingCopy.howTitle),
        const SizedBox(height: 16),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 900
                ? 4
                : constraints.maxWidth >= 600
                ? 2
                : 1;
            const spacing = 16.0;
            final itemWidth =
                (constraints.maxWidth - spacing * (columns - 1)) / columns;

            return Wrap(
              spacing: spacing,
              runSpacing: spacing,
              children: [
                for (var i = 0; i < LandingCopy.howSteps.length; i++)
                  SizedBox(
                    width: itemWidth,
                    child: _HowStepCard(
                      index: i + 1,
                      step: LandingCopy.howSteps[i],
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}

class _HowStepCard extends StatelessWidget {
  const _HowStepCard({required this.index, required this.step});

  final int index;
  final LandingStep step;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outline, width: 1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24,
                height: 24,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  '$index',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: colorScheme.onSecondaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(step.title, style: theme.textTheme.titleSmall),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            step.body,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowCostSection extends StatelessWidget {
  const _LowCostSection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(LandingCopy.lowCostTitle),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.outline, width: 1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.savings_outlined,
                size: 20,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  LandingCopy.lowCostBody,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _GetAppSection extends ConsumerWidget {
  const _GetAppSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final apkUrl = ref.watch(apkDownloadUrlProvider);
    final openUrl = ref.watch(urlOpenerProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeading(LandingCopy.getAppTitle),
        const SizedBox(height: 16),
        Text(
          LandingCopy.getAppBody,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        // A plain redirect to the GitHub releases page: no file is served by
        // the app, and the visitor picks the build there. Primary styling to
        // match "Open dashboard", since it is the main action of this section.
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            onPressed: () => openUrl(apkUrl),
            icon: const Icon(Icons.android, size: 20),
            label: const Text(LandingCopy.apkButton),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          LandingCopy.apkHelper,
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: colorScheme.outline, height: 1),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              LandingCopy.footer,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Text(
              AppConfig.appVersion,
              style: theme.textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
