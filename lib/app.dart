import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/router_refresh.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/notices/in_app_notice_notifier.dart';
import 'package:aerosense_app/features/notices/widgets/in_app_notice_banner.dart';
import 'package:aerosense_app/features/auth/debug_screen.dart';
import 'package:aerosense_app/features/auth/login_screen.dart';
import 'package:aerosense_app/features/assistant/assistant_screen.dart';
import 'package:aerosense_app/features/dashboard/dashboard_screen.dart';
import 'package:aerosense_app/features/forecast/forecast_screen.dart';
import 'package:aerosense_app/features/forecast/preventive_providers.dart';
import 'package:aerosense_app/features/history/history_screen.dart';
import 'package:aerosense_app/features/landing/landing_providers.dart';
import 'package:aerosense_app/features/landing/landing_screen.dart';
import 'package:aerosense_app/features/profile/profile_screen.dart';
import 'package:aerosense_app/features/settings/settings_screen.dart';
import 'package:aerosense_app/shared/demo_ribbon.dart';
import 'package:aerosense_app/shared/assistant_speed_dial.dart';

// ---------------------------------------------------------------------------
// Router provider — created once, never rebuilt inside build()
// ---------------------------------------------------------------------------

/// Returns [from] only when it is a safe internal path worth returning to.
///
/// A deep link that is not one of the public entry points is worth returning
/// to after sign-in; anything else (external URL, protocol-relative `//host`,
/// or one of the entry points themselves) falls back to the dashboard. The
/// dashboard is excluded too, because it is already the default after sign-in
/// and would otherwise leave a stale `from` in the URL after an explicit
/// sign-out.
String? safeRedirectFrom(String? from) {
  if (from == null || from.isEmpty) return null;
  if (!from.startsWith('/')) return null;
  if (from.startsWith('//')) return null;
  const rejected = {'/', '/login', '/splash', '/dashboard'};
  final path = from.split('?').first;
  if (rejected.contains(path)) return null;
  return from;
}

