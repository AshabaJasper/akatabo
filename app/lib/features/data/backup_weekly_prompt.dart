import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/backup/weekly_backup.dart';
import 'backup_actions.dart';

/// Starts the weekly backup check: once now, at start-up, and again each time the app comes
/// back to the front, since a phone can keep the app in memory for weeks. It lasts as long as
/// [container], the app's lifetime.
///
/// When the backup is due and the folder must be picked again (always so after a restart),
/// the person is asked over whatever screen is showing, once the first frame is drawn.
void startWeeklyBackupChecks(ProviderContainer container) {
  container.read(_weeklyCheckProvider).check();
}

final _weeklyCheckProvider = Provider<_WeeklyCheck>((ref) {
  final check = _WeeklyCheck(ref.container);
  ref.onDispose(check.dispose);
  return check;
});

class _WeeklyCheck {
  _WeeklyCheck(ProviderContainer container) {
    _checks = WeeklyBackupChecks(container, ask: _ask);
    _lifecycle = AppLifecycleListener(onResume: check);
  }

  late final WeeklyBackupChecks _checks;
  late final AppLifecycleListener _lifecycle;

  Future<void> check() => _checks.check();

  Future<void> _ask() async {
    await WidgetsBinding.instance.endOfFrame;
    final navigator = findRootNavigator();
    if (navigator == null || !navigator.mounted) return;
    await showWeeklyBackupDue(navigator.context);
  }

  void dispose() => _lifecycle.dispose();
}

/// The app's outermost navigator, found from the top of the widget tree. The start-up code
/// sits above the app and has no screen of its own to ask from.
NavigatorState? findRootNavigator() {
  NavigatorState? found;
  void visit(Element element) {
    if (found != null) return;
    if (element is StatefulElement && element.state is NavigatorState) {
      found = element.state as NavigatorState;
      return;
    }
    element.visitChildren(visit);
  }

  WidgetsBinding.instance.rootElement?.visitChildren(visit);
  return found;
}

/// "Time for this week's backup": asks the person to pick the folder again, then backs up.
/// Not drawn; built from the dialog rules (design check).
Future<void> showWeeklyBackupDue(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (_) => const WeeklyBackupDueDialog(),
);

class WeeklyBackupDueDialog extends ConsumerStatefulWidget {
  const WeeklyBackupDueDialog({super.key});

  @override
  ConsumerState<WeeklyBackupDueDialog> createState() => _WeeklyBackupDueDialogState();
}

class _WeeklyBackupDueDialogState extends ConsumerState<WeeklyBackupDueDialog> {
  bool _working = false;

  Future<void> _pick() async {
    final navigator = Navigator.of(context);
    final (_, message) = await BackupActions(ref)
        .backupIntoPickedFolder(context, onWorking: () => setState(() => _working = true));
    if (!mounted) return;
    setState(() => _working = false);
    navigator.pop();
    showBackupMessage(navigator.context, message);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Time for this week's backup"),
      content: Text(
        _working
            ? 'Saving the backup…'
            : 'Akatabo cannot keep the folder you picked once it is closed. Pick it again '
                  'to save this week\'s backup there. Not now asks again the next time you '
                  'open Akatabo.',
      ),
      actions: [
        TextButton(
          onPressed: _working ? null : () => Navigator.of(context).pop(),
          child: const Text('Not now'),
        ),
        TextButton(onPressed: _working ? null : _pick, child: const Text('Pick the folder')),
      ],
    );
  }
}
