import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/ak_appearance.dart';
import '../data/providers.dart';
import '../data/settings/setting_keys.dart';

/// The Appearance settings that shape the theme, from storage. Widget tests override this
/// with a fixed value so they need no database.
final appearanceProvider = Provider<AkAppearance>((ref) => ref.watch(storedAppearanceProvider));

/// "Category chart" on Appearance, from storage. Pie until the person picks another.
final categoryChartProvider = Provider<CategoryChart>((ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const {};
  return SettingKeys.categoryChart.decode(s[SettingKeys.categoryChart.name]);
});
