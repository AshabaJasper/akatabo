import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';

/// Whether the person has been through Onboarding and Welcome. Read once at start-up to
/// choose the first screen; settings are already loaded before the first frame.
final onboardingDoneProvider = Provider<bool>((ref) {
  final stored = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
  return SettingKeys.onboardingDone.decode(stored[SettingKeys.onboardingDone.name]);
});

/// Marks Onboarding as done, so the next launch opens on Home.
Future<void> finishOnboarding(WidgetRef ref) =>
    ref.read(settingsRepositoryProvider).write(SettingKeys.onboardingDone, true);
