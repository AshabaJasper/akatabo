import 'package:material_ui/material_ui.dart';

import '../core/theme/ak_theme.dart';
import 'ak_surfaces.dart';

/// What a list, chart or total says when there is nothing to show yet. Always a sentence the
/// person can act on or understand, never a bare zero.
///
/// With [actionLabel] and [onAction] it also offers the next step as a text link under the
/// sentence, so an empty screen is never a dead end.
class AkEmptyNote extends StatelessWidget {
  const AkEmptyNote(this.text, {super.key, this.actionLabel, this.onAction})
    : assert((actionLabel == null) == (onAction == null), 'Give both a label and an action');

  final String text;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AkSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(text, style: context.type.bodyMd.copyWith(color: context.colors.inkMuted)),
        if (actionLabel != null) ...[
          const SizedBox(height: AkSpace.s2),
          AkTextLink(actionLabel!, onTap: onAction!),
        ],
      ],
    ),
  );
}
