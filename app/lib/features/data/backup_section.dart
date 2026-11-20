import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../services/backup/backup_settings.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import '../settings/settings_page.dart';
import 'backup_actions.dart';

/// Back up everything, and Restore from a backup, on Export and back up (DataExport.html).
class BackupSection extends ConsumerStatefulWidget {
  const BackupSection({super.key});

  @override
  ConsumerState<BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends ConsumerState<BackupSection> {
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

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
    final protect = BackupKeys.protect.decode(s[BackupKeys.protect.name]);
    final weekly = BackupKeys.weekly.decode(s[BackupKeys.weekly.name]);
    final last = formatBackupDay(BackupKeys.lastAt.decode(s[BackupKeys.lastAt.name]));

    return Padding(
      padding: const EdgeInsets.only(bottom: AkSpace.s6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AkEyebrow('Back up everything'),
          const SizedBox(height: AkSpace.s2),
          AkCard(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border(bottom: BorderSide(color: c.line)),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: settingsRowSide,
                    vertical: AkSpace.s3,
                  ),
                  child: Text(
                    'One file holding every transaction, category, budget and setting. Keep '
                    'it somewhere other than this phone, then restore it on any phone.',
                    style: t.bodySm.copyWith(color: c.inkMuted),
                  ),
                ),
                SettingsSwitchRow(
                  label: 'Protect with a password',
                  detail: 'Nobody can open the file without it',
                  value: protect,
                  divider: true,
                  onChanged: (v) => BackupActions(ref).setProtect(v),
                ),
                SettingsSwitchRow(
                  label: 'Back up by itself every week',
                  detail: 'To a folder you pick. Last backup: $last',
                  value: weekly,
                  divider: true,
                  onChanged: (v) {
                    if (_working) return;
                    _run((a) => a.setWeekly(context, v, onWorking: _busy));
                  },
                ),
                Padding(
                  padding: const EdgeInsets.all(settingsRowSide),
                  child: AkOutlineButton(
                    label: _working ? 'Saving the backup…' : 'Save a backup file now',
                    ink: c.brandText,
                    onPressed: _working
                        ? null
                        : () => _run((a) => a.saveNow(context, onWorking: _busy)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AkSpace.s3),
          AkCard(
            padding: const EdgeInsets.symmetric(horizontal: settingsRowSide),
            semanticLabel: 'Restore from a backup. Bring your data back, or move to a new phone',
            onTap: () => context.push(Routes.dataRestore),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: AkSize.row),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    AkIconTile(
                      icon: AkIcons.upload,
                      background: c.surfaceSunk,
                      foreground: c.brandText,
                    ),
                    const SizedBox(width: AkSpace.s3),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: AkSpace.s2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Restore from a backup',
                              style: t.bodyMd.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              'Bring your data back, or move to a new phone',
                              style: t.caption.copyWith(color: c.inkMuted),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: AkSpace.s3),
                    AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
