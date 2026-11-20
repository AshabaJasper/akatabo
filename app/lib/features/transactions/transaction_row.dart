import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_surfaces.dart';

/// "today", "yesterday", a weekday within the last week, or a short date.
String dayLabel(DateTime when, DateTime now) {
  final days = daysBetween(dateOnly(when), dateOnly(now));
  if (days <= 0) return 'today';
  if (days == 1) return 'yesterday';
  if (days < 7) return DateFormat('EEEE').format(when);
  return DateFormat('d MMM').format(when);
}

/// "09:14", the time an entry happened.
String clockLabel(DateTime when) => DateFormat('HH:mm').format(when);

/// One saved transaction as a list row: category tile, words, where and when, and the amount.
///
/// The amount's sign and colour both say the direction, so colour is never the only cue.
class TransactionRow extends StatelessWidget {
  const TransactionRow({
    super.key,
    required this.transaction,
    required this.now,
    this.category,
    this.accountName = '',
    this.toAccountName,
    this.onTap,
  });

  final Transaction transaction;
  final DateTime now;
  final Category? category;

  /// The account paid from (or the one money came into).
  final String accountName;

  /// For a transfer, the account it went to.
  final String? toAccountName;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final tx = transaction;
    final isTransfer = tx.direction == Direction.transfer;
    final isMoneyIn = tx.direction == Direction.moneyIn;
    final tileColour = category == null ? c.catSlate : colourForToken(c, category!.colourToken);
    final tileInk = categoryIconColour(c, category?.colourToken ?? 'cat-slate');

    final words = tx.description.trim();
    final title = words.isNotEmpty
        ? words
        : isTransfer
        ? 'Moved money'
        : (category?.name ?? 'No category');
    final when = '${dayLabel(tx.occurredAt, now)}, ${clockLabel(tx.occurredAt)}';
    final where = isTransfer
        ? '$accountName to ${toAccountName ?? 'another account'}'
        : accountName;
    final subtitle = where.isEmpty ? when : '$where, $when';

    final amountText = isTransfer
        ? formatAmount(tx.amount)
        : formatSigned(tx.amount, moneyIn: isMoneyIn);
    final amountColour = isTransfer ? c.inkMuted : (isMoneyIn ? c.moneyIn : c.moneyOut);

    return Semantics(
      button: onTap != null,
      label: '$title, $amountText, $subtitle',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AkSize.row),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
            child: Row(
              children: [
                AkIconTile(
                  icon: AkIcons.fromKey(category?.iconKey ?? 'dots'),
                  background: tileColour,
                  foreground: tileInk,
                ),
                const SizedBox(width: AkSpace.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyStrong.copyWith(color: c.ink),
                      ),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AkSpace.s2),
                Text(amountText, style: t.figure.copyWith(color: amountColour)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
