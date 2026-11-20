import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../data/repositories/repositories.dart';
import '../../widgets/ak_category_choices.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/amount_text.dart';
import '../filters/transaction_filter_providers.dart';
import '../home/home_providers.dart';

/// The preview tile at the top of Edit a category is drawn at 64px with a 32px icon. There
/// is no size token for it yet (design check), so it is built from the 48px large tile.
const double _previewTile = AkSize.tileLg + AkSpace.s4;

/// The icon and colour a new category starts with: those of Other and Other money in in the
/// default data, a neutral start the person then changes.
const newCategoryIconKey = 'dots';
const newCategoryColourToken = 'cat-slate';

/// Where Edit a category was opened from, so its back link names the page it returns to.
enum CategoryEditFrom {
  /// Settings > Categories: "Categories".
  settings,

  /// Money-in categories: "Money-in categories".
  income,

  /// The category's own page: the category's name.
  detail;

  /// The value of a route's `from`; anything else is Settings > Categories.
  static CategoryEditFrom parse(String? value) =>
      values.where((f) => f.name == value).firstOrNull ?? settings;

  String backLabel(Category? category) => switch (this) {
    settings => 'Categories',
    income => 'Money-in categories',
    detail => category?.name ?? 'Categories',
  };
}

/// Edit a category: its name, colour, icon and monthly budget, and Delete. The preview tile
/// follows the choices as they are made; nothing is stored until "Save category".
///
/// [CategoryEditScreen.create] is the same screen for a new category of one kind: no Delete,
/// and a budget only for money out. It is added at the end of its kind's order.
class CategoryEditScreen extends ConsumerWidget {
  const CategoryEditScreen({
    super.key,
    required String this.categoryId,
    this.from = CategoryEditFrom.settings,
  }) : newKind = null;

  const CategoryEditScreen.create({
    super.key,
    required CategoryKind kind,
    this.from = CategoryEditFrom.settings,
  }) : categoryId = null,
       newKind = kind;

  /// The category being edited; null for a new one.
  final String? categoryId;

  /// The kind of the new category; null when editing.
  final CategoryKind? newKind;

