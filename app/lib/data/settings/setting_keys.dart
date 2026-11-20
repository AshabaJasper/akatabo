import 'package:material_ui/material_ui.dart' show ThemeMode;

import '../../core/theme/ak_appearance.dart';
import '../db/tables.dart';

/// One row on a Settings page: its storage key, its default and how it is written as text.
///
/// Every setting is read through one of these, so a misspelt key or a wrong type is a
/// compile error, and a damaged stored value falls back to the default.
sealed class SettingKey<T> {
  const SettingKey(this.name, this.defaultValue);
  final String name;
  final T defaultValue;

  String encode(T value);

  /// The stored text as a value, or the default when it cannot be read.
  T decode(String? raw);
}

final class BoolSetting extends SettingKey<bool> {
  const BoolSetting(super.name, super.defaultValue);
  @override
  String encode(bool value) => value ? '1' : '0';
  @override
  bool decode(String? raw) => raw == null ? defaultValue : raw == '1';
}

final class IntSetting extends SettingKey<int> {
  const IntSetting(super.name, super.defaultValue, {this.min, this.max});
  final int? min;
  final int? max;
  @override
  String encode(int value) => '$value';
  @override
  int decode(String? raw) {
    final v = int.tryParse(raw ?? '');
    if (v == null || (min != null && v < min!) || (max != null && v > max!)) {
      return defaultValue;
    }
    return v;
  }
}

final class StringSetting extends SettingKey<String> {
  const StringSetting(super.name, super.defaultValue);
  @override
  String encode(String value) => value;
  @override
  String decode(String? raw) => raw ?? defaultValue;
}

final class EnumSetting<T extends Enum> extends SettingKey<T> {
  const EnumSetting(super.name, super.defaultValue, this.values);
  final List<T> values;
  @override
  String encode(T value) => value.name;
  @override
  T decode(String? raw) => values.firstWhere((v) => v.name == raw, orElse: () => defaultValue);
}

/// "How often it points them out" on Smart help: how readily a payment is called unusual.
enum UnusualHowOften { rarely, balanced, often }

/// "Category chart" on Appearance: how the Categories screen shows the month's split.
/// Pie draws the donut beside the reading (as Categories.html), Bars puts a share bar in
/// each row, List only shows the rows alone.
enum CategoryChart { pie, bars, listOnly }

/// Every setting. Defaults are what the drawn Settings pages show.
abstract final class SettingKeys {
  // Appearance
  static const theme = EnumSetting('appearance.theme', ThemeMode.system, ThemeMode.values);

  /// An `AkPalette.id`. An id that is no longer offered reads as green (see `paletteById`).
  static const mainColour = StringSetting('appearance.mainColour', 'green');
  static const categoryChart = EnumSetting(
    'appearance.categoryChart',
    CategoryChart.pie,
    CategoryChart.values,
  );
  static const corners = EnumSetting('appearance.corners', AkCorners.rounded, AkCorners.values);
  static const textSize = EnumSetting(
    'appearance.textSize',
    AkTextSize.standard,
    AkTextSize.values,
  );

  // General
  static const monthStartsOn = IntSetting('general.monthStartsOn', 1, min: 1, max: 28);

  /// [DateTime.monday] (1) to [DateTime.sunday] (7). Drawn as Sunday.
  static const weekStartsOn = IntSetting('general.weekStartsOn', DateTime.sunday, min: 1, max: 7);
  static const newEntryDirection = EnumSetting(
    'general.newEntryDirection',
    Direction.moneyOut,
    Direction.values,
  );

  // Home screen: which sections show. The header figures, "Where it went" and "Latest".
  static const homeShowHeaderTiles = BoolSetting('home.showHeaderTiles', true);
  static const homeShowWhereItWent = BoolSetting('home.showWhereItWent', true);
  static const homeShowLatest = BoolSetting('home.showLatest', true);

  // Smart help
  /// When "Forget everything it has learned" was last used, in milliseconds since the epoch.
  /// Corrections before this time are ignored. 0 means never.
  static const learningResetAt = IntSetting('smart.learningResetAt', 0, min: 0);
  static const suggestCategory = BoolSetting('smart.suggestCategory', true);
  static const forecastMonth = BoolSetting('smart.forecastMonth', true);
  static const pointOutUnusual = BoolSetting('smart.pointOutUnusual', true);
  static const unusualHowOften = EnumSetting(
    'smart.unusualHowOften',
    UnusualHowOften.balanced,
    UnusualHowOften.values,
  );
  static const noticeRegular = BoolSetting('smart.noticeRegular', true);

  // Reminders
  /// Reminder switches start off: notification permission is asked only when one is switched on.
  static const dailyReminder = BoolSetting('reminders.daily', false);

  /// Minutes after midnight, local time. 20:00 as drawn.
  static const dailyReminderAt = IntSetting('reminders.dailyAt', 20 * 60, min: 0, max: 24 * 60 - 1);

  /// A notification when an entry takes a budget past its own warn level (set on Set a
  /// budget), and again when it goes over. The level lives on each budget, not here.
  static const budgetWarn = BoolSetting('reminders.budgetWarn', false);
  static const regularReminder = BoolSetting('reminders.regular', false);
  static const weeklySummary = BoolSetting('reminders.weekly', false);

  /// [DateTime.monday] (1) to [DateTime.sunday] (7). Sent in the evening; drawn as Sunday.
  static const weeklySummaryDay = IntSetting(
    'reminders.weeklyDay',
    DateTime.sunday,
    min: 1,
    max: 7,
  );

  // First run
  static const onboardingDone = BoolSetting('app.onboardingDone', false);
}
