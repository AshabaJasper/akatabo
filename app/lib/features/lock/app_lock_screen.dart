import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../services/security/biometrics.dart';
import '../../services/security/lock_controller.dart';
import '../../services/security/privacy_settings.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_pickers.dart';
import '../settings/settings_page.dart';
import 'pin_flow_screen.dart';

/// App lock, its own page off the Settings hub: Lock the app, the PIN, Unlock with and Lock
/// after. The rows are SetPrivacy.html's lock rows; the page around them is undrawn and
/// flagged for a design check.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key, this.backLabel = 'Settings'});

  /// The page the person came from: the Settings hub, or Privacy and data's App lock row.
  final String backLabel;

  @override
  Widget build(BuildContext context) =>
      SettingsPage(title: 'App lock', backLabel: backLabel, children: const [AppLockSection()]);
}

/// The lock rows. The PIN row always shows, so the PIN can be set or changed without hunting
/// for it behind the switch.
class AppLockSection extends ConsumerStatefulWidget {
  const AppLockSection({super.key});

  @override
  ConsumerState<AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends ConsumerState<AppLockSection> {
  String? _problem;
  bool _busy = false;

  Future<void> _save<T>(SettingKey<T> key, T value) async {
    setState(() => _problem = null);
    try {
      await ref.read(settingsRepositoryProvider).write(key, value);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  /// One PIN screen at a time: a second tap while one is open does nothing.
  Future<void> _flow(PinFlow flow) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await showPinFlow(context, flow);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Fingerprint or face is saved only after the phone recognises the person once, so the
  /// choice is known to work.
  Future<void> _chooseUnlock(UnlockMethod method) async {
    if (method == UnlockMethod.pin) return _save(PrivacyKeys.unlockWith, method);
    setState(() => _problem = null);
    final result = await ref
        .read(lockControllerProvider.notifier)
        .keepUnlockedWhile(
          () => ref
              .read(biometricsProvider)
              .authenticate('Use your fingerprint or face to unlock Akatabo'),
        );
    if (!mounted) return;
    switch (result) {
      case BiometricResult.passed:
        await _save(PrivacyKeys.unlockWith, method);
      case BiometricResult.failed:
        setState(() => _problem = 'Not recognised, so Akatabo still unlocks with your PIN.');
      case BiometricResult.unavailable:
        setState(
          () => _problem =
              'Fingerprint or face is not available right now, so Akatabo still unlocks with '
              'your PIN.',
        );
    }
  }

  Future<void> _pickLockAfter(LockAfter current) async {
    final picked = await showAkChoiceSheet<LockAfter>(
      context,
      title: 'Lock after',
      note: 'How long Akatabo can be out of sight before it asks for your PIN again.',
      options: [for (final a in LockAfter.values) (a, a.label)],
      selected: current,
    );
    if (picked != null) await _save(PrivacyKeys.lockAfter, picked);
  }

  @override
  Widget build(BuildContext context) {
    final settingsAsync = ref.watch(storedSettingsProvider);
    final pinAsync = ref.watch(pinIsSetProvider);
    // Defaults would show the lock as off when it is on, so a failed load says so instead.
    if ((settingsAsync.hasError && !settingsAsync.hasValue) ||
        (pinAsync.hasError && !pinAsync.hasValue)) {
      return const AkEmptyNote(
        'The lock settings could not load. Close Akatabo and open it again.',
      );
    }
    // Until both are known the rows wait: guessing "no PIN" would offer Set a PIN, which
    // replaces a stored PIN without asking for it.
    if (!settingsAsync.hasValue || !pinAsync.hasValue) {
      return const SizedBox(height: AkSize.row * 3);
    }
    final s = settingsAsync.requireValue;
    T read<T>(SettingKey<T> key) => key.decode(s[key.name]);
    final lockOn = read(PrivacyKeys.lockOn) && pinAsync.requireValue;
    final biometrics = ref.watch(biometricsAvailableProvider).value ?? false;
    final lockAfter = read(PrivacyKeys.lockAfter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          label: 'App lock',
          children: [
            SettingsSwitchRow(
              label: 'Lock the app',
              detail: lockOn ? null : 'Ask for a PIN each time Akatabo opens',
              value: lockOn,
              onChanged: _busy ? (_) {} : (on) => _flow(on ? PinFlow.turnOn : PinFlow.turnOff),
              divider: true,
            ),
            // Setting a PIN is the same as switching the lock on: a PIN with the lock off
            // would only be one more thing to forget. A PIN left behind with the lock off
            // (a failed clear) is replaced the same way, never asked for.
            if (lockOn)
              SettingsValueRow(
                title: 'Change PIN',
                value: '$pinLength digits',
                onTap: () => _flow(PinFlow.change),
                divider: true,
              )
            else
              SettingsValueRow(
                title: 'Set a PIN',
                value: '$pinLength digits',
                onTap: () => _flow(PinFlow.turnOn),
              ),
            if (lockOn && biometrics)
              _SegmentRow(
                label: 'Unlock with',
                child: AkSegmented<UnlockMethod>(
                  semanticLabel: 'Unlock with',
                  segments: const [
                    AkSegment(UnlockMethod.pin, 'PIN'),
                    AkSegment(UnlockMethod.biometric, 'Fingerprint or face'),
                  ],
                  selected: read(PrivacyKeys.unlockWith),
                  onChanged: _chooseUnlock,
                ),
              ),
            if (lockOn)
              SettingsValueRow(
                title: 'Lock after',
                value: lockAfter.label,
                onTap: () => _pickLockAfter(lockAfter),
              ),
          ],
        ),
        if (_problem != null) ...[AkEmptyNote(_problem!), const SizedBox(height: AkSpace.s4)],
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: settingsRowSide),
          child: Text(
            'Akatabo has no account to reset a PIN through. If you forget it, the only way '
            'back in is to delete everything on this phone, then restore a backup file.',
            style: context.type.bodySm.copyWith(color: context.colors.inkMuted),
          ),
        ),
        const SizedBox(height: AkSpace.s5),
      ],
    );
  }
}

/// A label above a segmented choice, with a line under it, as "Unlock with" is drawn.
class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.colors.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(child: Text(label, style: context.type.bodyMd)),
          const SizedBox(height: AkSpace.s2),
          child,
        ],
      ),
    );
  }
}
