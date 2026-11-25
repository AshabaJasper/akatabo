import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/tokens.g.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/budget.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/amount_text.dart';
import '../home/home_providers.dart';
import '../settings/smart_rows.dart';
import 'budgets_providers.dart';

/// The warn levels a person can choose, as whole percents of the budget.
const _warnLevels = [60, 70, 80, 90];

/// Sets, changes or removes one category's monthly budget. Opened from a budget row, or from
/// "Set one" for a category with spending and no budget.
class BudgetEditScreen extends ConsumerWidget {
  const BudgetEditScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final calc = ref.watch(periodCalculatorProvider);
    final month = calc.month(today);
    final catsAsync = ref.watch(allCategoriesProvider);
    final historyAsync = ref.watch(budgetHistoryRowsProvider);
    final ready = catsAsync.hasValue && historyAsync.hasValue;
    final failed = catsAsync.hasError || historyAsync.hasError;

    final category = catsAsync.value?.where((cat) => cat.id == categoryId).firstOrNull;
    final months = previousMonths(calc, month);
    final history = monthlyMoneyOut(
      categoryId: categoryId,
      months: months,
      rows: historyAsync.value ?? const <Transaction>[],
    );

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: failed
            ? ListView(
                padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
                children: [
                  AkBackLink('Goals', onTap: () => closeScreen(context)),
                  const SizedBox(height: AkSpace.s3),
                  const AkEmptyNote('This budget could not load. Close Akatabo and open it again.'),
                ],
              )
            : !ready
            ? ListView(
                padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
                children: [const SizedBox(height: AkSize.chart)],
              )
            : category == null
            ? ListView(
                padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
                children: [const AkEmptyNote('This category is no longer here.')],
              )
            : _BudgetForm(
                key: ValueKey(category.id),
                category: category,
                months: months,
                history: history,
                title: t.titleLg,
              ),
      ),
    );
  }
}

class _BudgetForm extends ConsumerStatefulWidget {
  const _BudgetForm({
    super.key,
    required this.category,
    required this.months,
    required this.history,
    required this.title,
  });

  final Category category;
  final List<Period> months;

  /// Money out for each of [months], oldest first.
  final List<int> history;
  final TextStyle title;

  @override
  ConsumerState<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends ConsumerState<_BudgetForm> {
  late final TextEditingController _amount;
  late bool _carry;
  late int _warnAt;
  String? _problem;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final base = widget.category.monthlyBudget;
    _amount = TextEditingController(text: base == null ? '' : formatAmount(base));
    _carry = widget.category.budgetCarriesOver;
    _warnAt = _warnLevels.contains(widget.category.budgetWarnAt)
        ? widget.category.budgetWarnAt
        : 80;
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// The typed amount, or zero when it is empty or not a number.
  int get _typed => parseAmount(_amount.text);

  /// The suggestion needs three months with spending. Months with none count as zero, so a
  /// category used only lately is not suggested from empty history.
  int? get _suggestion {
    final active = widget.history.where((m) => m > 0).length;
    if (active < suggestionMinMonths) return null;
    return suggestedBudget(widget.history);
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = _typed;
    if (amount <= 0) {
      setState(() => _problem = 'Enter an amount above zero.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref
          .read(categoryRepositoryProvider)
          .setBudget(
            widget.category.id,
            monthlyBudget: amount,
            carriesOver: _carry,
            warnAt: _warnAt,
          );
      if (mounted) await closeScreen(context);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _problem = 'The budget could not be saved. Try again.';
      });
    }
  }

