import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/semantics.dart' show CustomSemanticsAction;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../home/home_providers.dart';
import 'income_categories_screen.dart';
import 'settings_page.dart';

/// Each category with its tile and budget: tap to edit it, drag the grip (or use its menu)
/// to reorder, switch off to hide it. A hidden category keeps its past entries.
/// The system Fees and tax category is never listed: its totals come from fee and tax fields.
class CategoriesSettingsScreen extends ConsumerStatefulWidget {
  const CategoriesSettingsScreen({super.key});

  @override
  ConsumerState<CategoriesSettingsScreen> createState() => _CategoriesSettingsScreenState();
}

class _CategoriesSettingsScreenState extends ConsumerState<CategoriesSettingsScreen> {
  String? _problem;

  Future<void> _setHidden(String id, {required bool hidden}) async {
    setState(() => _problem = null);
    try {
      await ref.read(categoryRepositoryProvider).setHidden(id, hidden: hidden);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  Future<bool> _reorder(List<String> ids) async {
    setState(() => _problem = null);
    try {
      await ref.read(categoryRepositoryProvider).reorder(ids);
      return true;
    } on Object {
      if (mounted) setState(() => _problem = 'The new order could not be saved. Try again.');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allCategoriesProvider);
    if (all.hasError) {
      return const SettingsPage(
        title: 'Categories',
        children: [AkEmptyNote('Categories could not load. Close Akatabo and open it again.')],
      );
    }
    if (!all.hasValue) return const SettingsPage(title: 'Categories', children: []);
    final cats = all.requireValue.where((c) => !c.isSystem).toList();
    final spending = cats.where((c) => c.kind == CategoryKind.spending).toList();
    final income = cats.where((c) => c.kind == CategoryKind.income).toList();

    Widget list(List<Category> items) => CategoryOrderList(
      categories: items,
      onEdit: (c) => context.push(Routes.categoryEdit(c.id)),
      onHidden: (c, hidden) => _setHidden(c.id, hidden: hidden),
      onReorder: _reorder,
    );

    return SettingsPage(
      title: 'Categories',
      children: [
        Text(
          'Tap one to change its name, icon, colour or budget. Drag to reorder. '
          'Switch off to hide it.',
          style: context.type.bodySm.copyWith(color: context.colors.inkMuted),
        ),
        const SizedBox(height: AkSpace.s4),
        SettingsSection(label: 'Spending', children: [list(spending)]),
        // As drawn: money-in categories have their own screen, reached by one row here.
        Padding(
          padding: const EdgeInsets.only(bottom: AkSpace.s6),
          child: AkCard(
            padding: EdgeInsets.zero,
            child: SettingsValueRow(
              title: 'Money-in categories',
              value: incomeCategoryWords(income),
              onTap: () => context.push(Routes.settingsIncomeCategories),
            ),
          ),
        ),
        if (_problem != null) AkEmptyNote(_problem!),
        AkPrimaryButton(
          label: 'New category',
          onPressed: () => context.push(Routes.settingsCategoryNew),
        ),
      ],
    );
  }
}

/// Where a reorder action puts a row.
enum _Move { top, up, down, bottom }

/// One kind's categories in the person's order, each row with a grip, its tile, name and
/// budget, and a show switch. Rows reorder by dragging the grip after a long press, by the
/// grip's menu (Move up, Move down, Move to the top or bottom) for keyboard and switch
/// users, and by the same moves as screen-reader actions on each row.
class CategoryOrderList extends StatefulWidget {
  const CategoryOrderList({
    super.key,
    required this.categories,
    required this.onEdit,
    required this.onHidden,
    required this.onReorder,
  });

  final List<Category> categories;
  final ValueChanged<Category> onEdit;
  final void Function(Category category, bool hidden) onHidden;

  /// Saves the ids of [categories] in their new order; completes with false when it failed.
  final Future<bool> Function(List<String> ids) onReorder;

  @override
  State<CategoryOrderList> createState() => _CategoryOrderListState();
}

class _CategoryOrderListState extends State<CategoryOrderList> {
  /// The order on screen. A move shows at once, before the database confirms it, so a
  /// dropped row does not jump back and then forward again.
  late List<Category> _shown = widget.categories;

  @override
  void didUpdateWidget(CategoryOrderList old) {
    super.didUpdateWidget(old);
    // A parent rebuild hands over a new list with the same rows; only a real change from the
    // database replaces what is shown.
    if (!listEquals(old.categories, widget.categories)) _shown = widget.categories;
  }

  Future<void> _move(int from, int to) async {
    if (to < 0 || to >= _shown.length || to == from) return;
    final before = _shown;
    final next = [...before];
    next.insert(to, next.removeAt(from));
    setState(() => _shown = next);
    final saved = await widget.onReorder([for (final c in next) c.id]);
    if (!saved && mounted && identical(_shown, next)) setState(() => _shown = before);
  }

  void _apply(int index, _Move move) => _move(index, switch (move) {
    _Move.top => 0,
    _Move.up => index - 1,
    _Move.down => index + 1,
    _Move.bottom => _shown.length - 1,
  });

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final categories = _shown;
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: categories.length,
      // A dragged row lifts as a plain `surface` card with its 1px line: no shadow.
      proxyDecorator: (child, _, _) => Material(
        color: c.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(context.metrics.lg),
          side: BorderSide(color: c.lineStrong),
        ),
        child: child,
      ),
      onReorderItem: _move,
      itemBuilder: (context, i) {
        final cat = categories[i];
        return _CategoryRow(
          key: ValueKey(cat.id),
          index: i,
          category: cat,
          isFirst: i == 0,
          isLast: i == categories.length - 1,
          onEdit: () => widget.onEdit(cat),
          onHidden: (hidden) => widget.onHidden(cat, hidden),
          onMove: (move) => _apply(i, move),
        );
      },
    );
  }
}