/// Provides the [GoRouter] instance. Created once from [ProviderScope].
///
/// The router deliberately does **not** watch the auth state: rebuilding it
/// would recreate the router at [GoRouter.initialLocation] and lose the page the
/// visitor asked for. Instead the auth state is read inside `redirect` and the
/// router is refreshed through [RouterRefreshNotifier] whenever it changes.
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = RouterRefreshNotifier();
  ref.onDispose(refresh.dispose);

  // Refresh, never rebuild. `ref.listen` keeps the provider alive without
  // making this provider depend on it.
  ref.listen(authStateProvider, (_, _) => refresh.refresh());
  ref.listen(webLandingEnabledProvider, (_, _) => refresh.refresh());

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final location = state.matchedLocation;
      final from = state.uri.queryParameters['from'];

      // While the first auth event is in flight, park on splash and remember
      // where the visitor was going.
      if (auth.isLoading) {
        if (location == '/splash') return null;
        return '/splash?from=${Uri.encodeComponent(state.uri.toString())}';
      }

      final user = auth.value;

      // Auth resolved: leave splash for the remembered location or the entry
      // point for this platform. A signed-out deep link is carried through to
      // the login screen so the visitor still lands where they asked.
      if (location == '/splash') {
        if (user != null) return safeRedirectFrom(from) ?? '/dashboard';
        final target = safeRedirectFrom(from);
        if (target != null) {
          return '/login?from=${Uri.encodeComponent(target)}';
        }
        return ref.read(webLandingEnabledProvider) ? '/' : '/login';
      }

      if (user != null) {
        // Signed-in visitors never see the public pages.
        if (location == '/login') {
          return safeRedirectFrom(from) ?? '/dashboard';
        }
        if (location == '/') return '/dashboard';
        return null;
      }

      // Signed out: `/` is the landing page on web and the login screen on
      // Android; `/login` is always public; everything else is guarded and
      // remembers where the visitor wanted to go.
      if (location == '/login') return null;
      if (location == '/') {
        return ref.read(webLandingEnabledProvider) ? null : '/login';
      }
      // Only a deep link worth returning to is carried through sign-in; the
      // dashboard is the default anyway, so it must not leave a stale `from`.
      final target = safeRedirectFrom(state.uri.toString());
      if (target == null) {
        return ref.read(webLandingEnabledProvider) ? '/' : '/login';
      }
      return '/login?from=${Uri.encodeComponent(target)}';
    },
    routes: [
      // Public landing page. Registered on every platform so the route table is
      // identical; the redirect decides whether Android ever sees it.
      GoRoute(
        path: '/',
        name: 'landing',
        builder: (context, state) => const LandingScreen(),
      ),
      GoRoute(
        path: '/splash',
        name: 'splash',
        builder: (context, state) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(
        path: '/login',
        name: 'login',
        builder: (context, state) => const LoginScreen(),
      ),
      // Full-screen assistant, outside the shell so there is no fifth nav tab.
      GoRoute(
        path: '/assistant',
        name: 'assistant',
        builder: (context, state) => const AssistantScreen(),
      ),
      // Full-screen profile, also outside the shell (reached from the account
      // menu). The auth guard above protects it like any other route.
      GoRoute(
        path: '/profile',
        name: 'profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      // Debug screen — only registered in debug builds.
      if (kDebugMode)
        GoRoute(
          path: '/debug',
          name: 'debug',
          builder: (context, state) => const DebugScreen(),
        ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShellScaffold(navigationShell: navigationShell);
        },
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/dashboard',
                name: 'dashboard',
                builder: (context, state) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/history',
                name: 'history',
                builder: (context, state) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/forecast',
                name: 'forecast',
                builder: (context, state) => const ForecastScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/settings',
                name: 'settings',
                builder: (context, state) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// ---------------------------------------------------------------------------
// Root application widget
// ---------------------------------------------------------------------------

/// Root application widget. Reads the router from [routerProvider].
class AeroSenseApp extends ConsumerWidget {
  const AeroSenseApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'AeroSense',
      debugShowCheckedModeBanner: false,
      theme: AeroSenseTheme.light,
      darkTheme: AeroSenseTheme.dark,
      themeMode: themeMode,
      routerConfig: router,
      builder: (context, child) {
        final isDemo = ref.watch(demoModeProvider);
        if (!isDemo) return child ?? const SizedBox.shrink();

        return Column(
          children: [
            const DemoRibbon(),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeTop: true,
                child: child ?? const SizedBox.shrink(),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Adaptive shell scaffold
// ---------------------------------------------------------------------------

/// Switches between bottom [NavigationBar] on mobile (< 900 dp)
/// and [NavigationRail] on web/desktop (≥ 900 dp). See DESIGN.md §4.
class AppShellScaffold extends ConsumerWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final showNoticeBanner = navigationShell.currentIndex != 0;
    final keyboardIsOpen = MediaQuery.viewInsetsOf(context).bottom > 0;

    // Active pre-ventilation publisher watcher (if designated as publishing device)
    ref.watch(preventivePublisherProvider);

    // Listen for transient device offline/online notices and show floating snackbar
    ref.listen<InAppNotice?>(inAppNoticeProvider, (previous, next) {
      if (next == null) return;
      if (next.type == NoticeType.deviceOffline ||
          next.type == NoticeType.deviceOnline) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.clearSnackBars();
        messenger.showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 5),
            width: isDesktop ? 560 : null,
            content: Text(next.message),
          ),
        );
      }
    });

    final content = Column(
      children: [
        if (showNoticeBanner) const InAppNoticeBanner(),
        Expanded(child: navigationShell),
      ],
    );

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              destinations: const [
                NavigationRailDestination(
                  icon: Icon(Icons.dashboard_outlined),
                  selectedIcon: Icon(Icons.dashboard),
                  label: Text('Dashboard'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.show_chart_outlined),
                  selectedIcon: Icon(Icons.show_chart),
                  label: Text('History'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.auto_graph_outlined),
                  selectedIcon: Icon(Icons.auto_graph),
                  label: Text('Forecast'),
                ),
                NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Settings'),
                ),
              ],
            ),
            const VerticalDivider(thickness: 1, width: 1),
            Expanded(child: content),
          ],
        ),
        floatingActionButton: keyboardIsOpen
            ? null
            : const AssistantSpeedDial(),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      );
    }

    return Scaffold(
      body: content,
      floatingActionButton: keyboardIsOpen ? null : const AssistantSpeedDial(),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      bottomNavigationBar: NavigationBar(
        height: 68,
        backgroundColor: Theme.of(context).colorScheme.surface,
        // Keep the M3 indicator: the selected icon is painted with
        // onSecondaryContainer (near-black navy here), so a transparent
        // indicator leaves it invisible on the dark surface and diverges
        // from NavigationRail's selected state.
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.show_chart_outlined),
            selectedIcon: Icon(Icons.show_chart),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.auto_graph_outlined),
            selectedIcon: Icon(Icons.auto_graph),
            label: 'Forecast',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
