import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/format/dates.dart';
import '../core/format/money.dart';
import '../data/providers.dart';
import '../data/settings/setting_keys.dart';

export '../core/format/dates.dart' show DateStyle, formatDate;
export '../core/format/money.dart' show AmountStyle, formatHeadline;

/// "Date style" from storage. In words until the person picks another.
final dateStyleProvider = Provider<DateStyle>((ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
  return SettingKeys.dateStyle.decode(s[SettingKeys.dateStyle.name]);
});

/// "How amounts are written" from storage. In full until the person picks another.
final amountStyleProvider = Provider<AmountStyle>((ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
  return SettingKeys.amountStyle.decode(s[SettingKeys.amountStyle.name]);
});
