import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../smart/unusual/unusual_detector.dart';
import '../regular/day_number.dart';
import 'transactions_providers.dart';

/// The constants and thresholds from the bundled artefact. The usual amounts and hours
/// come from the person's own entries each time.
final unusualParamsProvider = FutureProvider<UnusualParams>((ref) async {
  final raw = await rootBundle.loadString('assets/smart/unusual_params.json');
  return UnusualParams.fromJson(jsonDecode(raw) as Map<String, Object?>);
});

/// Entries the person answered "This was me" for in this session. The answer is also
/// saved on the entry (`flagDismissed`); this set hides the card at once, before the
/// database write comes back.
class UnusualDismissed extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void dismiss(String id) => state = {...state, id};
}

final unusualDismissedProvider = NotifierProvider<UnusualDismissed, Set<String>>(
  UnusualDismissed.new,
);

/// What the card says about one flagged entry.
class UnusualNote {
  const UnusualNote({
    required this.result,
    required this.categoryEntries,
    required this.hour,
    required this.amount,
  });

  final UnusualResult result;

  /// Earlier money-out entries in the same category: the evidence behind the note.
  final int categoryEntries;
  final int hour;
  final int amount;
}

UnusualEntry _entryOf(Transaction t) => UnusualEntry(
  amount: t.amount,
  categoryId: t.categoryId ?? '',
  hour: t.occurredAt.hour,
  payeeKey: t.payeeKey,
  day: dayNumberOf(t.localDay),
);

bool _before(Transaction a, Transaction b) =>
    a.occurredAt.isBefore(b.occurredAt) ||
    (a.occurredAt == b.occurredAt && a.createdAt.isBefore(b.createdAt));

/// The note for entry [id], or null when it is not unusual, the person switched the
/// feature off, said "This was me" this session, or the data is still loading.
final unusualNoteProvider = Provider.autoDispose.family<UnusualNote?, String>((ref, id) {
  final settings = ref.watch(storedSettingsProvider).value ?? const {};
  if (!SettingKeys.pointOutUnusual.decode(settings[SettingKeys.pointOutUnusual.name])) {
    return null;
  }
  if (ref.watch(unusualDismissedProvider).contains(id)) return null;
  final params = ref.watch(unusualParamsProvider).value;
  final all = ref.watch(allTransactionsProvider).value;
  if (params == null || all == null) return null;

  Transaction? target;
  for (final t in all) {
    if (t.id == id) target = t;
  }
  if (target == null ||
      target.flagDismissed ||
      target.direction != Direction.moneyOut ||
      target.categoryId == null) {
    return null;
  }
  final history = [
    for (final t in all.reversed)
      if (t.direction == Direction.moneyOut && t.categoryId != null && _before(t, target))
        _entryOf(t),
  ];
  final result = scoreUnusual(_entryOf(target), history, params, level: _levelOf(settings));
  if (!result.flagged) return null;
  return UnusualNote(
    result: result,
    categoryEntries: history.where((h) => h.categoryId == target!.categoryId).length,
    hour: target.occurredAt.hour,
    amount: target.amount,
  );
});

UnusualLevel _levelOf(Map<String, String> settings) =>
    switch (SettingKeys.unusualHowOften.decode(settings[SettingKeys.unusualHowOften.name])) {
      UnusualHowOften.rarely => UnusualLevel.rarely,
      UnusualHowOften.balanced => UnusualLevel.balanced,
      UnusualHowOften.often => UnusualLevel.often,
    };

/// Every entry the detector points out now, for the "Only unusual" filter: each money-out
/// entry scored against the entries before it, as the card does, less those answered
/// "This was me". Watched only while that filter is on.
final unusualIdsProvider = Provider.autoDispose<Set<String>>((ref) {
  final settings = ref.watch(storedSettingsProvider).value ?? const {};
  final params = ref.watch(unusualParamsProvider).value;
  final all = ref.watch(allTransactionsProvider).value;
  if (params == null || all == null) return const {};
  final dismissed = ref.watch(unusualDismissedProvider);
  final level = _levelOf(settings);
  final ordered = [
    for (final t in all)
      if (t.direction == Direction.moneyOut && t.categoryId != null) t,
  ]..sort((a, b) => _before(a, b) ? -1 : (_before(b, a) ? 1 : 0));
  final history = <UnusualEntry>[];
  final out = <String>{};
  for (final t in ordered) {
    final entry = _entryOf(t);
    if (!t.flagDismissed &&
        !dismissed.contains(t.id) &&
        scoreUnusual(entry, history, params, level: level).flagged) {
      out.add(t.id);
    }
    history.add(entry);
  }
  return out;
});
