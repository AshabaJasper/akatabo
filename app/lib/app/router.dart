import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../features/add/add_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/categories/category_detail_screen.dart';
import '../features/fees/fees_screen.dart';
import '../features/forecast/forecast_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/placeholder/placeholder_screen.dart';
import '../features/regular/regular_new_screen.dart';
import '../features/regular/regular_payments_screen.dart';
import '../features/transactions/transaction_detail_screen.dart';
import '../features/transactions/transactions_screen.dart';
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
            routes: [GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.insights, builder: (_, _) => const InsightsScreen())],
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
      GoRoute(path: Routes.onboarding, builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: Routes.welcome, builder: (_, _) => const WelcomeScreen()),
      GoRoute(
        path: Routes.add,
        parentNavigatorKey: rootKey,
        pageBuilder: (_, state) => MaterialPage<void>(
          key: state.pageKey,
          fullscreenDialog: true,
          child: const AddScreen(),
        ),
      ),
      GoRoute(
        path: Routes.transactions,
        parentNavigatorKey: rootKey,
        builder: (_, state) => TransactionsScreen(
          day: int.tryParse(state.uri.queryParameters['day'] ?? ''),
          fromCalendar: state.uri.queryParameters['from'] == 'calendar',
        ),
      ),
      GoRoute(
        path: Routes.calendar,
        parentNavigatorKey: rootKey,
        builder: (_, state) =>
            CalendarScreen(fromList: state.uri.queryParameters['from'] == 'list'),
      ),
      GoRoute(
        path: Routes.categories,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const CategoriesScreen(),
      ),
      GoRoute(
        path: '${Routes.categories}/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) => CategoryDetailScreen(categoryId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(
        path: Routes.fees,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const FeesScreen(),
      ),
      GoRoute(
        path: Routes.forecast,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const ForecastScreen(),
      ),
      GoRoute(
        path: Routes.regular,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const RegularPaymentsScreen(),
      ),
      GoRoute(
        path: Routes.regularNew,
        parentNavigatorKey: rootKey,
        builder: (_, _) => const RegularNewScreen(),
      ),
      GoRoute(
        path: '/transactions/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) => TransactionDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
}
