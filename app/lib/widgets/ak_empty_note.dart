import 'package:material_ui/material_ui.dart';

import '../core/theme/ak_theme.dart';

/// What a list, chart or total says when there is nothing to show yet. Always a sentence the
/// person can act on or understand, never a bare zero.
class AkEmptyNote extends StatelessWidget {
  const AkEmptyNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AkSpace.s4),
    child: Text(text, style: context.type.bodyMd.copyWith(color: context.colors.inkMuted)),
  );
}
