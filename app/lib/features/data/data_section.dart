import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../services/backup/backup_settings.dart';
import '../../services/security/lock_controller.dart';
import '../settings/settings_page.dart';
import 'backup_actions.dart';

/// Data and backup on Privacy and data (SetPrivacy.html): Export and back up, Export a
/// monthly report, Save a backup file now, Back up every week, Restore from a backup file,
/// Delete everything on this phone.
class DataSection extends ConsumerStatefulWidget {
  const DataSection({super.key});

  /// Where Restore opens from here, so its back link can say "Privacy and data".
  static const restoreRoute = '${Routes.dataRestore}?from=privacy';

  @override
  ConsumerState<DataSection> createState() => _DataSectionState();
}

enum _DeleteAnswer { cancel, backupFirst, delete }

class _DataSectionState extends ConsumerState<DataSection> {
  bool _working = false;

  Future<void> _run(Future<String?> Function(BackupActions) action) async {
    final message = await action(BackupActions(ref));
    if (!mounted) return;
    setState(() => _working = false);
    showBackupMessage(context, message);
  }

  void _busy() {
    if (mounted) setState(() => _working = true);
  }

  Future<void> _saveNow() => _run((a) => a.saveNow(context, onWorking: _busy));

  Future<void> _confirmDelete() async {
    final c = context.colors;
    final answer = await showDialog<_DeleteAnswer>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete everything on this phone?'),
        content: const Text(
          'Every entry, category, account, budget, regular payment and setting on this phone '
          'is deleted, and Akatabo starts again as on its first day. This cannot be undone.\n\n'
          'Save a backup file first if you may want any of it back.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DeleteAnswer.cancel),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DeleteAnswer.backupFirst),
            child: const Text('Save a backup first'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(_DeleteAnswer.delete),
            style: TextButton.styleFrom(foregroundColor: c.moneyOut),
            child: const Text('Delete everything'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (answer) {
      case _DeleteAnswer.backupFirst:
        await _saveNow();
      case _DeleteAnswer.delete:
        setState(() => _working = true);
        String message;
        try {
          // The same step as "Forgot your PIN?": the PIN goes with everything else.
          await ref.read(lockControllerProvider.notifier).forgetEverything();
          message = 'Everything on this phone was deleted.';
        } catch (error, stack) {
          FlutterError.reportError(
            FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo delete'),
          );
          message = 'Nothing was deleted: something went wrong. Try again.';
        }
        if (!mounted) return;
        setState(() => _working = false);
        showBackupMessage(context, message);
      case _DeleteAnswer.cancel || null:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
    final weekly = BackupKeys.weekly.decode(s[BackupKeys.weekly.name]);
    final last = formatBackupDay(BackupKeys.lastAt.decode(s[BackupKeys.lastAt.name]));

    return SettingsSection(
      label: 'Data and backup',
      children: [
        SettingsValueRow(
          title: 'Export and back up',
          value: 'CSV, Excel, PDF, backup file',
          divider: true,
          onTap: () => context.push(Routes.dataExport),
        ),
        SettingsValueRow(
          title: 'Export a monthly report',
          value: 'PDF',
          divider: true,
          onTap: () => context.push(Routes.dataExportPdf),
        ),
        SettingsValueRow(
          title: 'Save a backup file now',
          value: _working ? 'Saving…' : 'Last: $last',
          divider: true,
          onTap: _working ? null : _saveNow,
        ),
        SettingsSwitchRow(
          label: 'Back up every week',
          detail: 'To a folder you choose on this phone',
          value: weekly,
          divider: true,
          onChanged: (v) {
            if (_working) return;
            _run((a) => a.setWeekly(context, v, onWorking: _busy));
          },
        ),
        SettingsValueRow(
          title: 'Restore from a backup file',
          value: '',
          divider: true,
          onTap: () => context.push(DataSection.restoreRoute),
        ),
        _DangerRow(
          label: 'Delete everything on this phone',
          onTap: _working ? null : _confirmDelete,
        ),
      ],
    );
  }
}

/// The last row of the card, in `money-out`: an action that cannot be undone.
class _DangerRow extends StatelessWidget {
  const _DangerRow({required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: onTap != null,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: AkSize.row),
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsets.symmetric(horizontal: settingsRowSide),
            child: Text(
              label,
              style: context.type.body.copyWith(
                color: context.colors.moneyOut,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
