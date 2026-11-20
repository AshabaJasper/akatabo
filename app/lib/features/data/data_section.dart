import 'package:material_ui/material_ui.dart';

import '../settings/settings_page.dart';

/// Data and backup on Privacy and data: Export and back up, Export a monthly report, Save a
/// backup file now, Back up every week, Restore from a backup file, Delete everything on this
/// phone. Built by the backup and restore work.
class DataSection extends StatelessWidget {
  const DataSection({super.key});

  @override
  Widget build(BuildContext context) =>
      const SettingsSection(label: 'Data and backup', children: []);
}