  Future<void> _confirmRemove() async {
    final name = widget.category.name;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove the $name budget?'),
        content: const Text('Its spending stays in your entries and totals. Only the budget goes.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (yes != true || !mounted) return;
    try {
      await ref
          .read(categoryRepositoryProvider)
          .setBudget(widget.category.id, monthlyBudget: null, carriesOver: false, warnAt: 80);
      if (mounted) await closeScreen(context);
    } on Object {
      if (!mounted) return;
      setState(() => _problem = 'The budget could not be removed. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final name = widget.category.name;
    final suggestion = _suggestion;
    final hasBudget = widget.category.monthlyBudget != null;
    final compare = _typed > 0 ? _typed : (suggestion ?? 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
      children: [
        AkBackLink('Goals', onTap: () => closeScreen(context)),
        const SizedBox(height: AkSpace.s3),
        Semantics(
          header: true,
          child: Text('$name budget', style: widget.title.copyWith(color: c.ink)),
        ),
        const SizedBox(height: AkSpace.s5),
        AkTextField(
          label: 'Each month, UGX',
          controller: _amount,
          keyboardType: TextInputType.number,
          figures: true,
          inputFormatters: const [ThousandsFormatter()],
          hint: '200,000',
          onChanged: (_) => setState(() => _problem = null),
        ),
        const SizedBox(height: AkSpace.s3),
        if (suggestion != null) ...[
          Wrap(
            spacing: AkSpace.s2,
            runSpacing: AkSpace.s2,
            children: [
              AkChip(
                label: '${formatAmount(suggestion)} suggested',
                selected: _typed == suggestion,
                onTap: () => setState(() {
                  _amount.text = formatAmount(suggestion);
                  _problem = null;
                }),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s2),
          Text(_sentence(compare, suggestion), style: t.bodySm.copyWith(color: c.inkMuted)),
        ] else
          AkEmptyNote('A suggestion appears after three months with spending in $name.'),
        const SizedBox(height: AkSpace.s5),
        const AkEyebrow('Your last 6 months'),
        const SizedBox(height: AkSpace.s2),
        _HistoryBars(
          values: widget.history,
          labels: [for (final m in widget.months) DateFormat('MMM').format(m.start)],
          limit: compare,
          colours: (brand: c.brand, over: c.moneyOut, line: c.ink),
        ),
        const SizedBox(height: AkSpace.s5),
        // As drawn: label and note on the left, the switch at the row's end, on a card.
        AkCard(
          padding: EdgeInsets.zero,
          child: NotedSwitchRow(
            label: 'Carry over what is left',
            note: 'Unspent money adds to next month',
            value: _carry,
            onChanged: (v) => setState(() => _carry = v),
            divider: false,
          ),
        ),
        const SizedBox(height: AkSpace.s5),
        const AkEyebrowLabel('Warn me at'),
        const SizedBox(height: AkSpace.s2),
        AkSegmented<int>(
          semanticLabel: 'Warn me at',
          selected: _warnAt,
          onChanged: (v) => setState(() => _warnAt = v),
          segments: [for (final w in _warnLevels) AkSegment(w, '$w%')],
        ),
        const SizedBox(height: AkSpace.s2),
        Text(
          'Nearly used from $_warnAt% of the budget',
          style: t.caption.copyWith(color: c.inkMuted),
        ),
        if (_problem != null) ...[
          const SizedBox(height: AkSpace.s3),
          Text(_problem!, style: t.bodySm.copyWith(color: c.moneyOut)),
        ],
        const SizedBox(height: AkSpace.s5),
        AkPrimaryButton(label: 'Save budget', onPressed: _saving ? null : _save),
        if (hasBudget) ...[
          const SizedBox(height: AkSpace.s3),
          Center(child: AkTextLink('Remove budget', onTap: _confirmRemove)),
        ],
      ],
    );
  }

  /// The drawn sentence: how often the amount was exceeded, and what the suggestion would
  /// have covered.
  String _sentence(int amount, int suggestion) {
    final active = widget.history.where((m) => m > 0).toList();
    final over = active.where((m) => m > amount).length;
    final covered = monthsCovered(widget.history, suggestion);
    final months = widget.history.length;
    final overLine = over == 0
        ? 'You stayed within ${formatAmount(amount)} in the last $months months.'
        : 'You went over ${formatAmount(amount)} in $over of the last $months months.';
    return '$overLine A budget of ${formatAmount(suggestion)} would have covered '
        '$covered of them.';
  }
}

/// Six months of money out as bars, with a dashed line at the budget and months over it drawn
/// in `money-out`.
class _HistoryBars extends StatelessWidget {
  const _HistoryBars({
    required this.values,
    required this.labels,
    required this.limit,
    required this.colours,
  });

  final List<int> values;
  final List<String> labels;
  final int limit;
  final ({Color brand, Color over, Color line}) colours;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    var top = limit;
    for (final v in values) {
      if (v > top) top = v;
    }
    final summary = [
      for (var i = 0; i < values.length; i++) '${labels[i]} ${formatAmount(values[i])}',
    ].join(', ');
    return Semantics(
      label: 'Last six months: $summary. Budget ${formatAmount(limit)}.',
      child: ExcludeSemantics(
        child: Column(
          children: [
            SizedBox(
              height: AkSize.chart,
              child: Stack(
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      for (final v in values)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s1),
                            child: Align(
                              alignment: Alignment.bottomCenter,
                              child: Container(
                                height: top == 0 ? 0 : AkSize.chart * (v / top),
                                decoration: BoxDecoration(
                                  color: limit > 0 && v > limit ? colours.over : colours.brand,
                                  borderRadius: BorderRadius.circular(AkRadiusTokens.xs),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (limit > 0 && top > 0)
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: AkSize.chart * (limit / top) - AkSize.stroke / 2,
                      child: CustomPaint(
                        size: const Size.fromHeight(AkSize.stroke),
                        painter: _DashedLinePainter(colours.line),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AkSpace.s2),
            Row(
              children: [
                for (final l in labels)
                  Expanded(
                    child: Text(
                      l,
                      textAlign: TextAlign.center,
                      style: t.caption.copyWith(color: c.inkMuted),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = size.height;
    final y = size.height / 2;
    const dash = AkSpace.s1;
    var x = 0.0;
    while (x < size.width) {
      final end = x + dash > size.width ? size.width : x + dash;
      canvas.drawLine(Offset(x, y), Offset(end, y), paint);
      x += dash * 2;
    }
  }

  @override
  bool shouldRepaint(_DashedLinePainter old) => old.color != color;
}
