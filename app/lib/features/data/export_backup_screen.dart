import 'package:material_ui/material_ui.dart';

import '../settings/settings_page.dart';
import 'backup_section.dart';
import 'export_section.dart';

/// Export and back up, as DataExport.html draws it. The export part and the backup part live
/// in their own files so they can be built separately.
class ExportBackupScreen extends StatelessWidget {
  const ExportBackupScreen({super.key, this.startOnPdf = false});

  /// Opens the export part on the PDF report ("Export a monthly report").
  final bool startOnPdf;

  @override
  Widget build(BuildContext context) => SettingsPage(
    title: 'Export and back up',
    children: [
      ExportSection(startOnPdf: startOnPdf),
      const BackupSection(),
    ],
  );
}
