import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';

/// Which sections of Home show. Read from storage, so the Home screen redraws when a switch
/// changes. Until the stored settings arrive, each section takes its default.
class HomeLayout {
  const HomeLayout({
    required this.headerTiles,
    required this.forecast,
    required this.whereItWent,
    required this.latest,
    required this.budgets,
  });

  /// "Money in", "Left in budgets" and "Fees and tax" under the header total.
  final bool headerTiles;

  /// The forecast card. It still waits for "Forecast the month" and a week of entries.
  final bool forecast;
  final bool whereItWent;
  final bool latest;

  /// Budgets at a glance: the three most used budgets.
  final bool budgets;
}

final homeLayoutProvider = Provider<HomeLayout>((ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
  bool read(BoolSetting key) => key.decode(s[key.name]);
  return HomeLayout(
    headerTiles: read(SettingKeys.homeShowHeaderTiles),
    forecast: read(SettingKeys.homeShowForecast),
    whereItWent: read(SettingKeys.homeShowWhereItWent),
    latest: read(SettingKeys.homeShowLatest),
    budgets: read(SettingKeys.homeShowBudgets),
  );
});

/// "The app opens on", from storage. Home until the person picks another.
final opensOnProvider = Provider<AppOpensOn>((ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
  return SettingKeys.opensOn.decode(s[SettingKeys.opensOn.name]);
});
