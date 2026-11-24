import '../core/time/period.dart';
import '../smart/forecast/forecast_range.dart'
    show percentile, forecastPercentileLow, forecastPercentileHigh;

/// Savings goals: how far along a goal is, how much to put aside to reach it, and when at
/// the current pace it would be reached. Pure Dart, so every figure here is testable and the
/// screens only show what these functions return.
///
/// Money is whole shillings. A saved amount is the sum of a goal's moves; a move above zero
/// sets money aside and a move below zero takes it back out.

/// One move as this file needs it: how much, and the local day (yyyymmdd) it happened.
class GoalMoveEntry {
  const GoalMoveEntry({required this.amount, required this.localDay});
  final int amount;
  final int localDay;
}

/// The milestones the progress bar marks, as whole percents of the target.
const goalMilestones = [25, 50, 75, 100];

/// Total saved for a goal: the sum of its moves, which may be lower than zero only if the
/// moves were recorded wrongly, so callers clamp at zero for display.
int savedOf(Iterable<GoalMoveEntry> moves) => moves.fold(0, (sum, m) => sum + m.amount);

/// Fraction of the target reached, between 0 and 1.
double progressOf({required int target, required int saved}) {
  if (target <= 0) return 0;
  final f = saved / target;
  return f < 0 ? 0 : (f > 1 ? 1 : f);
}

/// The milestones a change from [before] to [after] crosses, in order. A milestone counts when
/// the saved amount first reaches it; taking money back out and putting it in again crosses it
/// again, which is why the caller shows the message once per move.
List<int> milestonesCrossed({required int target, required int before, required int after}) {
  if (target <= 0 || after <= before) return const [];
  return [
    for (final m in goalMilestones)
      if (before * 100 < target * m && after * 100 >= target * m) m,
  ];
}

/// Rounds a non-negative amount up to the next 100 shillings. Saving targets round up so a
/// suggested amount always gets there. (The budget allowance rounds down, because it is a limit.)
int roundUpToHundred(int amount) => amount <= 0 ? 0 : (amount + 99) ~/ 100 * 100;

/// How much to put aside each week or month to reach the target by [targetDay], rounded up
/// to 100. Null when there is no date. Zero once the target is reached. With one period or
/// less to go, or the date passed, the whole remainder is due at once.
int? requiredPer({
  required int target,
  required int saved,
  required int? targetDay,
  required DateTime today,
  required int periodDays,
}) {
  if (targetDay == null) return null;
  final remaining = target - saved;
  if (remaining <= 0) return 0;
  final due = fromLocalDay(targetDay);
  final daysLeft = daysBetween(today, due);
  // Inside the last period (or past the date) the whole remainder is due now. Dividing by a
  // fraction of a period would ask for more than is left.
  if (periodDays <= 0 || daysLeft <= periodDays) return roundUpToHundred(remaining);
  // ceil(remaining * periodDays / daysLeft) in integers, so no floating-point error rounds up
  // an extra 100.
  return roundUpToHundred((remaining * periodDays + daysLeft - 1) ~/ daysLeft);
}

/// When the goal would be reached at the pace the person has actually kept, and the range
/// around it. [early] uses the strongest weeks of saving, [late] the weakest; [late] is null
/// when the weakest weeks put nothing aside, because then no date is honest to give.
class GoalProjection {
  const GoalProjection({
    required this.point,
    required this.early,
    required this.late,
    required this.weeklyRate,
  });
  final DateTime point;
  final DateTime early;
  final DateTime? late;

  /// The average put aside a week over the window, rounded to 100.
  final int weeklyRate;
}

/// How many weeks of history the projection looks at.
const goalProjectionWeeks = 8;

/// Fewest adds before a projection is shown. Fewer than this and the pace is a guess.
const goalProjectionMinAdds = 3;

/// Fewest days of history before a projection is shown.
const goalProjectionMinDays = 21;

/// Projects the reach date from the saving pattern in [moves]. Returns null when the history
/// is too thin to say anything (fewer than [goalProjectionMinAdds] adds, or less than
/// [goalProjectionMinDays] days since the first add), so the screen can say "too early to tell"
/// instead of showing a date that looks more certain than it is.
GoalProjection? projectReach({
  required int target,
  required int saved,
  required List<GoalMoveEntry> moves,
  required DateTime today,
}) {
  final remaining = target - saved;
  if (remaining <= 0) return null;

  final adds = moves.where((m) => m.amount > 0).toList();
  if (adds.length < goalProjectionMinAdds) return null;
  final firstAdd = adds.map((m) => m.localDay).reduce((a, b) => a < b ? a : b);
  final historyDays = daysBetween(fromLocalDay(firstAdd), today);
  if (historyDays < goalProjectionMinDays) return null;

  // Net saved in each of the last weeks, oldest first. Week 0 is the seven days up to today.
  // The window starts at the first add, so weeks before the goal existed are not counted as
  // weeks with no saving, which would halve a new saver's pace.
  final windowWeeks = historyDays ~/ 7 + 1 < goalProjectionWeeks
      ? historyDays ~/ 7 + 1
      : goalProjectionWeeks;
  final weeks = List<int>.filled(windowWeeks, 0);
  for (final m in moves) {
    final age = daysBetween(fromLocalDay(m.localDay), today);
    if (age < 0) continue;
    final week = age ~/ 7;
    if (week >= windowWeeks) continue;
    weeks[windowWeeks - 1 - week] += m.amount;
  }
  final sorted = [...weeks]..sort();
  final rateLow = percentile(sorted, forecastPercentileLow);
  final rateHigh = percentile(sorted, forecastPercentileHigh);
  final rateMid = weeks.fold<int>(0, (a, b) => a + b) / windowWeeks;
  // Net nothing put aside (or more taken out than put in): the current pace never gets there.
  if (rateMid <= 0) return null;

  DateTime reach(double rate) {
    final weeksNeeded = remaining / rate;
    return addDays(today, (weeksNeeded * 7).ceil());
  }

  return GoalProjection(
    point: reach(rateMid),
    early: rateHigh > 0 ? reach(rateHigh) : reach(rateMid),
    late: rateLow > 0 ? reach(rateLow) : null,
    weeklyRate: roundUpToHundred(rateMid.round()),
  );
}
