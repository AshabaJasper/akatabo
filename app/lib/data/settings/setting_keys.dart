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

/// Every setting. Defaults are what the drawn Settings pages show.
abstract final class SettingKeys {
  // Appearance
  static const theme = EnumSetting('appearance.theme', ThemeMode.system, ThemeMode.values);
  static const mainColour = StringSetting('appearance.mainColour', 'green');
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

  // First run
  static const onboardingDone = BoolSetting('app.onboardingDone', false);
}
