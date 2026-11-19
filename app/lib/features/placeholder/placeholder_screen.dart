import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';

/// Stands in for a screen until its phase builds it. Shows only the screen's title.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title, this.closable = false});

  final String title;

  /// Shows a close button, for screens that cover the tabs.
  final bool closable;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s4, AkSpace.s6, AkSpace.s6),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (closable)
                Semantics(
                  button: true,
                  label: 'Close',
                  container: true,
                  excludeSemantics: true,
                  onTap: () => context.pop(),
                  child: Material(
                    color: c.ground,
                    shape: CircleBorder(side: BorderSide(color: c.lineStrong)),
                    clipBehavior: Clip.antiAlias,
                    child: InkWell(
                      onTap: () => context.pop(),
                      child: SizedBox.square(
                        dimension: AkSize.target,
                        child: Center(child: AkIcon(AkIcons.close, color: c.ink)),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: AkSpace.s4),
              Semantics(header: true, child: Text(title, style: context.type.displayLg)),
            ],
          ),
        ),
      ),
    );
  }
}
