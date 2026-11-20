import 'package:material_ui/material_ui.dart';

import '../settings/settings_page.dart';

/// Privacy and security on Privacy and data: Lock the app, Unlock with, Lock after, Hide
/// amounts, Blank the screen in the app switcher. Built by the lock and privacy work.
class PrivacySection extends StatelessWidget {
  const PrivacySection({super.key});

  @override
  Widget build(BuildContext context) =>
      const SettingsSection(label: 'Privacy and security', children: []);
}
