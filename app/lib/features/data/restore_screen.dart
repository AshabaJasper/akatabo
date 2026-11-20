import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../services/backup/backup_codec.dart';
import '../../services/backup/backup_files.dart';
import '../../services/backup/backup_service.dart';
import '../../services/backup/restore_planner.dart';
import '../../services/security/lock_controller.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import 'backup_actions.dart';
import 'backup_password.dart';
import 'restore_parts.dart';

/// Restore from a backup, as DataRestore.html draws it: 1 choose the file, 2 check it, 3
/// restore. Step 2 is drawn; step 1, the password entry, step 3 and the errors are built
/// from the rules and flagged for a design check.
///
/// Nothing on the phone changes until the person presses the restore button, and then it
/// all changes in one database transaction or not at all.
class RestoreScreen extends ConsumerStatefulWidget {
  const RestoreScreen({super.key, this.fromPrivacy});

  /// Opened from Privacy and data, so the back link names it. Null reads the route's
  /// `from=privacy`; drawn as "Export and back up".
  final bool? fromPrivacy;

  @override
  ConsumerState<RestoreScreen> createState() => _RestoreScreenState();
}

/// What went wrong with the chosen file, or with restoring it.
enum _Trouble { notAkatabo, damaged, newer, unreadable, restoreFailed }

class _RestoreScreenState extends ConsumerState<RestoreScreen> {
  PickedFile? _file;
  BackupHeader? _header;
  OpenedBackup? _opened;
  _Trouble? _trouble;
  String? _newerAppVersion;
  String? _busy;
  bool _wrongPassword = false;
  RestoreMode _mode = RestoreMode.addMissing;
  final _password = TextEditingController();

  /// Set when the restore finished: what it did, for step 3.
  ({RestoreMode mode, RestorePreview preview})? _done;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  bool get _fromPrivacy {
    if (widget.fromPrivacy != null) return widget.fromPrivacy!;
    if (GoRouter.maybeOf(context) == null) return false;
    return GoRouterState.of(context).uri.queryParameters['from'] == 'privacy';
  }

  int get _step => _done != null ? 2 : (_file == null ? 0 : 1);

  BackupService get _service => ref.read(backupServiceProvider);

  void _problem(BackupException e) {
    setState(() {
      switch (e.problem) {
        case BackupProblem.notAkatabo:
          _trouble = _Trouble.notAkatabo;
        case BackupProblem.newerVersion:
          _trouble = _Trouble.newer;
          _newerAppVersion = e.appVersion;
        case BackupProblem.wrongPassword:
          _wrongPassword = true;
        case BackupProblem.damaged || BackupProblem.passwordNeeded:
          _trouble = _Trouble.damaged;
      }
    });
  }

  Future<void> _choose() async {
    final PickedFile? file;
    try {
      file = await ref
          .read(lockControllerProvider.notifier)
          .keepUnlockedWhile(() => ref.read(backupFilesProvider).pick());
    } on BackupException catch (e) {
      if (mounted) _problem(e);
      return;
    } catch (error, stack) {
      _report(error, stack);
      if (mounted) setState(() => _trouble = _Trouble.unreadable);
      return;
    }
    if (file == null || !mounted) return;
    setState(() {
      _file = file;
      _header = null;
      _opened = null;
      _trouble = null;
      _wrongPassword = false;
      _password.clear();
      _mode = RestoreMode.addMissing;
    });
    try {
      final header = _service.codec.readHeader(file.bytes);
      setState(() => _header = header);
      if (!header.isProtected) await _open();
    } on BackupException catch (e) {
      _problem(e);
    }
  }

