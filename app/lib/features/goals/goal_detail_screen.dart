import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/goals.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import 'goal_summary.dart';
import 'goal_widgets.dart';
import 'goals_providers.dart';
import 'move_sheet.dart';

/// One goal: what is set aside, the pace to its date, a Smart help estimate with its range,
/// the buttons to put money in or take it out, and its moves with the milestones it passed.
class GoalDetailScreen extends ConsumerWidget {
  const GoalDetailScreen({super.key, required this.goalId});

  final String goalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final today = dateOnly(ref.watch(appNowProvider));
    final goalAsync = ref.watch(goalProvider(goalId));
    final movesAsync = ref.watch(goalMovesProvider(goalId));
    final accountsAsync = ref.watch(allAccountsProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    final ready = goalAsync.hasValue && movesAsync.hasValue && accountsAsync.hasValue;
    final failed = goalAsync.hasError || movesAsync.hasError || accountsAsync.hasError;

    // "Back", not a page name: a goal opens from the Goals tab and from Savings goals.
    Widget frame(Widget body, {Goal? goal}) => Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, 0),
              child: Row(
                children: [
                  Expanded(child: AkBackLink('Back', onTap: () => closeScreen(context))),
                  if (goal != null)
                    Semantics(
                      button: true,
                      label: 'Edit ${goal.name}',
                      excludeSemantics: true,
                      onTap: () => context.push(Routes.goalEdit(goal.id)),
                      child: AkTextLink(
                        'Edit',
                        onTap: () => context.push(Routes.goalEdit(goal.id)),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: body),
          ],
        ),
      ),
    );

    if (failed) {
      return frame(
        const Padding(
          padding: EdgeInsets.all(AkSpace.s6),
          child: AkEmptyNote('This goal could not be loaded. Go back and try again.'),
        ),
      );
    }
    if (!ready) return frame(const SizedBox.shrink());

    final goal = goalAsync.value;
    if (goal == null) {
      return frame(
        const Padding(
          padding: EdgeInsets.all(AkSpace.s6),
          child: AkEmptyNote('This goal is no longer here. It may have been deleted.'),
        ),
      );
    }

    final moves = movesAsync.value!;
    final accounts = accountsAsync.value!;
    final names = {for (final a in accounts) a.id: a.name};
    final summary = summariseGoal(goal: goal, moves: moves, today: today);
    final projection = summary.projection;
    final reached = summary.standing == GoalStanding.reached;
    final archived = goal.archivedAt != null;

    return frame(
      goal: goal,
      ListView(
        padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s3, AkSpace.s6, AkSpace.s6),
        children: [
          _Block(goal: goal, summary: summary, hidden: hidden),
          const SizedBox(height: AkSpace.s3),
          if (archived) ...[
            AkCard(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Archived. Its money stays set aside until you take it out.',
                      style: context.type.body.copyWith(color: c.ink),
                    ),
                  ),
                  const SizedBox(width: AkSpace.s2),
                  AkTextLink('Unarchive', onTap: () => _unarchive(context, ref, goal.id)),
                ],
              ),
            ),
            const SizedBox(height: AkSpace.s3),
          ],
          _PaceCard(goal: goal, summary: summary, hidden: hidden),
          if (projection != null && !reached) ...[
            const SizedBox(height: AkSpace.s3),
            _SmartHelpCard(projection: projection),
          ],
          const SizedBox(height: AkSpace.s3),
          Row(
            children: [
              Expanded(
                child: AkPrimaryButton(
                  label: 'Add to goal',
                  onPressed: reached || archived
                      ? null
                      : () => _move(context, ref, goal: goal, moves: moves, add: true),
                ),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: AkOutlineButton(
                  label: 'Take out',
                  onPressed: summary.saved > 0
                      ? () => _move(context, ref, goal: goal, moves: moves, add: false)
                      : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          _MovesCard(summary: summary, moves: moves, names: names, hidden: hidden),
          const SizedBox(height: AkSpace.s3),
          if (reached) AkPrimaryButton(label: 'Use it', onPressed: () => context.push(Routes.add)),
        ],
      ),
    );
  }

  Future<void> _unarchive(BuildContext context, WidgetRef ref, String id) async {
    try {
      await ref.read(goalRepositoryProvider).unarchive(id);
    } on Object {
      if (context.mounted) showAkMessage(context, 'The goal could not be restored. Try again.');
    }
  }

  Future<void> _move(
    BuildContext context,
    WidgetRef ref, {
    required Goal goal,
    required List<GoalMove> moves,
    required bool add,
  }) async {
    final crossed = await showGoalMoveSheet(context, goal: goal, moves: moves, add: add);
    if (crossed == null || !context.mounted) return;
    if (crossed.isNotEmpty) {
      showAkMessage(context, milestoneName(crossed.last));
    }
  }
}

