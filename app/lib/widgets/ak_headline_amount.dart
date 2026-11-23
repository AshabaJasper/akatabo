import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../app/formats.dart';
import '../core/format/money.dart';
import 'ak_hidden_amount.dart';

/// A screen's large main figure, written as "How amounts are written" says: `UGX 1,284,000`
/// or `UGX 1.28M`. A screen reader always hears the full figure, because "1.28M" read aloud
/// loses the exact amount. With [hideable] it also follows "Hide amounts".
class AkHeadlineAmount extends ConsumerWidget {
  const AkHeadlineAmount(
    this.shillings, {
    super.key,
    required this.style,
    this.hideable = false,
    this.prefix = '',
  });

  final int shillings;
  final TextStyle style;
  final bool hideable;

  /// Written before the figure, such as a minus sign.
  final String prefix;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = '$prefix${formatHeadline(shillings, ref.watch(amountStyleProvider))}';
    final full = '$prefix${formatUgx(shillings)}';
    final figure = hideable ? AkHiddenAmount(text, style: style) : Text(text, style: style);
    if (text == full || (hideable && ref.watch(amountsHiddenProvider))) return figure;
    return Semantics(label: full, excludeSemantics: true, child: figure);
  }
}
