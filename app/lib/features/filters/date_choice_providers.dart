import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/providers.dart';
import '../../domain/date_choice.dart';

/// What the person chose on Choose dates: a preset, or a custom first and last day.
///
/// Only the choice is held, never the dates a preset gives, so "Last 7 days" moves on at
/// midnight and a change to "Month starts on" redraws "This month". Held in memory: it
/// resets to This month when the app opens, and is not saved.
class DateChoice {
  const DateChoice(this.preset) : first = null, last = null;
  DateChoice.custom(DateTime first, DateTime last)
    : preset = DatePreset.custom,
      first = dateOnly(first),
      last = dateOnly(last);

  final DatePreset preset;

  /// The custom range's first and last day, both included. Null for a preset.
  final DateTime? first;
  final DateTime? last;
}

class DateChoiceNotifier extends Notifier<DateChoice> {
  // Watches nothing, so a settings save or midnight never resets the choice.
  @override
  DateChoice build() => const DateChoice(DatePreset.thisMonth);

  /// Chooses a preset; its dates are worked out when read, from today.
  void choosePreset(DatePreset preset) {
    if (preset == DatePreset.custom) {
      throw ArgumentError('Choose a custom range with chooseCustom');
    }
    state = DateChoice(preset);
  }

  /// Chooses the custom range from [first] to [last], both days included.
  void chooseCustom(DateTime first, DateTime last) {
    if (dateOnly(last).isBefore(dateOnly(first))) {
      throw ArgumentError('A range must end on or after its first day: $first to $last');
    }
    state = DateChoice.custom(first, last);
  }
}

final dateChoiceProvider = NotifierProvider<DateChoiceNotifier, DateChoice>(DateChoiceNotifier.new);

/// The days the current choice covers, worked out from today and the period settings.
final chosenPeriodProvider = Provider<Period>((ref) {
  final choice = ref.watch(dateChoiceProvider);
  if (choice.preset == DatePreset.custom) {
    return Period(choice.first!, addDays(choice.last!, 1), PeriodKind.custom);
  }
  return presetPeriod(
    choice.preset,
    ref.watch(appNowProvider),
    ref.watch(periodCalculatorProvider),
  );
});
