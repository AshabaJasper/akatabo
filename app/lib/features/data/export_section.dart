import 'package:material_ui/material_ui.dart';

/// Export to read or share, on Export and back up: format, period, what to include, and the
/// export button. Built by the export work. [startOnPdf] opens it on the PDF report.
class ExportSection extends StatelessWidget {
  const ExportSection({super.key, this.startOnPdf = false});

  final bool startOnPdf;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
