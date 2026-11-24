import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_surfaces.dart';
import 'goal_summary.dart';
import 'goal_widgets.dart';
import 'goals_providers.dart';

/// How many goals the Goals tab shows before "See all".
const _shown = 3;

/// The Savings half of the Goals tab: what is set aside in total, then the goals being saved
/// toward, reached ones after them. "See all" opens Savings goals; with none yet, "New goal".
/// It loads on its own, so a goal error never hides the budgets below it.
class SavingsSection extends ConsumerWidget {
  const SavingsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final goalsAsync = ref.watch(goalsProvider);
    final movesAsync = ref.watch(allGoalMovesProvider);
    final goals = goalsAsync.value;
    final moves = movesAsync.value;

    final live = [
      for (final g in goals ?? const <Goal>[])
        if (g.archivedAt == null) g,
    ];
    final ready = goals != null && moves != null;

    final Widget body;
    if (goalsAsync.hasError || movesAsync.hasError) {
      body = Text(
        'Savings goals could not load. Close Akatabo and open it again.',
        style: t.bodySm.copyWith(color: c.inkMuted),
      );
    } else if (!ready) {
      body = const SizedBox.shrink();
    } else if (goals.isEmpty) {
      body = Text(
        'No savings goals yet. Set money aside for school fees, a phone or rent, and it '
        'shows here. The money stays in the account it came from.',
        style: t.bodySm.copyWith(color: c.inkMuted),
      );
    } else if (live.isEmpty) {
      // Every goal archived: their money can still be set aside, so the total and the way to
      // it stay, under "See all".
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalRow(total: moves.fold<int>(0, (sum, m) => sum + m.amount)),
          const SizedBox(height: AkSpace.s1),
          Text(
            'All your goals are archived. See all to open them.',
            style: t.bodySm.copyWith(color: c.inkMuted),
          ),
        ],
      );
    } else {
      final movesByGoal = <String, List<GoalMove>>{};
      for (final m in moves) {
        (movesByGoal[m.goalId] ??= []).add(m);
      }
      final summaries = {
        for (final g in live)
          g.id: summariseGoal(goal: g, moves: movesByGoal[g.id] ?? const [], today: today),
      };
      bool isReached(Goal g) => summaries[g.id]!.standing == GoalStanding.reached;
      final ordered = [...live.where((g) => !isReached(g)), ...live.where(isReached)];
      final total = moves.fold<int>(0, (sum, m) => sum + m.amount);
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _TotalRow(total: total),
          const SizedBox(height: AkSpace.s3),
          for (final g in ordered.take(_shown)) ...[
            GoalRow(
              goal: g,
              summary: summaries[g.id]!,
              onTap: () => context.push(Routes.goal(g.id)),
            ),
            const SizedBox(height: AkSpace.s3),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AkSectionTitle(
          'Savings',
          actionLabel: !ready ? null : (goals.isEmpty ? 'New goal' : 'See all'),
          onAction: !ready
              ? null
              : () => context.push(goals.isEmpty ? Routes.goalNew : Routes.goals),
        ),
        const SizedBox(height: AkSpace.s2),
        body,
      ],
    );
  }
}

/// "Set aside in your accounts" and the total, hidden while "Hide amounts" is on.
class _TotalRow extends StatelessWidget {
  const _TotalRow({required this.total});

  final int total;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Row(
      children: [
        Expanded(
          child: Text('Set aside in your accounts', style: t.bodySm.copyWith(color: c.inkMuted)),
        ),
        AkHiddenAmount(formatUgx(total), style: t.figure.copyWith(color: c.ink)),
      ],
    );
  }
}
