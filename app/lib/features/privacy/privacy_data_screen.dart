import 'package:material_ui/material_ui.dart';

import '../data/data_section.dart';
import '../settings/settings_page.dart';
import 'about_section.dart';
import 'privacy_section.dart';

/// Privacy and data, as SetPrivacy.html draws it: Privacy and security, Data and backup, and
/// About, each in its own file so they can be built separately. The hub's "Data and backup"
/// row opens the page at that section.
class PrivacyDataScreen extends StatefulWidget {
  const PrivacyDataScreen({super.key, this.openAtData = false});

  /// Scrolls to Data and backup once the page is drawn.
  final bool openAtData;

  @override
  State<PrivacyDataScreen> createState() => _PrivacyDataScreenState();
}

class _PrivacyDataScreenState extends State<PrivacyDataScreen> {
  final _dataKey = GlobalKey();

  @override
  void initState() {
    super.initState();
    if (widget.openAtData) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final target = _dataKey.currentContext;
        if (target != null && target.mounted) Scrollable.ensureVisible(target);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SettingsPage(
      title: 'Privacy and data',
      children: [
        const PrivacySection(),
        KeyedSubtree(key: _dataKey, child: const DataSection()),
        const AboutSection(),
      ],
    );
  }
}
