import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../core/theme/ak_theme.dart';
import '../services/security/hidden_amounts.dart';

export '../services/security/hidden_amounts.dart'
    show amountsHiddenProvider, amountsRevealedProvider;

/// What a hidden figure shows: six dots, whatever the amount, so its length says nothing.
const hiddenFigure = '••••••';

/// What a screen reader says for a hidden figure.
const hiddenFigureLabel = 'Amount hidden. Tap to show amounts';

/// A main figure that follows "Hide amounts": dots until the person taps one, then every main
/// figure shows until Akatabo is out of sight again.
class AkHiddenAmount extends ConsumerWidget {
  const AkHiddenAmount(this.text, {super.key, required this.style, this.textAlign});

  /// The figure as it shows when not hidden, for example `UGX 1,284,000`.
  final String text;
  final TextStyle style;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(amountsHiddenProvider)) {
      return Text(text, style: style, textAlign: textAlign);
    }
    void reveal() => ref.read(amountsRevealedProvider.notifier).reveal();
    return Semantics(
      button: true,
      label: hiddenFigureLabel,
      excludeSemantics: true,
      onTap: reveal,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: reveal,
        // At least 44 by 44, so a small figure is still easy to tap.
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AkSize.target, minWidth: AkSize.target),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: 1,
            heightFactor: 1,
            child: Text(hiddenFigure, style: style, textAlign: textAlign),
          ),
        ),
      ),
    );
  }
}
