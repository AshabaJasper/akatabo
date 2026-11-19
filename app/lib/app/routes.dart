/// Route paths. Screens navigate by these names, never by string literals.
abstract final class Routes {
  static const home = '/home';
  static const insights = '/insights';
  static const budgets = '/budgets';
  static const settings = '/settings';

  /// Add a transaction. Sits on the root navigator, above the tabs.
  static const add = '/add';
}
