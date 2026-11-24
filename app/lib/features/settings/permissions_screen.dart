import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../services/notifications/notifications_service.dart';
import '../../services/permissions/phone_permissions.dart';
import '../../services/security/biometrics.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import 'settings_page.dart';
import 'smart_rows.dart';

/// Shown when the phone's settings page could not be opened.
const settingsNotOpenedMessage =
    "The phone's settings could not be opened. Open them yourself, then Apps, then Akatabo.";

const _notifications = 'android.permission.POST_NOTIFICATIONS';
const _biometric = 'android.permission.USE_BIOMETRIC';

/// Phone permissions: what the phone has allowed Akatabo, read live, and what Akatabo never
/// asks for. Each row opens the phone's own settings page; nothing is changed from here.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  /// Null until known.
  bool? _notificationsAllowed;

  /// Null until known, and where the phone cannot list them (iOS).
  Map<String, bool>? _requested;
  bool _loaded = false;
  String? _problem;
  late final AppLifecycleListener _life;

  @override
  void initState() {
    super.initState();
    // Read again each time Akatabo comes back, since the rows send the person to the phone's
    // settings to change things.
    _life = AppLifecycleListener(onResume: _check);
    _check();
  }

  @override
  void dispose() {
    _life.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    ref.invalidate(biometricsAvailableProvider);
    bool? allowed;
    try {
      allowed = await ref.read(notificationsServiceProvider).areAllowed();
    } on Object {
      allowed = null;
    }
    final requested = await ref.read(phonePermissionsProvider).requested();
    if (!mounted) return;
    setState(() {
      _notificationsAllowed = allowed;
      _requested = requested;
      _loaded = true;
    });
  }

  Future<void> _open(PhoneSettingsPage page) async {
    setState(() => _problem = null);
    final opened = await ref.read(phonePermissionsProvider).open(page);
    if (!opened && mounted) setState(() => _problem = settingsNotOpenedMessage);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final biometrics = ref.watch(biometricsAvailableProvider);
    final requested = _requested;
    final others = [
      if (requested != null)
        for (final e in requested.entries)
          if (e.key != _notifications && e.key != _biometric) e,
    ];
    final never = requested == null ? const <String>[] : neverAskedFor(requested.keys);

    return SettingsPage(
      title: 'Phone permissions',
      children: [
        Text(
          'What this phone allows Akatabo, checked each time you come back to the app. '
          "Tap a row to change it in the phone's settings.",
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s5),
        SettingsSection(
          label: 'Asked for',
          children: [
            _PermissionRow(
              name: 'Notifications',
              use: permissionWords(_notifications).use,
              state: switch (_notificationsAllowed) {
                null => _loaded ? 'Unknown' : 'Checking',
                true => 'Allowed',
                false => 'Blocked',
              },
              warn: _notificationsAllowed == false,
              onTap: () => _open(PhoneSettingsPage.notifications),
              divider: true,
            ),
            _PermissionRow(
              name: 'Fingerprint or face',
              use: permissionWords(_biometric).use,
              state: switch (biometrics) {
                AsyncData(value: true) => 'Ready',
                AsyncData(value: false) => 'None added',
                _ => 'Checking',
              },
              onTap: () => _open(PhoneSettingsPage.biometrics),
              divider: others.isNotEmpty,
            ),
            for (final (i, e) in others.indexed)
              _PermissionRow(
                name: permissionWords(e.key).name,
                use: permissionWords(e.key).use,
                state: e.value ? 'Allowed' : 'Not allowed',
                onTap: () => _open(PhoneSettingsPage.app),
                divider: i < others.length - 1,
              ),
          ],
        ),
        if (never.isNotEmpty) ...[
          const AkEyebrow('Never asked for'),
          const SizedBox(height: AkSpace.s2),
          Text(
            'Akatabo never asks for ${joinWords(never)}. Backups and exports go through the '
            "phone's own file picker and share sheet, so no storage permission is needed.",
            style: t.body.copyWith(color: c.ink),
          ),
          const SizedBox(height: AkSpace.s6),
        ],
        AkCard(
          padding: EdgeInsets.zero,
          child: ActionRow(
            label: 'Open Akatabo in phone settings',
            onTap: () => _open(PhoneSettingsPage.app),
            destructive: false,
          ),
        ),
        if (_problem != null) ...[const SizedBox(height: AkSpace.s3), AkEmptyNote(_problem!)],
      ],
    );
  }
}

/// One permission: its name and use on the left, its state on the right. The whole row opens
/// the phone's settings page for it.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.name,
    required this.use,
    required this.state,
    required this.onTap,
    this.warn = false,
    this.divider = false,
  });

  final String name;
  final String use;
  final String state;
  final VoidCallback onTap;

  /// Draws the state as a problem (Blocked).
  final bool warn;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      label: '$name, $state. $use',
      hint: "Opens the phone's settings",
      excludeSemantics: true,
      container: true,
      // excludeSemantics drops the row's own tap action, so it is given back here.
      onTap: onTap,
      child: AkListRow(
        title: name,
        subtitle: use,
        divider: divider,
        onTap: onTap,
        padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s2),
        trailing: Text(
          state,
          style: context.type.body.copyWith(
            color: warn ? c.moneyOut : c.inkMuted,
            fontWeight: warn ? FontWeight.w600 : null,
          ),
        ),
      ),
    );
  }
}
