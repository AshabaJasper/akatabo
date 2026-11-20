import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/period.dart';
import '../../smart/regular/regular_detector.dart';
import '../../widgets/ak_message.dart';
import '../../widgets/ak_surfaces.dart';
import 'day_number.dart';
import 'regular_providers.dart';

/// "Looks regular": payments Smart help noticed repeating in the entries, with the
/// evidence, and Add or Dismiss for each. Nothing shows when there are none.
class LooksRegularSection extends ConsumerStatefulWidget {
  const LooksRegularSection({super.key});

  @override
  ConsumerState<LooksRegularSection> createState() => _LooksRegularSectionState();
}

class _LooksRegularSectionState extends ConsumerState<LooksRegularSection> {
  /// Payees answered on this screen. Hidden at once, so a second tap before the database
  /// stream catches up cannot save the same series twice.
  final _answered = <String>{};

  @override
  Widget build(BuildContext context) {
    final found = [
      for (final f in ref.watch(looksRegularProvider))
        if (!_answered.contains(f.series.payeeKey)) f,
    ];
    if (found.isEmpty) return const SizedBox.shrink();
    final c = context.colors;
    final t = context.type;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: AkSpace.s5),
        Row(
          children: [
            AkIcon(AkIcons.repeat, color: c.brandText),
            const SizedBox(width: AkSpace.s2),
            Expanded(
              child: Semantics(
                header: true,
                child: Text('Looks regular', style: t.title.copyWith(color: c.ink)),
              ),
            ),
          ],
        ),
        const SizedBox(height: AkSpace.s1),
        Text(
          'Found in your entries. Add one to count it in the forecast.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s3),
        for (final f in found) ...[
          LooksRegularCard(
            found: f,
            onAdd: () => _save(f, dismissed: false),
            onDismiss: () => _save(f, dismissed: true),
          ),
          const SizedBox(height: AkSpace.s3),
        ],
      ],
    );
  }

  Future<void> _save(LooksRegular f, {required bool dismissed}) async {
    final s = f.series;
    if (_answered.contains(s.payeeKey)) return;
    setState(() => _answered.add(s.payeeKey));
    final saved = await saveOrSay(
      context,
      () => ref
          .read(regularPaymentRepositoryProvider)
          .addDetected(
            label: f.label,
            payeeKey: s.payeeKey,
            categoryId: s.categoryId,
            typicalAmount: s.typicalAmount,
            amountLow: s.amountLow,
            amountHigh: s.amountHigh,
            intervalDays: s.intervalDays,
            nextDueOn: localDayOfNumber(s.nextDueFromToday),
            timesSeen: s.occurrences,
            dismissed: dismissed,
          ),
    );
    // Not saved: the card comes back, so the person can answer again.
    if (!saved && mounted) setState(() => _answered.remove(s.payeeKey));
  }
}

/// One noticed series: name and amount, the evidence, the next date, and the two answers.
class LooksRegularCard extends StatelessWidget {
  const LooksRegularCard({
    super.key,
    required this.found,
    required this.onAdd,
    required this.onDismiss,
  });

  final LooksRegular found;
  final VoidCallback onAdd;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final s = found.series;
    final next = DateFormat('EEE d MMM').format(fromLocalDay(localDayOfNumber(s.nextDueFromToday)));
    final amount = s.amountLow == s.amountHigh
        ? formatAmount(s.typicalAmount)
        : '${formatAmount(s.amountLow)} to ${formatAmount(s.amountHigh)}';
    return AkCard(
      padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s3, AkSpace.s4, AkSpace.s1),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(found.label, style: t.bodyStrong.copyWith(color: c.ink)),
              ),
              const SizedBox(width: AkSpace.s3),
              Text(amount, style: t.figure.copyWith(color: c.ink)),
            ],
          ),
          const SizedBox(height: AkSpace.s1),
          Text('${_evidence(s)} Next about $next.', style: t.bodySm.copyWith(color: c.inkMuted)),
          Row(
            children: [
              _Answer('Add', semantics: 'Add ${found.label} as a regular payment', onTap: onAdd),
              const SizedBox(width: AkSpace.s4),
              _Answer('Dismiss', semantics: 'Dismiss ${found.label}', onTap: onDismiss),
            ],
          ),
        ],
      ),
    );
  }

  static String _evidence(RegularSeries s) =>
      'Paid ${s.occurrences} times, about every ${s.intervalDays} days.';
}

class _Answer extends StatelessWidget {
  const _Answer(this.label, {required this.semantics, required this.onTap});
  final String label;
  final String semantics;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    container: true,
    excludeSemantics: true,
    onTap: onTap,
    child: AkTextLink(label, onTap: onTap),
  );
}