  Future<void> _open() async {
    final file = _file;
    if (file == null) return;
    final protected = _header?.isProtected ?? false;
    if (protected && _password.text.isEmpty) {
      setState(() => _wrongPassword = true);
      return;
    }
    setState(() {
      _busy = protected ? 'Checking the password…' : 'Reading the backup…';
      _wrongPassword = false;
    });
    try {
      final opened = await _service.open(file.bytes, password: protected ? _password.text : null);
      if (!mounted) return;
      setState(() {
        _opened = opened;
        // "Add what is missing" is the default; replacing is the destructive choice.
        _mode = RestoreMode.addMissing;
      });
    } on BackupException catch (e) {
      if (mounted) _problem(e);
    } catch (error, stack) {
      _report(error, stack);
      if (mounted) setState(() => _trouble = _Trouble.damaged);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _restore() async {
    final opened = _opened;
    if (opened == null) return;
    final p = opened.preview;
    if (_mode == RestoreMode.replaceAll && !await _confirmReplace(p)) return;
    if (!mounted) return;
    setState(() {
      _busy = 'Restoring…';
      _trouble = null;
    });
    try {
      await _service.restore(opened, _mode);
      if (mounted) setState(() => _done = (mode: _mode, preview: p));
    } catch (error, stack) {
      _report(error, stack);
      if (mounted) setState(() => _trouble = _Trouble.restoreFailed);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<bool> _confirmReplace(RestorePreview p) async {
    final lost = p.lostByReplacing;
    final c = context.colors;
    final yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Replace everything on this phone?'),
        content: Text(
          'This phone will hold only what is in the backup. '
          '${lost == 0 ? 'Every entry here is in the backup too.' : 'The ${_entries(lost)} only this phone has will be deleted.'}'
          '${p.phoneNewer == 0 ? '' : ' ${_changes(p.phoneNewer)} made here since the backup will be undone.'}'
          ' This cannot be undone.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: TextButton.styleFrom(foregroundColor: c.moneyOut),
            child: const Text('Replace everything'),
          ),
        ],
      ),
    );
    return yes ?? false;
  }

  static void _report(Object error, StackTrace stack) => FlutterError.reportError(
    FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo restore'),
  );

  @override
  Widget build(BuildContext context) {
    final restoring = _busy == 'Restoring…';
    return PopScope(
      canPop: !restoring,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AkSpace.s6,
                    AkSpace.s2,
                    AkSpace.s6,
                    AkSpace.s4,
                  ),
                  children: [
                    AkBackLink(
                      _fromPrivacy ? 'Privacy and data' : 'Export and back up',
                      onTap: restoring ? () {} : () => closeScreen(context),
                    ),
                    const SizedBox(height: AkSpace.s1),
                    Semantics(header: true, child: Text('Restore', style: context.type.displayLg)),
                    const SizedBox(height: AkSpace.s3h),
                    RestoreSteps(current: _step),
                    const SizedBox(height: AkSpace.s3h),
                    ..._body(context),
                  ],
                ),
              ),
              if (_action(context) case final action?)
                Padding(
                  padding: const EdgeInsets.fromLTRB(AkSpace.s6, 0, AkSpace.s6, AkSpace.s5),
                  child: action,
                ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _body(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    if (_done case final done?) return [_DoneNote(mode: done.mode, preview: done.preview)];
    if (_file == null) {
      return [
        Text(
          'Pick a backup file you saved from Akatabo. Its name ends in .akatabo.',
          style: t.bodyLg,
        ),
        const SizedBox(height: AkSpace.s2),
        Text(
          'You will see what is in it, and choose how to restore it, before anything on this '
          'phone changes.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        if (_trouble == _Trouble.unreadable) ...[
          const SizedBox(height: AkSpace.s4),
          const RestoreProblemCard(
            title: 'The file could not be opened',
            body:
                'Akatabo could not read it from where it is kept. Try again, or copy the file '
                'to this phone first.',
          ),
        ],
      ];
    }

    final widgets = <Widget>[_fileCard(context)];
    if (_trouble != null) {
      final (title, body) = switch (_trouble!) {
        _Trouble.notAkatabo => (
          'This is not an Akatabo backup',
          'Akatabo can restore only the backup files it saves. Their names end in .akatabo. '
              'Choose one of those.',
        ),
        _Trouble.damaged || _Trouble.unreadable => (
          'This backup cannot be read',
          'The file may be damaged, or cut short while it was copied or sent. Try another '
              'copy of it, such as the one you first saved.',
        ),
        _Trouble.newer => (
          'This backup is from a newer Akatabo',
          'It was saved by ${_newerAppVersion == null ? 'a newer version of Akatabo' : 'Akatabo $_newerAppVersion'}, '
              'which this phone does not have yet. Update Akatabo from the app store, then '
              'restore the file again.',
        ),
        _Trouble.restoreFailed => (
          'Nothing was changed',
          'The restore stopped part way, so all of it was undone. Your data is as it was '
              'before. Try again, or choose another copy of the backup.',
        ),
      };
      widgets.addAll([
        const SizedBox(height: AkSpace.s3h),
        RestoreProblemCard(title: title, body: body),
      ]);
      if (_trouble != _Trouble.restoreFailed) return widgets;
    }
    if (_busy != null) {
      widgets.addAll([const SizedBox(height: AkSpace.s4), _BusyNote(_busy!)]);
      return widgets;
    }
    final opened = _opened;
    if (opened == null) {
      if (_header?.isProtected ?? false) {
        widgets.addAll([
          const SizedBox(height: AkSpace.s4),
          Text('This backup is protected. Type the password it was saved with.', style: t.body),
          const SizedBox(height: AkSpace.s3),
          BackupPasswordField(
            label: 'Backup password',
            controller: _password,
            autofocus: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _open(),
            errorText: _wrongPassword
                ? (_password.text.isEmpty
                      ? 'Type the password to open the backup.'
                      : 'That password does not open this backup. Check capital letters and '
                            'try again.')
                : null,
          ),
          const SizedBox(height: AkSpace.s2),
          Text(
            'Forgotten it? Without the password nobody can open this file. Try another '
            'backup that has no password, or one whose password you know.',
            style: t.caption.copyWith(color: c.inkMuted),
          ),
        ]);
      }
      return widgets;
    }

    final p = opened.preview;
    widgets.addAll([
      const SizedBox(height: AkSpace.s3h),
      _contents(context, p),
      const SizedBox(height: AkSpace.s3h),
      const AkEyebrow('How to restore'),
      const SizedBox(height: AkSpace.s2),
      RestoreChoice(
        title: 'Add what is missing',
        detail: _addDetail(p),
        selected: _mode == RestoreMode.addMissing,
        onTap: () => setState(() => _mode = RestoreMode.addMissing),
      ),
      const SizedBox(height: AkSpace.s2),
      RestoreChoice(
        title: 'Replace everything on this phone',
        detail: p.lostByReplacing > 0
            ? 'Your ${_entries(p.lostByReplacing)} not in the backup would be lost'
            : 'This phone will hold exactly what the backup holds',
        warning: p.lostByReplacing > 0,
        selected: _mode == RestoreMode.replaceAll,
        onTap: () => setState(() => _mode = RestoreMode.replaceAll),
      ),
    ]);
    return widgets;
  }

  Widget _fileCard(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final file = _file!;
    final header = _header;
    final size = _size(file.bytes.length);
    final String detail;
    if (_trouble != null && _trouble != _Trouble.restoreFailed) {
      detail = size;
    } else if (header == null) {
      detail = size;
    } else if (header.isProtected) {
      detail = _opened == null ? '$size, protected with a password' : '$size, password accepted';
    } else {
      detail = '$size, saved ${formatBackupDay(header.createdAt.millisecondsSinceEpoch)}';
    }
    return Container(
      constraints: const BoxConstraints(minHeight: AkSize.row + AkSpace.s2),
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border.all(color: c.line),
        borderRadius: BorderRadius.circular(context.metrics.lg),
      ),
      child: Row(
        children: [
          AkIconTile(icon: AkIcons.file, background: c.surfaceSunk, foreground: c.brandText),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    file.name,
                    style: t.bodyStrong,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(detail, style: t.caption.copyWith(color: c.inkMuted)),
                ],
              ),
            ),
          ),
          if (_busy == null)
            Semantics(
              label: 'Change the file',
              button: true,
              excludeSemantics: true,
              child: AkTextLink('Change', onTap: _choose),
            ),
        ],
      ),
    );
  }

  Widget _contents(BuildContext context, RestorePreview p) {
    final c = context.colors;
    final t = context.type;
    final phoneOnly = p.phoneOnly;
    return AkCard(
      padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3h, vertical: AkSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text('What is in this backup', style: t.title)),
          const SizedBox(height: AkSpace.s2),
          Row(
            children: [
              Expanded(
                child: RestoreStat(
                  figure: p.backupTransactions,
                  label: p.backupTransactions == 1 ? 'transaction' : 'transactions',
                ),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: RestoreStat(
                  figure: p.backupCategories,
                  label: p.backupCategories == 1 ? 'category' : 'categories',
                ),
              ),
              const SizedBox(width: AkSpace.s2),
              Expanded(
                child: RestoreStat(
                  figure: p.backupBudgets,
                  label: p.backupBudgets == 1 ? 'budget' : 'budgets',
                ),
              ),
            ],
          ),
          const SizedBox(height: AkSpace.s3),
          RestoreRangeBars(
            backupFirst: p.backupFirstDay,
            backupLast: p.backupLastDay,
            phoneFirst: p.phoneFirstDay,
            phoneLast: p.phoneLastDay,
          ),
          const SizedBox(height: AkSpace.s1),
          if (p.phoneTransactions == 0)
            Text('This phone has no entries yet.', style: t.bodySm)
          else if (phoneOnly == 0)
            Text('Every entry on this phone is in the backup too.', style: t.bodySm)
          else
            Text.rich(
              TextSpan(
                children: [
                  const TextSpan(text: 'This phone has '),
                  TextSpan(
                    text:
                        '${_entries(phoneOnly)} '
                        '${describeDayRange(p.phoneOnlyFirstDay!, p.phoneOnlyLastDay!)}',
                    style: t.bodySm.copyWith(fontWeight: FontWeight.w600, color: c.ink),
                  ),
                  const TextSpan(text: ' that are not in the backup.'),
                ],
              ),
              style: t.bodySm,
            ),
        ],
      ),
    );
  }

  String _addDetail(RestorePreview p) {
    final keeps = p.phoneOnly > 0 ? 'Keeps your ${_entries(p.phoneOnly)} not in the backup. ' : '';
    if (p.toAdd > 0) return '${keeps}Adds ${_entries(p.toAdd)} from the backup.';
    final newer = p.toUpdate + p.otherChanges;
    if (newer > 0) return '${keeps}Nothing new to add; brings in ${_changes(newer)}.';
    return 'This phone already has everything in the backup.';
  }

  Widget? _action(BuildContext context) {
    if (_done != null) return AkPrimaryButton(label: 'Done', onPressed: () => closeScreen(context));
    if (_busy != null) return null;
    if (_file == null || (_trouble != null && _trouble != _Trouble.restoreFailed)) {
      return AkPrimaryButton(
        label: _file == null ? 'Choose a backup file' : 'Choose another file',
        onPressed: _choose,
      );
    }
    final opened = _opened;
    if (opened == null) {
      if (_header?.isProtected ?? false) {
        return AkPrimaryButton(label: 'Open the backup', onPressed: _open);
      }
      return null;
    }
    final p = opened.preview;
    if (_trouble == _Trouble.restoreFailed) {
      return AkPrimaryButton(label: 'Try again', onPressed: _restore);
    }
    if (_mode == RestoreMode.addMissing) {
      if (p.toAdd > 0) {
        return AkPrimaryButton(label: 'Restore ${_transactions(p.toAdd)}', onPressed: _restore);
      }
      if (p.addMissingChangesSomething) {
        return AkPrimaryButton(label: 'Bring in the newer changes', onPressed: _restore);
      }
      return const AkPrimaryButton(label: 'Nothing to add', onPressed: null);
    }
    return AkPrimaryButton(
      label: p.backupTransactions > 0
          ? 'Restore ${_transactions(p.backupTransactions)}'
          : 'Replace everything',
      onPressed: _restore,
    );
  }
}