/// The brand block: the name, the saved figure, the bar and the one figure to notice.
class _Block extends StatelessWidget {
  const _Block({required this.goal, required this.summary, required this.hidden});

  final Goal goal;
  final GoalSummary summary;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final percent = (summary.progress * 100).round();
    return Container(
      padding: const EdgeInsets.all(AkSpace.s4),
      decoration: BoxDecoration(
        color: c.brandDeep,
        borderRadius: BorderRadius.circular(context.metrics.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(goal.name, style: t.displaySm.copyWith(color: c.onBrand)),
          const SizedBox(height: AkSpace.s2),
          AkHiddenAmount(formatUgx(summary.saved), style: t.figureXl.copyWith(color: c.onBrand)),
          const SizedBox(height: AkSpace.s1),
          Text(
            'saved of ${shownUgx(summary.target, hidden: hidden)}. '
            '${shownUgx(summary.remaining, hidden: hidden)} to go.',
            style: t.caption.copyWith(color: c.onBrandMuted),
          ),
          const SizedBox(height: AkSpace.s3),
          GoalBar(
            progress: summary.progress,
            label: '${goal.name}, $percent percent saved',
            fill: c.onBrand,
            track: c.brandRaised,
            tick: c.onBrandMuted,
            height: 12,
          ),
          const SizedBox(height: AkSpace.s2),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '$percent%',
                  style: t.headlineSm.copyWith(color: c.accent),
                ),
                TextSpan(
                  text: ' saved',
                  style: t.caption.copyWith(color: c.onBrandMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The pace to the date, in words, with the evidence it comes from.
class _PaceCard extends StatelessWidget {
  const _PaceCard({required this.goal, required this.summary, required this.hidden});

  final Goal goal;
  final GoalSummary summary;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final projection = summary.projection;
    final lines = <String>[];
    switch (summary.standing) {
      case GoalStanding.reached:
        lines.add('Reached on ${dayText(summary.milestoneDays[100]!)}.');
      case GoalStanding.noDate:
        lines.add('Add a date to see what it takes each week.');
      case _ when summary.datePassed:
        lines.add(
          'The date passed on ${dayText(goal.targetDay!)}. '
          '${shownUgx(summary.remaining, hidden: hidden)} to go.',
        );
        lines.add('Pick a new date to see what it takes each week.');
      case GoalStanding.tooEarly:
        lines.add(
          '${shownUgx(summary.weekly!, hidden: hidden)} a week to reach it by '
          '${dayText(goal.targetDay!)}.',
        );
        lines.add('Too early to tell. Add a few times first.');
      case GoalStanding.onPace || GoalStanding.behind:
        lines.add(
          '${shownUgx(summary.weekly!, hidden: hidden)} a week to reach it by '
          '${dayText(goal.targetDay!)}.',
        );
        if (projection != null) {
          lines.add(
            'You have added about ${shownUgx(projection.weeklyRate, hidden: hidden)} a week '
            'over the last ${weeksText(projection.windowWeeks)}.',
          );
        }
    }
    return AkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Pace', style: t.title.copyWith(color: c.ink)),
              ),
              GoalStandingChip(standing: summary.standing),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          for (final (i, line) in lines.indexed)
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : AkSpace.s1),
              child: Text(
                line,
                style: i == 0
                    ? t.bodyStrong.copyWith(color: c.ink)
                    : t.caption.copyWith(color: c.inkMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// Smart help: the likely reach date and its range, from the person's own saving pattern.
class _SmartHelpCard extends StatelessWidget {
  const _SmartHelpCard({required this.projection});

  final GoalProjection projection;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final late = projection.late;
    return AkCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AkIconTile(icon: AkIcons.chip, background: c.surfaceSunk, foreground: c.brand),
              const SizedBox(width: AkSpace.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Smart help', style: t.bodyStrong),
                    Text(
                      'An estimate from your own additions',
                      style: t.caption.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Text(
            'Likely around ${dayText(toLocalDay(projection.point))}.',
            style: t.bodyStrong.copyWith(color: c.ink),
          ),
          const SizedBox(height: AkSpace.s1),
          Text(
            late == null
                ? 'Range from ${dayText(toLocalDay(projection.early))}. The weakest weeks put nothing aside, so there is no end to the range yet.'
                : 'Range ${dayText(toLocalDay(projection.early))} to ${dayText(toLocalDay(late))}, based on ${weeksText(projection.windowWeeks)} of additions.',
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ],
      ),
    );
  }
}

/// How many rows the moves list shows before "Show all".
const _movesShown = 12;

/// The moves and the milestones, newest first, in one list. A long history shows the newest
/// [_movesShown] rows, with "Show all" for the rest.
class _MovesCard extends StatefulWidget {
  const _MovesCard({
    required this.summary,
    required this.moves,
    required this.names,
    required this.hidden,
  });

  final GoalSummary summary;
  final List<GoalMove> moves;
  final Map<String, String> names;
  final bool hidden;

  @override
  State<_MovesCard> createState() => _MovesCardState();
}

class _MovesCardState extends State<_MovesCard> {
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final summary = widget.summary;
    final names = widget.names;
    final c = context.colors;
    final t = context.type;
    final rows = <({int day, Widget row})>[
      for (final m in widget.moves)
        (
          day: m.localDay,
          row: _MoveRow(name: names[m.accountId] ?? 'Account', move: m, hidden: widget.hidden),
        ),
      for (final e in summary.milestoneDays.entries)
        (day: e.value, row: _MilestoneRow(percent: e.key, day: e.value)),
    ]..sort((a, b) => b.day.compareTo(a.day));

    return AkCard(
      padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s4, AkSpace.s4, AkSpace.s2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Moves', style: t.title.copyWith(color: c.ink)),
          const SizedBox(height: AkSpace.s2),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AkSpace.s2),
              child: Text(
                'Nothing set aside yet. Add to this goal to start.',
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            )
          else ...[
            for (final r in _all ? rows : rows.take(_movesShown)) r.row,
            if (rows.length > _movesShown)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
                child: AkTextLink(
                  _all ? 'Show fewer' : 'Show all ${rows.length}',
                  onTap: () => setState(() => _all = !_all),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _MoveRow extends StatelessWidget {
  const _MoveRow({required this.name, required this.move, required this.hidden});

  final String name;
  final GoalMove move;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final adding = move.amount > 0;
    final note = move.note;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
      child: Row(
        children: [
          AkIconTile(
            icon: adding ? AkIcons.wallet : AkIcons.received,
            background: c.surfaceSunk,
            foreground: c.brand,
          ),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  adding ? 'Set aside from $name' : 'Taken out to $name',
                  style: t.body.copyWith(color: c.ink),
                ),
                Text(
                  note == null || note.isEmpty
                      ? dayText(move.localDay)
                      : '${dayText(move.localDay)}, $note',
                  style: t.caption.copyWith(color: c.inkMuted),
                ),
              ],
            ),
          ),
          Text(
            hidden ? hiddenFigure : formatSigned(move.amount.abs(), moneyIn: adding),
            style: t.bodyStrong.copyWith(color: c.ink),
          ),
        ],
      ),
    );
  }
}

class _MilestoneRow extends StatelessWidget {
  const _MilestoneRow({required this.percent, required this.day});

  final int percent;
  final int day;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
      child: Row(
        children: [
          AkIconTile(icon: AkIcons.check, background: c.surfaceSunk, foreground: c.brand),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(milestoneName(percent), style: t.body.copyWith(color: c.ink)),
                Text(dayText(day), style: t.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
