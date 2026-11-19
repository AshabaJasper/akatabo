import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/placeholder/placeholder_screen.dart';
import 'routes.dart';
import 'shell_scaffold.dart';

/// Builds the app's router. A new router and root key per app instance keeps widget tests
/// isolated.
GoRouter buildRouter({String initialLocation = Routes.home}) {
  final rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
  return GoRouter(
    navigatorKey: rootKey,
    initialLocation: initialLocation,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => ShellScaffold(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.home,
                builder: (_, _) => const PlaceholderScreen(title: 'Home'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.insights,
                builder: (_, _) => const PlaceholderScreen(title: 'Insights'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.budgets,
                builder: (_, _) => const PlaceholderScreen(title: 'Budgets'),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: Routes.settings,
                builder: (_, _) => const PlaceholderScreen(title: 'Settings'),
              ),
            ],
          ),
        ],
      ),
      GoRoute(
        path: Routes.add,
        parentNavigatorKey: rootKey,
        pageBuilder: (_, state) => MaterialPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const PlaceholderScreen(title: 'Add a transaction', closable: true),
        ),
      ),
    ],
  );
}
