import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../home/home_providers.dart';
import 'settings_page.dart';

/// Shows or hides each category on Add. A hidden category keeps its past entries.
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

    Widget rows(List<Category> list) => Column(
      children: [
        for (final (i, c) in list.indexed)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SettingsSwitchRow(
                label: c.name,
                value: !c.hidden,
                onChanged: (shown) => _setHidden(c.id, hidden: !shown),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(AkSpace.s4, 0, AkSpace.s4, AkSpace.s3),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AkTextLink('Rename', onTap: () => context.push(Routes.categoryEdit(c.id))),
                ),
              ),
              if (i < list.length - 1) const Divider(height: 1),
            ],
          ),
      ],
    );

    return SettingsPage(
      title: 'Categories',
      children: [
        SettingsSection(label: 'Spending', children: [rows(spending)]),
        SettingsSection(label: 'Money in', children: [rows(income)]),
        if (_problem != null) AkEmptyNote(_problem!),
      ],
    );
  }
}