class _CategoryRow extends StatelessWidget {
  const _CategoryRow({
    super.key,
    required this.index,
    required this.category,
    required this.isFirst,
    required this.isLast,
    required this.onEdit,
    required this.onHidden,
    required this.onMove,
  });

  final int index;
  final Category category;
  final bool isFirst;
  final bool isLast;
  final VoidCallback onEdit;
  final ValueChanged<bool> onHidden;
  final ValueChanged<_Move> onMove;

  List<(_Move, String)> get _moves => [
    if (!isFirst) ...[(_Move.up, 'Move up'), (_Move.top, 'Move to the top')],
    if (!isLast) ...[(_Move.down, 'Move down'), (_Move.bottom, 'Move to the bottom')],
  ];

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final name = category.name;
    final budget = category.monthlyBudget;
    final subtitle = category.kind == CategoryKind.income
        ? null
        : budget == null
        ? 'No budget'
        : 'Budget ${formatAmount(budget)}';
    final moves = _moves;

    return Semantics(
      customSemanticsActions: {
        for (final (move, label) in moves) CustomSemanticsAction(label: label): () => onMove(move),
      },
      child: Container(
        // No fill: the card's own Material shows through, so the row's tap ripple is seen.
        decoration: BoxDecoration(
          border: isLast ? null : Border(bottom: BorderSide(color: c.line)),
        ),
        padding: const EdgeInsets.only(right: AkSpace.s3),
        child: Row(
          children: [
            ReorderableDelayedDragStartListener(
              index: index,
              enabled: moves.isNotEmpty,
              // Named here, not by a tooltip: a tooltip would pop up on the long press that
              // starts a drag.
              child: Semantics(
                container: true,
                button: true,
                label: 'Move $name',
                child: PopupMenuButton<_Move>(
                  tooltip: '',
                  enabled: moves.isNotEmpty,
                  elevation: 0,
                  color: c.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(context.metrics.lg),
                    side: BorderSide(color: c.lineStrong),
                  ),
                  onSelected: onMove,
                  itemBuilder: (_) => [
                    for (final (move, label) in moves)
                      PopupMenuItem(
                        value: move,
                        child: Text(label, style: t.bodyMd.copyWith(color: c.ink)),
                      ),
                  ],
                  child: SizedBox.square(
                    dimension: AkSize.target,
                    child: Center(
                      child: AkIcon(AkIcons.grip, size: AkSize.iconSm, color: c.inkMuted),
                    ),
                  ),
                ),
              ),
            ),
            Expanded(
              child: Semantics(
                button: true,
                label: subtitle == null ? 'Edit $name' : 'Edit $name, $subtitle',
                container: true,
                excludeSemantics: true,
                onTap: onEdit,
                child: InkWell(
                  onTap: onEdit,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(minHeight: AkSize.row),
                    child: Row(
                      children: [
                        AkCategoryTile(
                          iconKey: category.iconKey,
                          colourToken: category.colourToken,
                        ),
                        const SizedBox(width: AkSpace.s3),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: AkSpace.s1h),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(name, style: t.body.copyWith(fontWeight: FontWeight.w500)),
                                if (subtitle != null)
                                  Text(subtitle, style: t.caption.copyWith(color: c.inkMuted)),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: AkSpace.s2h),
            AkSwitch(
              label: 'Show $name',
              value: !category.hidden,
              onChanged: (shown) => onHidden(!shown),
            ),
          ],
        ),
      ),
    );
  }
}
