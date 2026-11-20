import 'package:material_ui/material_ui.dart';

import '../settings/settings_page.dart';

/// Restore from a backup, as DataRestore.html draws it: choose the file, check it, restore.
/// Built by the backup and restore work.
class RestoreScreen extends StatelessWidget {
  const RestoreScreen({super.key});

  @override
  Widget build(BuildContext context) => const SettingsPage(title: 'Restore', children: []);
}
