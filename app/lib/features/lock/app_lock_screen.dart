import 'dart:math' as math;

import 'package:flutter/services.dart' show HapticFeedback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../app/routes.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../services/security/biometrics.dart';
import '../../services/security/lock_controller.dart';
import '../../services/security/pin_store.dart';
import '../../services/security/privacy_settings.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_pickers.dart';
import '../settings/settings_page.dart';
import '../settings/smart_rows.dart';
import 'pin_flow_screen.dart';

/// App lock, its own page off the Settings hub. Every row is always here: when the lock is
/// off the rows that need it are dimmed, and each one says what it is waiting for.
class AppLockScreen extends StatelessWidget {
  const AppLockScreen({super.key, this.fromPrivacy = false});

  /// Opened from Privacy and data's App lock row, rather than the Settings hub.
  final bool fromPrivacy;

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'App lock',
    backLabel: fromPrivacy ? 'Privacy and data' : 'Settings',
    children: [AppLockSection(fromPrivacy: fromPrivacy)],
  );
}

/// The wrong-try count and the wait left, read from secure storage when the page opens.
final pinTriesProvider = FutureProvider.autoDispose<({int failures, Duration wait})>((ref) async {
  final store = ref.watch(pinStoreProvider);
  final failures = await store.wrongTries();
  final wait = await store.currentWait();
  return (failures: failures, wait: wait);
});

/// The lock rows. The PIN row always shows, so the PIN can be set or changed without hunting
/// for it behind the switch.
class AppLockSection extends ConsumerStatefulWidget {
  const AppLockSection({super.key, this.fromPrivacy = false});

  /// Privacy and data is the page underneath, so its Hide amounts link goes back to it rather
  /// than opening a second copy.
  final bool fromPrivacy;

  @override
  ConsumerState<AppLockSection> createState() => _AppLockSectionState();
}

class _AppLockSectionState extends ConsumerState<AppLockSection> {
  String? _problem;
  String? _done;
  bool _busy = false;

