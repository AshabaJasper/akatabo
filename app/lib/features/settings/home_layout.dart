import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';

/// Which sections of Home show. Read from storage, so the Home screen redraws when a switch
/// changes. Until the stored settings arrive, every section shows.
class HomeLayout {
  const HomeLayout({required this.headerTiles, required this.whereItWent, required this.latest});

  /// The "Money in" and "Fees and tax" figures under the header total.
  final bool headerTiles;
  final bool whereItWent;
  final bool latest;
}

final homeLayoutProvider = Provider<HomeLayout>((ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
  return HomeLayout(
    headerTiles: SettingKeys.homeShowHeaderTiles.decode(s[SettingKeys.homeShowHeaderTiles.name]),
    whereItWent: SettingKeys.homeShowWhereItWent.decode(s[SettingKeys.homeShowWhereItWent.name]),
    latest: SettingKeys.homeShowLatest.decode(s[SettingKeys.homeShowLatest.name]),
  );
});
