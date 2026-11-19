import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../home/home_providers.dart';
import 'settings_page.dart';

/// Renames one category. Its icon, colour and order are not editable yet.
class CategoryEditScreen extends ConsumerStatefulWidget {
  const CategoryEditScreen({super.key, required this.categoryId});

  final String categoryId;

  @override
  ConsumerState<CategoryEditScreen> createState() => _CategoryEditScreenState();
}

class _CategoryEditScreenState extends ConsumerState<CategoryEditScreen> {
  final _name = TextEditingController();
  bool _loaded = false;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Give the category a name.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(categoryRepositoryProvider).rename(widget.categoryId, name: name);
      if (mounted) await closeScreen(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The category could not be saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final all = ref.watch(allCategoriesProvider);
    if (all.hasError) {
      return const SettingsPage(
        title: 'Rename category',
        children: [AkEmptyNote('This category could not load. Close Akatabo and open it again.')],
      );
    }
    if (!all.hasValue) return const SettingsPage(title: 'Rename category', children: []);

    final matches = all.requireValue.where((c) => c.id == widget.categoryId);
    if (matches.isEmpty) {
      return const SettingsPage(
        title: 'Rename category',
        children: [AkEmptyNote('This category is no longer here.')],
      );
    }
    final cat = matches.single;
    if (!_loaded) {
      _name.text = cat.name;
      _loaded = true;
    }

    return SettingsPage(
      title: 'Rename category',
      children: [
        SettingsSection(
          label: 'Name',
          children: [
            Padding(
              padding: const EdgeInsets.all(AkSpace.s4),
              child: AkTextField(
                label: 'Name',
                controller: _name,
                textInputAction: TextInputAction.done,
                errorText: _error,
                onChanged: (_) {
                  if (_error != null) setState(() => _error = null);
                },
                onSubmitted: (_) => _save(),
              ),
            ),
          ],
        ),
        AkPrimaryButton(label: 'Save name', onPressed: _saving ? null : _save),
      ],
    );
  }
}