  Future<void> _save<T>(SettingKey<T> key, T value) async {
    setState(() {
      _problem = null;
      _done = null;
    });
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
      _done = null;
    });
    try {
      await showPinFlow(context, flow);
    } finally {
      if (mounted) {
        setState(() => _busy = false);
        ref.invalidate(pinTriesProvider);
      }
    }
  }

  /// Fingerprint or face is saved only after the phone recognises the person once, so the
  /// choice is known to work.
  Future<void> _chooseUnlock(UnlockMethod method) async {
    if (method == UnlockMethod.pin) return _save(PrivacyKeys.unlockWith, method);
    setState(() {
      _problem = null;
      _done = null;
    });
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

  /// Covers the app now. Only offered while the lock is on. The lock screen itself shows that it
  /// worked, so this page leaves no note behind to read stale after unlocking.
  void _lockNow() {
    HapticFeedback.selectionClick();
    setState(() {
      _problem = null;
      _done = null;
    });
    ref.read(lockControllerProvider.notifier).lockNow();
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
    T read<T>(SettingKey<T> key) => readSetting(s, key);
    final pinSet = pinAsync.requireValue;
    final lockOn = read(PrivacyKeys.lockOn) && pinSet;
    final biometrics = ref.watch(biometricsAvailableProvider).value ?? false;
    final lockAfter = read(PrivacyKeys.lockAfter);
    final unlockWith = read(PrivacyKeys.unlockWith);
    final hidden = read(PrivacyKeys.hideAmounts);
    final tries = ref.watch(pinTriesProvider).value;

    final unlockLabel = unlockWith == UnlockMethod.biometric && biometrics
        ? 'fingerprint or face'
        : 'your PIN';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _StatusCard(
          lockOn: lockOn,
          pinSet: pinSet,
          unlockLabel: unlockLabel,
          lockAfterLabel: lockAfter.label,
        ),
        const SizedBox(height: AkSpace.s5),
        SettingsSection(
          label: 'Lock',
          children: [
            SettingsSwitchRow(
              label: 'Lock the app',
              detail: lockOn
                  ? 'Akatabo asks for your PIN when it opens or comes back'
                  : pinSet
                  ? 'Off: Akatabo opens without asking'
                  : 'Turning it on sets your PIN',
              value: lockOn,
              onChanged: _busy ? (_) {} : (on) => _flow(on ? PinFlow.turnOn : PinFlow.turnOff),
              divider: true,
            ),
            // Setting a PIN is the same as switching the lock on: a PIN with the lock off
            // would only be one more thing to forget. A PIN left behind with the lock off
            // (a failed clear) is replaced the same way, never asked for.
            if (lockOn)
              _LockRow(
                title: 'Change PIN',
                value: '$pinLength digits',
                onTap: () => _flow(PinFlow.change),
                divider: true,
              )
            else
              _LockRow(
                title: 'Set a PIN',
                value: '$pinLength digits',
                detail: pinSet
                    ? 'Replaces the PIN stored on this phone'
                    : 'Akatabo asks for it when the lock is on',
                onTap: () => _flow(PinFlow.turnOn),
                divider: true,
              ),
            _LockRow(
              title: 'Lock now',
              chevron: false,
              detail: lockOn ? null : 'Turn on Lock the app first',
              enabled: lockOn,
              onTap: _lockNow,
              divider: true,
            ),
          ],
        ),
        SettingsSection(
          label: 'Unlock',
          children: [
            _SegmentRow(
              label: 'Unlock with',
              enabled: lockOn,
              note: !lockOn
                  ? 'Turn on Lock the app first'
                  : biometrics
                  ? null
                  : 'Fingerprint or face needs one set up in your phone\'s settings first. Until '
                        'then Akatabo unlocks with your PIN.',
              // While the lock is off the choice does nothing, so it is not offered to touch or
              // to a screen reader as if it worked; the note above says why.
              child: IgnorePointer(
                ignoring: !lockOn,
                child: ExcludeSemantics(
                  excluding: !lockOn,
                  child: AkSegmented<UnlockMethod>(
                    semanticLabel: 'Unlock with',
                    segments: const [
                      AkSegment(UnlockMethod.pin, 'PIN'),
                      AkSegment(UnlockMethod.biometric, 'Fingerprint or face'),
                    ],
                    selected: unlockWith,
                    onChanged: lockOn && biometrics && !_busy ? _chooseUnlock : (_) {},
                  ),
                ),
              ),
            ),
            _LockRow(
              title: 'Lock after',
              value: lockAfter.label,
              detail: lockOn ? null : 'Turn on Lock the app first',
              enabled: lockOn,
              onTap: () => _pickLockAfter(lockAfter),
              divider: true,
            ),
            _LockRow(
              title: 'Wrong PIN tries',
              value: tries == null
                  ? ''
                  : tries.wait > Duration.zero
                  ? 'Waiting'
                  : '${math.max(0, PinStore.freeTries - tries.failures)} free',
              detail: tries == null || tries.wait == Duration.zero
                  ? 'After ${PinStore.freeTries} wrong tries, Akatabo waits before the next one: '
                        '30 seconds, then longer, up to an hour.'
                  : 'Try again when the wait is over. Your entries are safe.',
            ),
          ],
        ),
        SettingsSection(
          label: 'Figures',
          children: [
            SettingsValueRow(
              title: 'Hide amounts',
              value: hidden ? 'On' : 'Off',
              onTap: () =>
                  widget.fromPrivacy ? closeScreen(context) : context.push(Routes.settingsPrivacy),
            ),
          ],
        ),
        if (_problem != null) ...[AkEmptyNote(_problem!), const SizedBox(height: AkSpace.s4)],
        if (_done != null) ...[AkEmptyNote(_done!), const SizedBox(height: AkSpace.s4)],
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

/// What the lock is doing, in one card at the top.
class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.lockOn,
    required this.pinSet,
    required this.unlockLabel,
    required this.lockAfterLabel,
  });

  final bool lockOn;
  final bool pinSet;
  final String unlockLabel;
  final String lockAfterLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final m = context.metrics;
    final headline = lockOn
        ? 'Locked when you leave'
        : pinSet
        ? 'Lock is off'
        : 'No PIN yet';
    final detail = lockOn
        ? 'Unlocks with $unlockLabel. Lock after: $lockAfterLabel.'
        : pinSet
        ? 'Turn on Lock the app to ask for your PIN.'
        : 'Set a PIN, then turn on Lock the app.';
    return Container(
      padding: const EdgeInsets.all(AkSpace.s4),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(m.md),
        border: Border.all(color: c.line),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: lockOn ? c.brand : c.switchOff,
              shape: BoxShape.circle,
            ),
            child: const SizedBox(width: AkSpace.s3, height: AkSpace.s3),
          ),
          const SizedBox(width: AkSpace.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(headline, style: t.title.copyWith(color: c.ink)),
                const SizedBox(height: AkSpace.s1),
                Text(detail, style: t.bodySm.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A settings row that can be dimmed: when [enabled] is false it reads as waiting, and its
/// [detail] says what it waits for. A row with no [onTap] is information only.
class _LockRow extends StatelessWidget {
  const _LockRow({
    required this.title,
    this.value,
    this.detail,
    this.onTap,
    this.enabled = true,
    this.divider = false,
    this.chevron = true,
  });

  final String title;
  final String? value;
  final String? detail;
  final VoidCallback? onTap;
  final bool enabled;
  final bool divider;

  /// A chevron when the row opens something; an action such as Lock now has none.
  final bool chevron;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final ink = enabled ? c.ink : c.inkMuted;
    final row = Container(
      constraints: const BoxConstraints(minHeight: AkSize.row),
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s2h),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            )
          : null,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.bodyMd.copyWith(color: ink)),
                if (detail != null) Text(detail!, style: t.caption.copyWith(color: c.inkMuted)),
              ],
            ),
          ),
          if (value != null && value!.isNotEmpty) ...[
            const SizedBox(width: AkSpace.s3),
            Text(value!, style: t.bodyMd.copyWith(color: c.inkMuted)),
          ],
          if (onTap != null && chevron) ...[
            const SizedBox(width: AkSpace.s2),
            AkIcon(AkIcons.chevron, color: c.inkMuted, size: AkSize.iconSm),
          ],
        ],
      ),
    );
    if (onTap == null || !enabled) return row;
    return Semantics(
      button: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(onTap: onTap, child: row),
      ),
    );
  }
}

/// A label above a segmented choice, dimmed while [enabled] is false, with a note under it
/// when there is one.
class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.label, required this.child, this.enabled = true, this.note});

  final String label;
  final Widget child;
  final bool enabled;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: c.line)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ExcludeSemantics(
            child: Text(label, style: t.bodyMd.copyWith(color: enabled ? c.ink : c.inkMuted)),
          ),
          const SizedBox(height: AkSpace.s2),
          child,
          if (note != null) ...[
            const SizedBox(height: AkSpace.s2),
            Text(note!, style: t.caption.copyWith(color: c.inkMuted)),
          ],
        ],
      ),
    );
  }
}
