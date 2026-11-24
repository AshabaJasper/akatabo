import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../domain/goals.dart';

/// Where a goal stands, in the words the screens use. Pure Dart: the screens only show it.
enum GoalStanding {
  /// The saved amount has met the target.
  reached,

  /// At the pace the person has kept, the date is met.
  onPace,

  /// At the pace kept so far, the date is missed.
  behind,

  /// Not enough history yet to judge the pace.
  tooEarly,

  /// No date set, so there is no pace to judge.
  noDate,
}

/// One goal, worked out from its moves: what is saved, how far along, what it takes each week
/// and when the pace reaches it. Every figure the goal screens show comes from here.
class GoalSummary {
  const GoalSummary({
    required this.target,
    required this.saved,
    required this.progress,
    required this.weekly,
    required this.projection,
    required this.standing,
    required this.milestoneDays,
    this.datePassed = false,
  });

  final int target;

  /// Money set aside, never below zero.
  final int saved;

  /// Fraction of the target reached, between 0 and 1.
  final double progress;

  /// Put aside each week to reach the date, rounded up to 100. Null with no date; zero once
  /// reached.
  final int? weekly;

  /// The reach date at the pace kept, or null while the history is too thin.
  final GoalProjection? projection;

  final GoalStanding standing;

  /// For each milestone (25, 50, 75, 100) the first crossed, the local day it was crossed.
  final Map<int, int> milestoneDays;

  /// The target date is before today and the goal is not reached, so a weekly amount "to
  /// reach it by" that date would point at a day already gone.
  final bool datePassed;

  int get remaining => target - saved > 0 ? target - saved : 0;
}

/// Works out a goal's summary from its [moves] as of [today].
GoalSummary summariseGoal({
  required Goal goal,
  required List<GoalMove> moves,
  required DateTime today,
}) {
  final entries = [for (final m in moves) GoalMoveEntry(amount: m.amount, localDay: m.localDay)];
  final raw = savedOf(entries);
  final saved = raw < 0 ? 0 : raw;
  final reached = saved >= goal.target;
  final weekly = reached
      ? 0
      : requiredPer(
          target: goal.target,
          saved: saved,
          targetDay: goal.targetDay,
          today: today,
          periodDays: 7,
        );
  final projection = reached
      ? null
      : projectReach(target: goal.target, saved: saved, moves: entries, today: today);

  final GoalStanding standing;
  if (reached) {
    standing = GoalStanding.reached;
  } else if (weekly == null) {
    standing = GoalStanding.noDate;
  } else if (projection == null) {
    standing = GoalStanding.tooEarly;
  } else {
    standing = projection.weeklyRate >= weekly ? GoalStanding.onPace : GoalStanding.behind;
  }

  return GoalSummary(
    target: goal.target,
    saved: saved,
    progress: progressOf(target: goal.target, saved: saved),
    weekly: weekly,
    projection: projection,
    standing: standing,
    milestoneDays: _milestoneDays(goal.target, moves),
    datePassed: !reached && goal.targetDay != null && goal.targetDay! < toLocalDay(today),
  );
}

/// Replays the moves oldest first, so each milestone keeps the day it was first crossed. A
/// milestone crossed again after money came back out keeps its first day.
Map<int, int> _milestoneDays(int target, List<GoalMove> moves) {
  final ordered = [...moves]..sort((a, b) => a.localDay.compareTo(b.localDay));
  final days = <int, int>{};
  var running = 0;
  for (final m in ordered) {
    final before = running < 0 ? 0 : running;
    running += m.amount;
    final after = running < 0 ? 0 : running;
    for (final milestone in milestonesCrossed(target: target, before: before, after: after)) {
      days.putIfAbsent(milestone, () => m.localDay);
    }
  }
  return days;
}

/// Money set aside per account, from every move: account id to the sum of its moves.
Map<String, int> savedByAccount(Iterable<GoalMove> moves) {
  final totals = <String, int>{};
  for (final m in moves) {
    totals[m.accountId] = (totals[m.accountId] ?? 0) + m.amount;
  }
  return totals;
}
