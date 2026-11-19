import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/db/tables.dart';
import '../../data/providers.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import 'settings_page.dart';

String _kindLabel(AccountKind k) => switch (k) {
  AccountKind.cash => 'Cash',
  AccountKind.mtn => 'MTN MoMo',
  AccountKind.airtel => 'Airtel Money',
  AccountKind.bank => 'Bank',
  AccountKind.other => 'Other',
};

/// Adds an account the person pays from. Saved accounts appear on the Accounts page and on Add.
class NewAccountScreen extends ConsumerStatefulWidget {
  const NewAccountScreen({super.key});

  @override
  ConsumerState<NewAccountScreen> createState() => _NewAccountScreenState();
}

class _NewAccountScreenState extends ConsumerState<NewAccountScreen> {
  final _name = TextEditingController();
  AccountKind _kind = AccountKind.other;
  String? _error;
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
      setState(() => _error = 'Give the account a name.');
      return;
    }
    setState(() {
      _error = null;
      _saving = true;
    });
    try {
      await ref.read(accountRepositoryProvider).add(name: name, kind: _kind);
      if (mounted) await closeScreen(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'The account could not be saved. Try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'New account',
      children: [
        SettingsSection(
          label: 'Account',
          children: [
            Padding(
              padding: const EdgeInsets.all(AkSpace.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AkTextField(
                    label: 'Name',
                    controller: _name,
                    hint: 'For example, Airtel wallet',
                    textInputAction: TextInputAction.done,
                    errorText: _error,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    onSubmitted: (_) => _save(),
                  ),
                  const SizedBox(height: AkSpace.s4),
                  Text('Kind', style: context.type.bodyMd),
                  const SizedBox(height: AkSpace.s2),
                  AkSegmented<AccountKind>(
                    semanticLabel: 'Kind of account',
                    segments: [for (final k in AccountKind.values) AkSegment(k, _kindLabel(k))],
                    selected: _kind,
                    onChanged: (k) => setState(() => _kind = k),
                  ),
                ],
              ),
            ),
          ],
        ),
        AkPrimaryButton(label: 'Save account', onPressed: _saving ? null : _save),
        if (_error != null && _name.text.trim().isNotEmpty) AkEmptyNote(_error!),
      ],
    );
  }
}
