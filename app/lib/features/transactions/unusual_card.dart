import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../smart/regular/stats.dart';
import '../../smart/unusual/unusual_detector.dart';
import 'unusual_providers.dart';

/// The sentences that say why an entry stands out, one per signal, in plain words.
List<String> unusualReasonLines(UnusualNote note, {required String categoryName}) {
  final s = note.result.signals;
  return [
    for (final r in note.result.reasons)
      switch (r) {
        UnusualReason.amount => _amountLine(note, s, categoryName),
        UnusualReason.hour =>
          'You rarely pay anything at this hour (${_two(note.hour)}:00 to '
              '${_two((note.hour + 1) % 24)}:00).',
        UnusualReason.payee => 'You have not paid this name before.',
      },
  ];
}

String _amountLine(UnusualNote note, UnusualSignals s, String categoryName) {
  final usual = roundHalfUp(s.usualAmount);
  final times = usual > 0 ? note.amount / usual : 0.0;
  final where = s.basis == UnusualBasis.payee ? 'here' : 'for $categoryName';
  final multiple = times >= 10 ? '${roundHalfUp(times)}' : times.toStringAsFixed(1);
  return 'It is about $multiple times what you usually pay $where (UGX ${formatAmount(usual)}).';
}

String _two(int h) => h.toString().padLeft(2, '0');

/// Shown on One transaction when Smart help finds the entry unusual. It gives its evidence
/// and lets the person answer "This was me", which hides it for the rest of the session.
class UnusualCard extends StatelessWidget {
  const UnusualCard({
    super.key,
    required this.note,
    required this.categoryName,
    required this.onThisWasMe,
  });

  final UnusualNote note;
  final String categoryName;
  final VoidCallback onThisWasMe;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final lines = unusualReasonLines(note, categoryName: categoryName);
    final evidence =
        'Compared with your ${note.categoryEntries} earlier $categoryName '
        '${note.categoryEntries == 1 ? 'entry' : 'entries'}.';
    return Container(
      padding: const EdgeInsets.fromLTRB(AkSpace.s4, AkSpace.s4, AkSpace.s4, AkSpace.s2),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(context.metrics.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: AkSize.tile,
            height: AkSize.tile,
            decoration: BoxDecoration(
              color: c.moneyOutSoft,
              borderRadius: BorderRadius.circular(context.metrics.md),
            ),
            alignment: Alignment.center,
            child: AkIcon(AkIcons.alert, color: c.moneyOut),
          ),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text('Unusual for you', style: t.title.copyWith(color: c.ink)),
                ),
                const SizedBox(height: AkSpace.s1),
                if (lines.isEmpty)
                  Text(
                    'It is far from your usual pattern.',
                    style: t.bodySm.copyWith(color: c.ink),
                  ),
                for (final line in lines) ...[
                  Text(line, style: t.bodySm.copyWith(color: c.ink)),
                  const SizedBox(height: AkSpace.s1),
                ],
                Text(evidence, style: t.caption.copyWith(color: c.inkMuted)),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _ThisWasMe(onTap: onThisWasMe),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ThisWasMe extends StatelessWidget {
  const _ThisWasMe({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = context.colors.brandText;
    return Semantics(
      button: true,
      label: 'This was me. Hide this note',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.metrics.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AkSize.target, minWidth: AkSize.target),
          child: Align(
            widthFactor: 1,
            child: Text(
              'This was me',
              style: context.type.bodySm.copyWith(color: colour, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }
}
