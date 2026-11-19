import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../domain/income.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../insights/insights_text.dart';
import 'income_categories_providers.dart';

/// The short line under a money-in category: how many payments came in under it this month.
///
/// The drawn "Regular, around the 28th" is not used: regular payments are entered by hand as
/// bills, and nothing yet detects regular money in, so the count is the honest line.
String incomeCountLine(IncomeLine line) {
  final count = switch (line.payments) {
    0 => 'Nothing this month',
    1 => '1 payment this month',
    final n => '$n payments this month',
  };
  return line.category.hidden ? '$count, hidden on Add' : count;
}

/// "Salary, business, gifts": the first word of the first three money-in categories, for the
/// link row on Settings > Categories.
String incomeCategoryWords(Iterable<Category> categories) {
  final words = [
    for (final c in categories.where((c) => c.kind == CategoryKind.income && !c.isSystem).take(3))
      c.name.trim().split(' ').first,
  ];
  if (words.isEmpty) return 'None yet';
  return [words.first, for (final w in words.skip(1)) w.toLowerCase()].join(', ');
}

/// Money-in categories: where money comes from, what came in under each this month, and a
/// way to add another. "This month" follows "Month starts on".
class IncomeCategoriesScreen extends ConsumerWidget {
  const IncomeCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final summary = ref.watch(incomeSummaryProvider);
    final days = ref.watch(incomeDaysProvider);
    final range = rangeText(days.start, dateOnly(ref.watch(appNowProvider)));

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s4),
                children: [
                  AkBackLink('Categories', onTap: () => closeScreen(context)),
                  const SizedBox(height: AkSpace.s1),
                  Semantics(
                    header: true,
                    child: Text('Money-in categories', style: t.displayLg.copyWith(color: c.ink)),
                  ),
                  const SizedBox(height: AkSpace.s2),
                  Text(
                    'Where your money comes from. These show when you add money in, and in '
                    'cash flow on Insights.',
                    style: t.bodySm.copyWith(color: c.inkMuted),
                  ),
                  const SizedBox(height: AkSpace.s3h),
                  ...switch (summary) {
                    AsyncError() => const [
                      AkEmptyNote(
                        'Money-in categories could not load. Close Akatabo and open it again.',
                      ),
                    ],
                    AsyncData(:final value) => _body(context, value, range),
                    _ => const <Widget>[],
                  },
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(AkSpace.s6, 0, AkSpace.s6, AkSpace.s6),
              child: AkPrimaryButton(
                label: 'New money-in category',
                onPressed: () => context.push(Routes.settingsIncomeCategoryNew),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context, IncomeSummary s, String range) {
    final c = context.colors;
    final t = context.type;
    if (s.lines.isEmpty) {
      return const [AkEmptyNote('No money-in categories yet. Add one with the button below.')];
    }
    return [
      AkCard(
        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h),
        child: Column(
          children: [
            for (final (i, line) in s.lines.indexed)
              _IncomeRow(
                line: line,
                divider: i < s.lines.length - 1,
                onTap: () => context.push(Routes.categoryEdit(line.category.id)),
              ),
          ],
        ),
      ),
      const SizedBox(height: AkSpace.s3h),
      if (s.total == 0)
        AkEmptyNote('Nothing has come in from $range yet. Money in that you add is counted here.')
      else
        Semantics(
          container: true,
          excludeSemantics: true,
          label: 'Money in, $range: ${formatUgx(s.total)}',
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text('Money in, $range', style: t.bodyStrong.copyWith(color: c.ink)),
                ),
                const SizedBox(width: AkSpace.s3),
                Text(
                  formatSigned(s.total, moneyIn: true),
                  style: t.figure.copyWith(color: c.moneyIn),
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _IncomeRow extends StatelessWidget {
  const _IncomeRow({required this.line, required this.divider, required this.onTap});

  final IncomeLine line;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final cat = line.category;
    final colour = colourForToken(c, cat.colourToken);
    final tileInk = ThemeData.estimateBrightnessForColor(colour) == Brightness.light
        ? c.ink
        : c.onBrand;
    final subtitle = incomeCountLine(line);
    final hasMoney = line.amount > 0;
    final spoken = hasMoney ? '${formatUgx(line.amount)} in' : 'nothing in';
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${cat.name}, $subtitle, $spoken',
      onTap: onTap,
      child: AkListRow(
        leading: AkIconTile(
          icon: AkIcons.fromKey(cat.iconKey),
          background: colour,
          foreground: tileInk,
        ),
        title: cat.name,
        subtitle: subtitle,
        divider: divider,
        onTap: onTap,
        trailing: Text(
          hasMoney ? formatSigned(line.amount, moneyIn: true) : formatAmount(0),
          style: t.figure.copyWith(color: hasMoney ? c.moneyIn : c.inkMuted),
        ),
      ),
    );
  }
}
