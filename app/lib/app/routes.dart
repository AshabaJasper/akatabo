/// Route paths. Screens navigate by these names, never by string literals.
abstract final class Routes {
  static const home = '/home';
  static const insights = '/insights';
  static const budgets = '/budgets';
  static const settings = '/settings';

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

  /// One transaction, by id.
  static String transaction(String id) => '/transactions/$id';

  /// Calendar: money out by day, week, month, quarter and year. Pushed over the tabs.
  static const calendar = '/calendar';

  /// Calendar opened from All transactions, so its back link and List button return there.
  static const calendarFromList = '$calendar?from=list';
}
