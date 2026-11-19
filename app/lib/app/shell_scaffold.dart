import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';
import 'routes.dart';

/// The five-tab frame: the current tab above, the bottom navigation below.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Android back on another tab returns to Home before it leaves the app.
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        body: shell,
        bottomNavigationBar: AkBottomNav(
          currentIndex: shell.currentIndex,
          onSelect: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
          onAdd: () => context.push(Routes.add),
        ),
      ),
    );
  }
}

/// Home, Insights, the Add disc, Budgets, Settings. 64px, `surface`, a `line` top border.
class AkBottomNav extends StatelessWidget {
  const AkBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
  });

  /// The tab index: 0 Home, 1 Insights, 2 Budgets, 3 Settings.
  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: c.surface,
          border: Border(top: BorderSide(color: c.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: AkSize.nav,
            child: Row(
              children: [
                _NavItem(
                  icon: AkIcons.home,
                  label: 'Home',
                  selected: currentIndex == 0,
                  onTap: () => onSelect(0),
                ),
                _NavItem(
                  icon: AkIcons.chart,
                  label: 'Insights',
                  selected: currentIndex == 1,
                  onTap: () => onSelect(1),
                ),
                Expanded(child: _AddDisc(onTap: onAdd)),
                _NavItem(
                  icon: AkIcons.target,
                  label: 'Budgets',
                  selected: currentIndex == 2,
                  onTap: () => onSelect(2),
                ),
                _NavItem(
                  icon: AkIcons.sliders,
                  label: 'Settings',
                  selected: currentIndex == 3,
                  onTap: () => onSelect(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AkIcons icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colour = selected ? c.brandText : c.inkMuted;
    final style = context.type.caption.copyWith(
      color: colour,
      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
    );
    return Expanded(
      child: Semantics(
        button: true,
        selected: selected,
        label: label,
        container: true,
        excludeSemantics: true,
        // excludeSemantics drops the InkWell's own tap action, so it is given here,
        // or TalkBack and Switch Access cannot open the tab.
        onTap: onTap,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AkIcon(icon, size: AkSize.iconNav, color: colour),
              const SizedBox(height: AkSpace.s1),
              // At a large phone text size the label shrinks to its slot rather than
              // running into the next item.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AkSpace.s0h),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(label, style: style, maxLines: 1, softWrap: false),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddDisc extends StatelessWidget {
  const _AddDisc({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: 'Add a transaction',
      container: true,
      excludeSemantics: true,
      onTap: onTap,
      child: Center(
        child: Material(
          color: c.switchOn,
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: SizedBox.square(
              dimension: AkSize.addDisc,
              child: Center(
                child: AkIcon(
                  AkIcons.plus,
                  size: AkSize.iconNav,
                  strokeWidth: 2.5,
                  color: c.onBrand,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