  final CategoryEditFrom from;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kind = newKind;
    final Widget body;
    if (kind != null) {
      body = _CategoryForm(
        category: null,
        kind: kind,
        fallbackName: null,
        backLabel: from.backLabel(null),
      );
    } else {
      final all = ref.watch(allCategoriesProvider);
      final cats = all.value ?? const <Category>[];
      final category = cats.where((c) => c.id == categoryId).firstOrNull;

      Widget note(String text) => ListView(
        padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
        children: [
          AkBackLink(from.backLabel(null), onTap: () => closeScreen(context)),
          const SizedBox(height: AkSpace.s3),
          AkEmptyNote(text),
        ],
      );

      if (all.hasError) {
        body = note('This category could not load. Close Akatabo and open it again.');
      } else if (!all.hasValue) {
        body = const SizedBox.shrink();
      } else if (category == null) {
        body = note('This category is no longer here.');
      } else {
        final fallbackId = CategoryRepository.fallbackFor(category);
        body = _CategoryForm(
          key: ValueKey(category.id),
          category: category,
          kind: category.kind,
          fallbackName: fallbackId == null
              ? null
              : cats.where((c) => c.id == fallbackId).firstOrNull?.name ?? 'Other',
          backLabel: from.backLabel(category),
          // From the category's own page, that page shows a deleted category as gone, so a
          // delete closes it too and lands where the person opened the category from.
          screensToCloseOnDelete: from == CategoryEditFrom.detail ? 2 : 1,
        );
      }
    }
    return Scaffold(
      backgroundColor: context.colors.ground,
      body: SafeArea(child: body),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({
    super.key,
    required this.category,
    required this.kind,
    required this.fallbackName,
    required this.backLabel,
    this.screensToCloseOnDelete = 1,
  });

  /// How many screens a delete closes: this one, and the category's page when opened from it.
  final int screensToCloseOnDelete;

  /// The stored category; null while making a new one.
  final Category? category;

  final CategoryKind kind;

  /// The name of the category its entries move to when it is deleted; null when it cannot
  /// be deleted (and for a new category).
  final String? fallbackName;

  final String backLabel;

  @override
  ConsumerState<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends ConsumerState<_CategoryForm> {
  late final TextEditingController _name;
  late final TextEditingController _budget;
  late String _colour;
  late String _icon;
  String? _nameError;
  String? _budgetError;
  String? _problem;
  bool _busy = false;

  /// The stored category. Only read where [_isNew] is false.
  Category get _cat => widget.category!;

  bool get _isNew => widget.category == null;

  /// Fees and tax cannot be budgeted (its total comes from fee and tax fields), and budgets
  /// are for money out, so money-in categories have none.
  bool get _budgetable =>
      !(widget.category?.isSystem ?? false) && widget.kind == CategoryKind.spending;

  @override
  void initState() {
    super.initState();
    final cat = widget.category;
    _name = TextEditingController(text: cat?.name ?? '');
    final base = cat?.monthlyBudget;
    _budget = TextEditingController(text: base == null ? '' : formatAmount(base));
    _colour = cat?.colourToken ?? newCategoryColourToken;
    _icon = cat?.iconKey ?? newCategoryIconKey;
  }

  @override
  void dispose() {
    _name.dispose();
    _budget.dispose();
    super.dispose();
  }

  Future<bool> _ask({required String title, required String body, required String yes}) async {
    final answer = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: Text(yes)),
        ],
      ),
    );
    return answer == true && mounted;
  }

  Future<void> _save() async {
    if (_busy) return;
    final name = _name.text.trim();
    final typed = _budget.text.trim();
    final amount = parseAmount(typed);
    setState(() {
      _nameError = name.isEmpty ? 'Give the category a name.' : null;
      _budgetError = _budgetable && typed.isNotEmpty && amount <= 0
          ? 'Enter an amount above zero, or leave it empty for no budget.'
          : null;
      _problem = null;
    });
    if (_nameError != null || _budgetError != null) return;

    final int? budget = _budgetable && typed.isNotEmpty ? amount : null;
    if (_isNew) return _create(name, budget);
    final changeBudget = _budgetable && budget != _cat.monthlyBudget;
    if (changeBudget && budget == null) {
      // Clearing the field removes the budget, so it asks first, as Set a budget does.
      final yes = await _ask(
        title: 'Remove the ${_cat.name} budget?',
        body: 'Its spending stays in your entries and totals. Only the budget goes.',
        yes: 'Remove',
      );
      if (!yes) return;
    }

    setState(() => _busy = true);
    try {
      await ref
          .read(categoryRepositoryProvider)
          .update(
            _cat.id,
            name: name,
            iconKey: _icon,
            colourToken: _colour,
            changeBudget: changeBudget,
            monthlyBudget: budget,
          );
      if (mounted) await closeScreen(context);
    } on CategoryNameTaken {
      if (mounted) {
        setState(() {
          _busy = false;
          _nameError = 'Another category already has this name.';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'The category could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _create(String name, int? budget) async {
    setState(() => _busy = true);
    try {
      await ref
          .read(categoryRepositoryProvider)
          .add(
            name: name,
            kind: widget.kind,
            iconKey: _icon,
            colourToken: _colour,
            monthlyBudget: budget,
          );
      if (mounted) await closeScreen(context);
    } on CategoryNameTaken {
      if (mounted) {
        setState(() {
          _busy = false;
          _nameError = 'Another category already has this name.';
        });
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'The category could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _delete() async {
    final fallback = widget.fallbackName;
    if (_busy || _isNew || fallback == null) return;
    // Taken now, before any wait: once the row is gone this form may be disposed before the
    // delete returns, and a disposed form has no context to close the screen with.
    final router = GoRouter.maybeOf(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      final repo = ref.read(categoryRepositoryProvider);
      final count = await repo.entryCount(_cat.id);
      if (!mounted) return;
      final moves = switch (count) {
        0 => 'It has no entries. Any regular payments in it move to $fallback.',
        1 => 'Its 1 entry and any regular payments move to $fallback.',
        _ => 'Its $count entries and any regular payments move to $fallback.',
      };
      final budget = _cat.monthlyBudget == null ? '' : ' Its budget is removed.';
      final yes = await _ask(
        title: 'Delete ${_cat.name}?',
        body:
            '$moves$budget This cannot be undone. To keep it as it is, switch it off on '
            'Categories instead.',
        yes: 'Delete',
      );
      if (!yes) {
        if (mounted) setState(() => _busy = false);
        return;
      }
      // Read before the delete: the category list can rebuild this screen without the form
      // once the row is gone, and a disposed form can no longer read providers.
      final filter = ref.read(transactionFilterProvider.notifier);
      final id = _cat.id;
      await repo.delete(id);
      // A deleted category chosen in Filters would leave the list empty with no chip to
      // unselect, so it leaves the choice too.
      filter.removeCategory(id);
      for (var i = 0; i < widget.screensToCloseOnDelete; i++) {
        if (router != null) {
          if (!router.canPop()) break;
          router.pop();
        } else {
          await navigator.maybePop();
        }
      }
    } on Object {
      if (mounted) {
        setState(() {
          _busy = false;
          _problem = 'The category could not be deleted. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final typedName = _name.text.trim();
    final shownName = typedName.isNotEmpty
        ? typedName
        : widget.category?.name ??
              (widget.kind == CategoryKind.income ? 'New money-in category' : 'New category');
    return ListView(
      padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
      children: [
        Row(
          children: [
            Expanded(child: AkBackLink(widget.backLabel, onTap: () => closeScreen(context))),
            if (!_isNew && widget.fallbackName != null)
              Semantics(
                button: true,
                label: 'Delete ${_cat.name}',
                container: true,
                excludeSemantics: true,
                onTap: _busy ? null : _delete,
                child: InkWell(
                  onTap: _busy ? null : _delete,
                  borderRadius: BorderRadius.circular(context.metrics.sm),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minHeight: AkSize.target,
                      minWidth: AkSize.target,
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s1),
                      child: Center(
                        widthFactor: 1,
                        child: Text(
                          'Delete',
                          style: t.body.copyWith(color: c.moneyOut, fontWeight: FontWeight.w500),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: AkSpace.s3h),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Semantics(
              label: 'Preview: $shownName',
              image: true,
              child: AkCategoryTile(
                iconKey: _icon,
                colourToken: _colour,
                size: _previewTile,
                iconSize: _previewTile / 2,
              ),
            ),
            const SizedBox(width: AkSpace.s3h),
            Expanded(
              child: AkTextField(
                label: 'Name',
                controller: _name,
                textInputAction: TextInputAction.done,
                errorText: _nameError,
                maxLength: 40,
                onChanged: (_) => setState(() => _nameError = null),
              ),
            ),
          ],
        ),
        const SizedBox(height: AkSpace.s5),
        const AkEyebrow('Colour'),
        const SizedBox(height: AkSpace.s2),
        AkColourChoices(
          label: 'Colour',
          selected: _colour,
          onChanged: (v) => setState(() => _colour = v),
        ),
        const SizedBox(height: AkSpace.s5),
        const AkEyebrow('Icon'),
        const SizedBox(height: AkSpace.s2),
        AkIconChoices(label: 'Icon', selected: _icon, onChanged: (v) => setState(() => _icon = v)),
        if (_budgetable) ...[
          const SizedBox(height: AkSpace.s5),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                flex: 3,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: AkSpace.s1h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Monthly budget', style: t.body.copyWith(fontWeight: FontWeight.w500)),
                      Text(
                        'Leave empty for no budget',
                        style: t.caption.copyWith(color: c.inkMuted),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AkSpace.s3),
              Expanded(
                flex: 2,
                child: AkTextField(
                  label: 'UGX',
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  figures: true,
                  inputFormatters: const [ThousandsFormatter()],
                  onChanged: (_) => setState(() => _budgetError = null),
                ),
              ),
            ],
          ),
          if (_budgetError != null) ...[
            const SizedBox(height: AkSpace.s2),
            Text(_budgetError!, style: t.bodySm.copyWith(color: c.moneyOut)),
          ],
        ],
        if (_problem != null) ...[
          const SizedBox(height: AkSpace.s3),
          Text(_problem!, style: t.bodySm.copyWith(color: c.moneyOut)),
        ],
        const SizedBox(height: AkSpace.s6),
        AkPrimaryButton(label: 'Save category', onPressed: _busy ? null : _save),
      ],
    );
  }
}