String _entries(int n) => n == 1 ? '1 entry' : '$n entries';
String _transactions(int n) => n == 1 ? '1 transaction' : '$n transactions';
String _changes(int n) => n == 1 ? '1 newer change' : '$n newer changes';

/// "12 KB", "0.4 MB".
String _size(int bytes) {
  if (bytes < 100 * 1024) return '${(bytes / 1024).ceil()} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}

class _BusyNote extends StatelessWidget {
  const _BusyNote(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          SizedBox(
            width: AkSize.icon,
            height: AkSize.icon,
            child: CircularProgressIndicator(strokeWidth: AkSize.stroke, color: c.brandBright),
          ),
          const SizedBox(width: AkSpace.s3),
          Expanded(child: Text(text, style: context.type.bodyMd)),
        ],
      ),
    );
  }
}

/// Step 3: what the restore did.
class _DoneNote extends StatelessWidget {
  const _DoneNote({required this.mode, required this.preview});
  final RestoreMode mode;
  final RestorePreview preview;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final p = preview;
    final String body;
    if (mode == RestoreMode.replaceAll) {
      body =
          'This phone now holds the backup: ${_entries(p.backupTransactions)}, '
          '${p.backupCategories} categories and ${p.backupBudgets} budgets.';
    } else {
      final parts = [
        if (p.toAdd > 0) 'Added ${_entries(p.toAdd)} from the backup.',
        if (p.toUpdate > 0) 'Brought in ${_changes(p.toUpdate)}.',
        if (p.phoneOnly > 0) 'Your ${_entries(p.phoneOnly)} not in the backup are as they were.',
      ];
      body = parts.isEmpty
          ? 'Your categories and settings were brought up to date.'
          : parts.join(' ');
    }
    return Semantics(
      liveRegion: true,
      container: true,
      child: AkCard(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AkIconTile(icon: AkIcons.check, background: c.surfaceSunk, foreground: c.brandText),
            const SizedBox(width: AkSpace.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(header: true, child: Text('Restore finished', style: t.title)),
                  const SizedBox(height: AkSpace.s1),
                  Text(body, style: t.body),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
