import 'dart:math' as math;

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../core/icons/ak_icon.dart';
import '../core/theme/ak_theme.dart';
import 'adaptive.dart';
import 'routes.dart';

/// The five-tab frame: the current tab above, the bottom navigation below.
class ShellScaffold extends StatelessWidget {
  const ShellScaffold({super.key, required this.shell});

  final StatefulNavigationShell shell;

  void _select(int i) => shell.goBranch(i, initialLocation: i == shell.currentIndex);

  @override
  Widget build(BuildContext context) {
    final wide = isWide(context);
    return PopScope(
      // Android back on another tab returns to Home before it leaves the app.
      canPop: shell.currentIndex == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) shell.goBranch(0);
      },
      child: Scaffold(
        // A wide window keeps the tabs in a rail on the left, not at the bottom: a bar across a
        // 1280dp screen is far from the thumb and the eye.
        body: wide
            ? _WideFrame(shell: shell, onSelect: _select, onAdd: () => context.push(Routes.add))
            : HingeSafe(child: shell),
        bottomNavigationBar: wide
            ? null
            : AkBottomNav(
                currentIndex: shell.currentIndex,
                onSelect: _select,
                onAdd: () => context.push(Routes.add),
              ),
      ),
    );
  }
}

/// The rail beside the tabs on a wide window. The tab's content is capped at [AkSize.contentMax]
/// and centred in what is left, so Home and the lists never stretch across a desktop.
class _WideFrame extends StatelessWidget {
  const _WideFrame({required this.shell, required this.onSelect, required this.onAdd});

  final StatefulNavigationShell shell;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    // The rail grows by a left cutout (its SafeArea), so the content starts that much further
    // right, and must not indent by it a second time.
    final inset = MediaQuery.paddingOf(context).left;
    // One surface-coloured strip under the status bar across the whole window: the system picks
    // a single icon colour for the bar, so nothing brand-coloured may sit behind part of it.
    return ColoredBox(
      color: context.colors.surface,
      child: SafeArea(
        bottom: false,
        left: false,
        right: false,
        child: Row(
          children: [
            _Rail(currentIndex: shell.currentIndex, onSelect: onSelect, onAdd: onAdd),
            Expanded(
              child: MediaQuery.removePadding(
                context: context,
                removeLeft: true,
                child: LayoutBuilder(
                  builder: (context, box) {
                    final width = math.min(AkSize.contentMax, box.maxWidth);
                    // The same as the Center below: the space beside the rail, split evenly.
                    final left = AkSize.rail + inset + (box.maxWidth - width) / 2;
                    return ColoredBox(
                      color: context.colors.ground,
                      child: Center(
                        child: ContentFrame(
                          left: left,
                          width: width,
                          child: SizedBox(
                            width: width,
                            child: HingeSafe(child: shell),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The four tabs and the Add disc, down the left of a wide window. The same order and icons as
/// the bottom bar.
class _Rail extends StatelessWidget {
  const _Rail({required this.currentIndex, required this.onSelect, required this.onAdd});

  final int currentIndex;
  final ValueChanged<int> onSelect;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    AkIcon tabIcon(AkIcons icon, {required bool selected}) =>
        AkIcon(icon, size: AkSize.iconNav, color: selected ? c.brandText : c.inkMuted);
    // The label has no style of its own: the rail's selected and unselected styles colour it.
    // At a large text size it shrinks to its slot rather than breaking mid-word.
    NavigationRailDestination dest(AkIcons icon, String label) => NavigationRailDestination(
      icon: tabIcon(icon, selected: false),
      selectedIcon: tabIcon(icon, selected: true),
      label: FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1, softWrap: false)),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(right: BorderSide(color: c.line)),
      ),
      child: SafeArea(
        right: false,
        child: SizedBox(
          width: AkSize.rail,
          child: Column(
            children: [
              const SizedBox(height: AkSpace.s3),
              SizedBox(
                height: AkSize.addDisc,
                width: AkSize.addDisc,
                child: _AddDisc(onTap: onAdd),
              ),
              const SizedBox(height: AkSpace.s3),
              Expanded(
                child: NavigationRail(
                  backgroundColor: c.surface,
                  minWidth: AkSize.rail,
                  // A landscape phone counts as wide; at a large text size the four tabs may
                  // not fit its height, so the rail scrolls rather than cutting Settings off.
                  scrollable: true,
                  selectedLabelTextStyle: t.caption.copyWith(
                    color: c.brandText,
                    fontWeight: FontWeight.w600,
                  ),
                  unselectedLabelTextStyle: t.caption.copyWith(
                    color: c.inkMuted,
                    fontWeight: FontWeight.w500,
                  ),
                  labelType: NavigationRailLabelType.all,
                  selectedIndex: currentIndex,
                  onDestinationSelected: onSelect,
                  indicatorColor: c.brandSoft,
                  destinations: [
                    dest(AkIcons.home, 'Home'),
                    dest(AkIcons.chart, 'Insights'),
                    dest(AkIcons.target, 'Goals'),
                    dest(AkIcons.sliders, 'Settings'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Home, Insights, the Add disc, Goals (savings and budgets), Settings. 64px, `surface`, a
/// `line` top border.
class AkBottomNav extends StatelessWidget {
  const AkBottomNav({
    super.key,
    required this.currentIndex,
    required this.onSelect,
    required this.onAdd,
  });

  /// The tab index: 0 Home, 1 Insights, 2 Goals, 3 Settings.
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
                  label: 'Goals',
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
                  size: AkSize.iconAdd,
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
