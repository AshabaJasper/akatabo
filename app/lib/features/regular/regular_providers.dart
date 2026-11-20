import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import '../../data/settings/setting_keys.dart';
import '../../smart/regular/regular_detector.dart';
import '../transactions/transactions_providers.dart';
import 'day_number.dart';

// Written by hand: these name drift's generated row class (see add_providers.dart).

final regularPaymentRepositoryProvider = Provider<RegularPaymentRepository>(
  (ref) => RegularPaymentRepository(ref.watch(appDatabaseProvider)),
);

/// The payments the person has not dismissed, soonest first.
final activeRegularProvider = StreamProvider.autoDispose<List<RegularPayment>>(
  (ref) => ref.watch(regularPaymentRepositoryProvider).watchActive(),
);

/// Every saved payment, dismissed ones too, so a payee already handled is not offered again.
final allRegularProvider = StreamProvider.autoDispose<List<RegularPayment>>(
  (ref) => ref.watch(regularPaymentRepositoryProvider).watchAll(),
);

/// The rule's constants from the bundled artefact.
final regularParamsProvider = FutureProvider<RegularParams>((ref) async {
  final raw = await rootBundle.loadString('assets/smart/regular_params.json');
  return RegularParams.fromJson(jsonDecode(raw) as Map<String, Object?>);
});

/// A series Smart help found in the entries that is not on the list yet.
class LooksRegular {
  const LooksRegular({required this.series, required this.label});

  final RegularSeries series;

  /// The words of the latest entry to this payee, as the person typed them.
  final String label;
}

/// Payments that repeat in the entries and are not saved or dismissed yet. Empty when
/// "Notice regular payments" is off or the data is still loading.
final looksRegularProvider = Provider.autoDispose<List<LooksRegular>>((ref) {
  final settings = ref.watch(storedSettingsProvider).value ?? const {};
  if (!SettingKeys.noticeRegular.decode(settings[SettingKeys.noticeRegular.name])) {
    return const [];
  }
  final params = ref.watch(regularParamsProvider).value;
  final all = ref.watch(allTransactionsProvider).value;
  final saved = ref.watch(allRegularProvider).value;
  if (params == null || all == null || saved == null) return const [];

  final savedKeys = {
    for (final r in saved)
      if (r.payeeKey.isNotEmpty) r.payeeKey,
  };
  final latestWords = <String, String>{};
  final payments = <PaidEntry>[];
  // Newest first, so the first words seen for a payee are the latest.
  for (final t in all) {
    final categoryId = t.categoryId;
    if (t.direction != Direction.moneyOut || categoryId == null) continue;
    latestWords.putIfAbsent(t.payeeKey, () => t.description);
    payments.add(
      PaidEntry(
        amount: t.amount,
        categoryId: categoryId,
        payeeKey: t.payeeKey,
        day: dayNumberOf(t.localDay),
      ),
    );
  }
  final today = dayNumberOf(toLocalDay(ref.watch(appNowProvider)));
  return [
    for (final s in detectRegular(payments, today, params))
      if (!savedKeys.contains(s.payeeKey) && !saved.any((r) => looksLikeSaved(s, r)))
        LooksRegular(series: s, label: latestWords[s.payeeKey] ?? s.payeeKey),
  ];
});

/// True when [saved] is probably the same bill as [s] under another name: a payment added
/// by hand is named by the person, so its key may not match the entries' words. Same
/// category, an amount inside the series' band (10% either side) and an interval within a
/// fifth of the series' interval.
bool looksLikeSaved(RegularSeries s, RegularPayment saved) =>
    saved.categoryId == s.categoryId &&
    saved.typicalAmount >= s.amountLow * 0.9 &&
    saved.typicalAmount <= s.amountHigh * 1.1 &&
    (saved.intervalDays - s.intervalDays).abs() <= s.intervalDays / 5;
