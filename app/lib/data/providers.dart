import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../core/theme/ak_appearance.dart';
import '../core/time/period.dart';
import 'db/app_database.dart';
import 'repositories/repositories.dart';
import 'settings/setting_keys.dart';

part 'providers.g.dart';

/// The one database for the app's lifetime. Tests override it with an in-memory one.
@Riverpod(keepAlive: true)
AppDatabase appDatabase(Ref ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
}

@Riverpod(keepAlive: true)
TransactionRepository transactionRepository(Ref ref) =>
    TransactionRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
CategoryRepository categoryRepository(Ref ref) =>
    CategoryRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
AccountRepository accountRepository(Ref ref) => AccountRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
GoalRepository goalRepository(Ref ref) => GoalRepository(ref.watch(appDatabaseProvider));

@Riverpod(keepAlive: true)
SettingsRepository settingsRepository(Ref ref) =>
    SettingsRepository(ref.watch(appDatabaseProvider));

/// Every stored setting, kept current.
@Riverpod(keepAlive: true)
Stream<Map<String, String>> storedSettings(Ref ref) =>
    ref.watch(settingsRepositoryProvider).watchAll();

/// The Appearance settings from storage.
@Riverpod(keepAlive: true)
AkAppearance storedAppearance(Ref ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const {};
  return AkAppearance(
    themeMode: SettingKeys.theme.decode(s[SettingKeys.theme.name]),
    paletteId: SettingKeys.mainColour.decode(s[SettingKeys.mainColour.name]),
    corners: SettingKeys.corners.decode(s[SettingKeys.corners.name]),
    textSize: SettingKeys.textSize.decode(s[SettingKeys.textSize.name]),
    categoryColours: SettingKeys.categoryColours.decode(s[SettingKeys.categoryColours.name]),
    moneyColours: SettingKeys.moneyColours.decode(s[SettingKeys.moneyColours.name]),
  );
}

/// Periods from "Month starts on" and "Week starts on".
@Riverpod(keepAlive: true)
PeriodCalculator periodCalculator(Ref ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const {};
  return PeriodCalculator(
    monthStartsOn: SettingKeys.monthStartsOn.decode(s[SettingKeys.monthStartsOn.name]),
    weekStartsOn: SettingKeys.weekStartsOn.decode(s[SettingKeys.weekStartsOn.name]),
  );
}
