import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_logo.dart';
import '../settings/settings_page.dart';

/// The version and build of this copy of Akatabo, as "1.0.0 (1)".
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return info.buildNumber.isEmpty ? info.version : '${info.version} (${info.buildNumber})';
});

/// About on Privacy and data (SetPrivacy.html): Version and Open-source licences.
///
/// The drawn "Privacy policy" and "Send feedback" rows are left out until the owner
/// supplies the policy and a contact (launch blockers in SHIP_GATE.md): a row that opens
/// nothing would be worse than no row.
class AboutSection extends ConsumerWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = switch (ref.watch(appVersionProvider)) {
      AsyncData(:final value) => value,
      AsyncError() => 'Not known',
      _ => '',
    };
    return SettingsSection(
      label: 'About',
      children: [
        SettingsValueRow(title: 'Version', value: version, divider: true),
        SettingsValueRow(
          title: 'Open-source licences',
          value: '',
          onTap: () => openLicences(context, version),
        ),
      ],
    );
  }
}

/// The licences of Akatabo and of every package it uses, on the stock licence page.
void openLicences(BuildContext context, String version) => showLicensePage(
  context: context,
  applicationName: 'Akatabo',
  applicationVersion: version.isEmpty ? null : version,
  applicationIcon: Padding(
    padding: const EdgeInsets.all(8),
    child: AkLogo(style: context.type.figureXl, on: AkLogoOn.ground, wordmark: false),
  ),
);
