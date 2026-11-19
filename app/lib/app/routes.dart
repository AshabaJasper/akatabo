/// Route paths. Screens navigate by these names, never by string literals.
abstract final class Routes {
  static const home = '/home';
  static const insights = '/insights';
  static const budgets = '/budgets';
  static String budget(String id) => '$budgets/$id';
  static const settings = '/settings';
  static const settingsGeneral = '/settings/general';
  static const settingsAppearance = '/settings/appearance';
  static const settingsAccounts = '/settings/accounts';
  static const settingsHome = '/settings/home';

  /// First launch: three short steps, then Welcome. Outside the tabs.
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';

  /// Add a transaction. Sits on the root navigator, above the tabs.
  static const add = '/add';

  /// Every transaction, newest first. Pushed over the tabs.
  static const transactions = '/transactions';

  /// One day's transactions, opened from Calendar. [day] is yyyymmdd.
  static String transactionsOn(int day) => '$transactions?day=$day';

  /// Every transaction, opened from Calendar's "List": its back link and Calendar button
  /// return to that Calendar instead of opening another.
  static const transactionsFromCalendar = '$transactions?from=calendar';

  /// Categories with this month's shares, and one category's page.
  static const categories = '/categories';
  static String category(String id) => '$categories/$id';

  /// Fees and tax this month, split three ways.
  static const fees = '/fees';

  /// The month-end forecast and how it adds up.
  static const forecast = '/forecast';

  /// Regular payments still due, and adding one by hand.
  static const regular = '/regular';
  static const regularNew = '/regular/new';

  /// One transaction, by id.
  static String transaction(String id) => '/transactions/$id';

  /// Calendar: money out by day, week, month, quarter and year. Pushed over the tabs.
  static const calendar = '/calendar';

  /// Calendar opened from All transactions, so its back link and List button return there.
  static const calendarFromList = '$calendar?from=list';
}
