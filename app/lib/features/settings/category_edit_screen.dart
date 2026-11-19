import 'package:flutter_riverpod/flutter_riverpod.dart';
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
import '../home/home_providers.dart';

/// The preview tile at the top of Edit a category is drawn at 64px with a 32px icon. There
/// is no size token for it yet (design check), so it is built from the 48px large tile.
const double _previewTile = AkSize.tileLg + AkSpace.s4;

/// Edit a category: its name, colour, icon and monthly budget, and Delete. The preview tile
/// follows the choices as they are made; nothing is stored until "Save category".
class CategoryEditScreen extends ConsumerWidget {
  const CategoryEditScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final all = ref.watch(allCategoriesProvider);
    final cats = all.value ?? const <Category>[];
    final category = cats.where((c) => c.id == categoryId).firstOrNull;

    Widget note(String text) => ListView(
      padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
      children: [
        AkBackLink('Categories', onTap: () => closeScreen(context)),
        const SizedBox(height: AkSpace.s3),
        AkEmptyNote(text),
      ],
    );

    final Widget body;
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
        fallbackName: fallbackId == null
            ? null
            : cats.where((c) => c.id == fallbackId).firstOrNull?.name ?? 'Other',
      );
    }
    return Scaffold(
      backgroundColor: context.colors.ground,
      body: SafeArea(child: body),
    );
  }
}

class _CategoryForm extends ConsumerStatefulWidget {
  const _CategoryForm({super.key, required this.category, required this.fallbackName});

  final Category category;

  /// The name of the category its entries move to when it is deleted; null when it cannot
  /// be deleted.
  final String? fallbackName;

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

  Category get _cat => widget.category;

  /// Fees and tax cannot be budgeted (its total comes from fee and tax fields), and budgets
  /// are for money out, so money-in categories have none.
  bool get _budgetable => !_cat.isSystem && _cat.kind == CategoryKind.spending;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _cat.name);
    final base = _cat.monthlyBudget;
    _budget = TextEditingController(text: base == null ? '' : formatAmount(base));
    _colour = _cat.colourToken;
    _icon = _cat.iconKey;
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

  Future<void> _delete() async {
    final fallback = widget.fallbackName;
    if (_busy || fallback == null) return;
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
      await repo.delete(_cat.id);
      if (mounted) await closeScreen(context);
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
    final shownName = _name.text.trim().isEmpty ? _cat.name : _name.text.trim();
    return ListView(
      padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
      children: [
        Row(
          children: [
            Expanded(child: AkBackLink('Categories', onTap: () => closeScreen(context))),
            if (widget.fallbackName != null)
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
