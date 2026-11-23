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
  static const settingsAccountNew = '/settings/accounts/new';
  static const settingsAccountEditPattern = '/settings/accounts/edit/:id';
  static String settingsAccountEdit(String id) => '/settings/accounts/edit/$id';
  static const settingsCategories = '/settings/categories';

  /// Edit a category in its "new" mode, for money out.
  static const settingsCategoryNew = '$settingsCategories/new';

  /// Money-in categories with this month's money in, and adding one (the same "new" mode,
  /// for money in).
  static const settingsIncomeCategories = '$settingsCategories/income';
  static const settingsIncomeCategoryNew = '$settingsIncomeCategories/new';

  /// Smart help and Reminders, one page reached from both hub rows.
  static const settingsSmart = '/settings/smart';

  /// The same page, scrolled to its Reminders section.
  static const settingsReminders = '$settingsSmart?section=reminders';

  /// Privacy and data: app lock, hidden amounts, data and backup, about. One page reached
  /// from both hub rows; the Data and backup row opens it at that section.
  static const settingsPrivacy = '/settings/privacy';

  /// App lock: the lock switch, the PIN, Unlock with and Lock after.
  static const settingsLock = '/settings/lock';
  static const settingsData = '$settingsPrivacy?section=data';

  /// Export and back up, and Restore from a backup. [exportPdf] opens Export on the PDF
  /// report, for the "Export a monthly report" row.
  static const dataExport = '/settings/data';
  static const dataExportPdf = '$dataExport?format=pdf';
  static const dataRestore = '/settings/data/restore';

  /// Filters for All transactions, and Choose dates from inside them.
  static const filters = '/filters';
  static const chooseDates = '/filters/dates';

  /// Edit a category. [from] names the page it was opened from, so its back link can say
  /// where it returns to: `income` (Money-in categories) or `detail` (the category's page).
  /// Left out, it is Settings > Categories.
  static String categoryEdit(String id, {String? from}) =>
      '$settingsCategories/$id/edit${from == null ? '' : '?from=$from'}';

  /// First launch: three short steps, then Welcome. Outside the tabs.
  static const onboarding = '/onboarding';
  static const welcome = '/welcome';

  /// Add a transaction. Sits on the root navigator, above the tabs.
  static const add = '/add';

  /// Add in edit mode for one entry, and Add filled from one ("Add one like this").
  static String addEdit(String id) => '$add?edit=$id';
  static String addLike(String id) => '$add?like=$id';

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
