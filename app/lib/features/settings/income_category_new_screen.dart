import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';

/// The icon and colour a new money-in category starts with: those of "Other money in" in the
/// default data. Edit a category is where they will be changed.
const newIncomeIconKey = 'dots';
const newIncomeColourToken = 'cat-slate';

/// Adds a money-in category by name. The smallest form that works until the shared Edit a
/// category screen can create categories too; this should move there then.
class IncomeCategoryNewScreen extends ConsumerStatefulWidget {
  const IncomeCategoryNewScreen({super.key});

  @override
  ConsumerState<IncomeCategoryNewScreen> createState() => _IncomeCategoryNewScreenState();
}

class _IncomeCategoryNewScreenState extends ConsumerState<IncomeCategoryNewScreen> {
  final _name = TextEditingController();
  String? _nameError;
  String? _saveError;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // Done on the keyboard and the button can both fire; only one save may run.
    if (_saving) return;
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _nameError = 'Give the category a name.');
      return;
    }
    setState(() {
      _nameError = null;
      _saveError = null;
      _saving = true;
    });
    try {
      await ref
          .read(categoryRepositoryProvider)
          .add(
            name: name,
            kind: CategoryKind.income,
            iconKey: newIncomeIconKey,
            colourToken: newIncomeColourToken,
          );
      if (mounted) await closeScreen(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _saveError = 'The category could not be saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Money-in categories', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s1),
            Semantics(
              header: true,
              child: Text(
                'New money-in category',
                style: context.type.displayLg.copyWith(color: c.ink),
              ),
            ),
            const SizedBox(height: AkSpace.s4),
            AkCard(
              child: AkTextField(
                label: 'Name',
                controller: _name,
                hint: 'For example, Rent from the shop',
                textInputAction: TextInputAction.done,
                errorText: _nameError,
                onChanged: (_) {
                  if (_nameError != null) setState(() => _nameError = null);
                },
                onSubmitted: (_) => _save(),
              ),
            ),
            const SizedBox(height: AkSpace.s4),
            AkPrimaryButton(label: 'Save category', onPressed: _saving ? null : _save),
            if (_saveError != null) AkEmptyNote(_saveError!),
          ],
        ),
      ),
    );
  }
}
