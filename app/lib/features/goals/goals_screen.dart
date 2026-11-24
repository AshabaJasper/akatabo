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
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_hidden_amount.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/add_providers.dart';
import 'goal_summary.dart';
import 'goal_widgets.dart';
import 'goals_providers.dart';

/// Savings goals: the total set aside across accounts, then each goal with its pace. Reached
/// goals and archived goals sit below. Reached from Budgets.
class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final goalsAsync = ref.watch(goalsProvider);
    final movesAsync = ref.watch(allGoalMovesProvider);
    final accountsAsync = ref.watch(allAccountsProvider);
    final hidden = ref.watch(amountsHiddenProvider);
    final ready = goalsAsync.hasValue && movesAsync.hasValue && accountsAsync.hasValue;
    final failed = goalsAsync.hasError || movesAsync.hasError || accountsAsync.hasError;

    if (failed) {
      return const _Frame(
        child: AkEmptyNote('Savings goals could not be loaded. Close this and try again.'),
      );
    }
    if (!ready) return const _Frame(child: SizedBox.shrink());

    final goals = goalsAsync.value!;
    final moves = movesAsync.value!;
    final accounts = accountsAsync.value!;

    final movesByGoal = <String, List<GoalMove>>{};
    for (final m in moves) {
      (movesByGoal[m.goalId] ??= []).add(m);
    }
    final summaries = {
      for (final g in goals)
        g.id: summariseGoal(goal: g, moves: movesByGoal[g.id] ?? const [], today: today),
    };

    final total = moves.fold<int>(0, (sum, m) => sum + m.amount);
    final byAccount = savedByAccount(moves);
    final breakdown = [
      for (final a in accounts)
        if ((byAccount[a.id] ?? 0) > 0)
          '${a.name} ${shownAmount(byAccount[a.id]!, hidden: hidden)}',
    ].join(' · ');

    final archived = [
      for (final g in goals)
        if (g.archivedAt != null) g,
    ];
    final live = [
      for (final g in goals)
        if (g.archivedAt == null) g,
    ];
    final saving = [
      for (final g in live)
        if (summaries[g.id]!.standing != GoalStanding.reached) g,
    ];
    final reached = [
      for (final g in live)
        if (summaries[g.id]!.standing == GoalStanding.reached) g,
    ];

    void open(Goal g) => context.push(Routes.goal(g.id));

    return _Frame(
      action: Semantics(
        button: true,
        label: 'New savings goal',
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: () => context.push(Routes.goalNew),
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: c.surface,
              border: Border.all(color: c.lineStrong),
            ),
            child: AkIcon(AkIcons.plus, size: 20, color: c.brandText),
          ),
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
        children: [
          Text('Savings goals', style: t.displayLg),
          const SizedBox(height: AkSpace.s3),
          _SummaryBlock(total: total, breakdown: breakdown),
          const SizedBox(height: AkSpace.s5),
          if (goals.isEmpty)
            AkEmptyNote(
              'Set money aside for something you want. It stays in the account it came from, '
              'and your balances do not change.',
              actionLabel: 'New goal',
              onAction: () => context.push(Routes.goalNew),
            )
          else ...[
            if (saving.isNotEmpty) ...[
              Text('Saving now', style: t.title.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s2),
              for (final g in saving) ...[
                GoalRow(goal: g, summary: summaries[g.id]!, onTap: () => open(g)),
                const SizedBox(height: AkSpace.s3),
              ],
            ],
            if (reached.isNotEmpty) ...[
              const SizedBox(height: AkSpace.s2),
              Text('Reached', style: t.title.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s2),
              for (final g in reached) ...[
                GoalRow(goal: g, summary: summaries[g.id]!, onTap: () => open(g)),
                const SizedBox(height: AkSpace.s3),
              ],
            ],
            if (archived.isNotEmpty) ...[
              const SizedBox(height: AkSpace.s2),
              AkCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    InkWell(
                      borderRadius: BorderRadius.circular(context.metrics.lg),
                      onTap: () => setState(() => _showArchived = !_showArchived),
                      child: Padding(
                        padding: const EdgeInsets.all(AkSpace.s4),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Archived, ${archived.length} ${archived.length == 1 ? 'goal' : 'goals'}',
                                style: t.bodyStrong,
                              ),
                            ),
                            AkIcon(AkIcons.chevron, size: 18, color: c.inkMuted),
                          ],
                        ),
                      ),
                    ),
                    if (_showArchived)
                      for (final g in archived)
                        InkWell(
                          onTap: () => open(g),
                          child: Padding(
                            padding: const EdgeInsets.all(AkSpace.s4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(g.name, style: t.bodyStrong),
                                Text(
                                  '${shownUgx(summaries[g.id]!.saved, hidden: hidden)} still set aside',
                                  style: t.caption.copyWith(color: c.inkMuted),
                                ),
                              ],
                            ),
                          ),
                        ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// The brand block at the top: what is set aside in total, and where it sits.
class _SummaryBlock extends StatelessWidget {
  const _SummaryBlock({required this.total, required this.breakdown});

  final int total;
  final String breakdown;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(AkSpace.s4),
      decoration: BoxDecoration(
        color: c.brandDeep,
        borderRadius: BorderRadius.circular(context.metrics.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Set aside in your accounts', style: t.bodySm.copyWith(color: c.onBrandMuted)),
          const SizedBox(height: AkSpace.s1),
          AkHiddenAmount(formatUgx(total), style: t.figureXl.copyWith(color: c.onBrand)),
          if (breakdown.isNotEmpty) ...[
            const SizedBox(height: AkSpace.s1),
            Text(breakdown, style: t.caption.copyWith(color: c.onBrandMuted)),
          ],
          const SizedBox(height: AkSpace.s1),
          Text(
            'It stays in these accounts and is still counted in your balances.',
            style: t.caption.copyWith(color: c.onBrandMuted),
          ),
        ],
      ),
    );
  }
}

/// A screen with the back link and an optional action at the top.
class _Frame extends StatelessWidget {
  const _Frame({required this.child, this.action});

  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, 0),
              child: Row(
                children: [
                  Expanded(child: AkBackLink('Goals', onTap: () => closeScreen(context))),
                  ?action,
                ],
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
