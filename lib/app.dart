import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aerosense_app/core/router_refresh.dart';
import 'package:aerosense_app/core/theme.dart';
import 'package:aerosense_app/core/theme_mode_provider.dart';
import 'package:aerosense_app/data/repositories/providers.dart';
import 'package:aerosense_app/features/notices/widgets/in_app_notice_banner.dart';
import 'package:aerosense_app/features/auth/debug_screen.dart';
import 'package:aerosense_app/features/auth/login_screen.dart';
import 'package:aerosense_app/features/dashboard/dashboard_screen.dart';
import 'package:aerosense_app/features/forecast/forecast_screen.dart';
import 'package:aerosense_app/features/history/history_screen.dart';
import 'package:aerosense_app/features/settings/settings_screen.dart';
import 'package:aerosense_app/shared/demo_ribbon.dart';

// ---------------------------------------------------------------------------
// Router provider — created once, never rebuilt inside build()
// ---------------------------------------------------------------------------

/// Provides the [GoRouter] instance. Created once from [ProviderScope].
///
/// The router is kept as a Provider so it can read [authStateProvider] and
/// receive a refreshListenable wired to the auth stream.
final routerProvider = Provider<GoRouter>((ref) {
  final authRepo = ref.watch(authRepositoryProvider);
  final authState = ref.watch(authStateProvider);

  final refreshListenable = GoRouterRefreshStream(authRepo.authStateChanges());
  ref.onDispose(refreshListenable.dispose);

  return GoRouter(
    initialLocation: '/splash',
    refreshListenable: refreshListenable,
    redirect: (context, state) {
      final isLoading = authState.isLoading;
      final user = authRepo.currentUser;
      final location = state.matchedLocation;
      final from = state.uri.queryParameters['from'];

      // While auth is loading, stay on or redirect to splash
      if (isLoading) {
        if (location == '/splash') return null;
        final target = state.uri.toString();
        return '/splash?from=${Uri.encodeComponent(target)}';
      }

      // Auth resolved: handle splash exit
      if (location == '/splash') {
        if (user == null) return '/login';
        // Return to original location or default to dashboard
        return from ?? '/dashboard';
      }

      // Normal auth guards
      if (user == null && location != '/login') return '/login';
      if (user != null && location == '/login') return '/dashboard';
      return null;
    },
    routes: [
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
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final isDesktop = width >= 900;
    final showNoticeBanner = navigationShell.currentIndex != 0;

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
      );
    }

    return Scaffold(
      body: content,
      bottomNavigationBar: NavigationBar(
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
