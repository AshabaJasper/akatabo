import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../data/db/app_database.dart' show CategoryKind;

import '../features/add/add_screen.dart';
import '../features/budgets/budget_edit_screen.dart';
import '../features/budgets/budgets_screen.dart';
import '../features/calendar/calendar_screen.dart';
import '../features/categories/categories_screen.dart';
import '../features/categories/category_detail_screen.dart';
import '../features/fees/fees_screen.dart';
import '../features/filters/choose_dates_screen.dart';
import '../features/filters/filters_screen.dart';
import '../features/forecast/forecast_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/onboarding/welcome_screen.dart';
import '../features/regular/regular_new_screen.dart';
import '../features/regular/regular_payments_screen.dart';
import '../features/settings/accounts_settings_screen.dart';
import '../features/settings/appearance_settings_screen.dart';
import '../features/settings/categories_settings_screen.dart';
import '../features/settings/category_edit_screen.dart';
import '../features/settings/general_settings_screen.dart';
import '../features/settings/home_settings_screen.dart';
import '../features/settings/income_categories_screen.dart';
import '../features/settings/new_account_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/settings/smart_settings_screen.dart';
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
            routes: [GoRoute(path: Routes.budgets, builder: (_, _) => const BudgetsScreen())],
          ),
          StatefulShellBranch(
            routes: [GoRoute(path: Routes.settings, builder: (_, _) => const SettingsScreen())],
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
        path: '${Routes.budgets}/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) => BudgetEditScreen(categoryId: state.pathParameters['id'] ?? ''),
      ),
      GoRoute(path: Routes.settingsGeneral, builder: (_, _) => const GeneralSettingsScreen()),
      GoRoute(path: Routes.settingsAppearance, builder: (_, _) => const AppearanceSettingsScreen()),
      GoRoute(path: Routes.settingsAccounts, builder: (_, _) => const AccountsSettingsScreen()),
      GoRoute(path: Routes.settingsHome, builder: (_, _) => const HomeSettingsScreen()),
      GoRoute(path: Routes.settingsAccountNew, builder: (_, _) => const NewAccountScreen()),
      GoRoute(path: Routes.settingsCategories, builder: (_, _) => const CategoriesSettingsScreen()),
      GoRoute(
        path: Routes.settingsCategoryNew,
        builder: (_, _) => const CategoryEditScreen.create(kind: CategoryKind.spending),
      ),
      GoRoute(
        path: '${Routes.settingsCategories}/:id/edit',
        builder: (_, state) => CategoryEditScreen(
          categoryId: state.pathParameters['id']!,
          from: CategoryEditFrom.parse(state.uri.queryParameters['from']),
        ),
      ),
      GoRoute(
        path: Routes.settingsIncomeCategories,
        builder: (_, _) => const IncomeCategoriesScreen(),
      ),
      GoRoute(
        path: Routes.settingsIncomeCategoryNew,
        builder: (_, _) => const CategoryEditScreen.create(
          kind: CategoryKind.income,
          from: CategoryEditFrom.income,
        ),
      ),
      GoRoute(
        path: Routes.settingsSmart,
        builder: (_, state) => SmartSettingsScreen(
          openAtReminders: state.uri.queryParameters['section'] == 'reminders',
        ),
      ),
      GoRoute(path: Routes.filters, builder: (_, _) => const FiltersScreen()),
      GoRoute(path: Routes.chooseDates, builder: (_, _) => const ChooseDatesScreen()),
      GoRoute(
        path: '/transactions/:id',
        parentNavigatorKey: rootKey,
        builder: (_, state) => TransactionDetailScreen(id: state.pathParameters['id'] ?? ''),
      ),
    ],
  );
}
