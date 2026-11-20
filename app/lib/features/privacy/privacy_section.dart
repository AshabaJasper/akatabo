import 'package:flutter/foundation.dart' show defaultTargetPlatform;
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
import '../lock/pin_flow_screen.dart';
import '../settings/settings_page.dart';

/// Privacy and security on Privacy and data (SetPrivacy.html): Lock the app, Unlock with,
/// Lock after, Hide amounts, Blank the screen in the app switcher.
///
/// "Unlock with", "Change PIN" and "Lock after" show only while the lock is on, and "Unlock
/// with" only on a phone with a fingerprint or face set up. "Change PIN" is not drawn
/// (design check).
class PrivacySection extends ConsumerStatefulWidget {
  const PrivacySection({super.key});

  @override
  ConsumerState<PrivacySection> createState() => _PrivacySectionState();
}

class _PrivacySectionState extends ConsumerState<PrivacySection> {
  String? _problem;
  bool _busy = false;

  /// Only Android has the app-switcher handler (MainActivity.kt); the row is left out on
  /// iOS until one is written there, rather than offering a switch that does nothing.
  bool get _blankOffered => defaultTargetPlatform != TargetPlatform.iOS;

  Future<void> _save<T>(SettingKey<T> key, T value) async {
    setState(() => _problem = null);
    try {
      await ref.read(settingsRepositoryProvider).write(key, value);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  Future<void> _switchLock(bool on) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await showPinFlow(context, on ? PinFlow.turnOn : PinFlow.turnOff);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changePin() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    try {
      await showPinFlow(context, PinFlow.change);
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
      return const AkEmptyNote('Privacy settings could not load. Close Akatabo and open it again.');
    }
    final s = settingsAsync.value ?? const <String, String>{};
    T read<T>(SettingKey<T> key) => key.decode(s[key.name]);
    final pinSet = pinAsync.value ?? false;
    final lockOn = read(PrivacyKeys.lockOn) && pinSet;
    final biometrics = ref.watch(biometricsAvailableProvider).value ?? false;
    final lockAfter = read(PrivacyKeys.lockAfter);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SettingsSection(
          label: 'Privacy and security',
          children: [
            SettingsSwitchRow(
              label: 'Lock the app',
              detail: lockOn ? null : 'Ask for a PIN each time Akatabo opens',
              value: lockOn,
              onChanged: _busy ? (_) {} : _switchLock,
              divider: true,
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
            if (lockOn) ...[
              SettingsValueRow(
                title: 'Lock after',
                value: lockAfter.label,
                onTap: () => _pickLockAfter(lockAfter),
                divider: true,
              ),
              SettingsValueRow(
                title: 'Change PIN',
                value: '$pinLength digits',
                onTap: _changePin,
                divider: true,
              ),
            ],
            SettingsSwitchRow(
              label: 'Hide amounts',
              detail: 'Show dots until you tap a figure',
              value: read(PrivacyKeys.hideAmounts),
              onChanged: (v) => _save(PrivacyKeys.hideAmounts, v),
              divider: _blankOffered,
            ),
            if (_blankOffered)
              SettingsSwitchRow(
                label: 'Blank the screen in the app switcher',
                detail: 'So figures do not show in recent apps',
                value: read(PrivacyKeys.blankInSwitcher),
                onChanged: (v) => _save(PrivacyKeys.blankInSwitcher, v),
              ),
          ],
        ),
        if (_problem != null) ...[AkEmptyNote(_problem!), const SizedBox(height: AkSpace.s4)],
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
