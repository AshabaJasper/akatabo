import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_logo.dart';
import '../privacy/about_section.dart';
import 'settings_page.dart';

/// Where the code lives. Shown as text and copied on request: the app has no internet
/// permission, and opening a browser would mean carrying a plugin only for this one link.
const projectUrl = 'https://github.com/AshabaJasper/akatabo';

/// Shown once the project link is on the clipboard.
const linkCopiedMessage = 'Link copied.';

/// About Akatabo: what the app is, the version of this copy, its licence and the project page.
class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  String? _note;

  Future<void> _copyLink() async {
    String message;
    try {
      await Clipboard.setData(const ClipboardData(text: projectUrl));
      message = linkCopiedMessage;
    } on Object {
      message = 'The link could not be copied.';
    }
    if (!mounted) return;
    setState(() => _note = message);
    unawaited(
      SemanticsService.sendAnnouncement(View.of(context), message, Directionality.of(context)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final version = switch (ref.watch(appVersionProvider)) {
      AsyncData(:final value) => value,
      AsyncError() => 'Not known',
      _ => '',
    };
    return SettingsPage(
      title: 'About Akatabo',
      children: [
        // The title already says the name, so the mark stands alone.
        const SizedBox(height: AkSpace.s2),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: AkLogo(style: t.figureXl, on: AkLogoOn.ground, wordmark: false),
        ),
        const SizedBox(height: AkSpace.s4),
        Text(
          'A free money tracker for Uganda that works without the internet. There is no '
          'account and there are no adverts, and the app cannot reach the internet, so your '
          'records stay on your phone.',
          style: t.body.copyWith(color: c.ink),
        ),
        const SizedBox(height: AkSpace.s5),
        SettingsSection(
          label: 'This copy',
          children: [
            SettingsValueRow(title: 'Version', value: version, divider: true),
            const SettingsValueRow(title: 'Licence', value: 'GPL-3.0', divider: true),
            SettingsValueRow(
              title: 'Open-source licences',
              value: '',
              onTap: () => openLicences(context, version),
              divider: true,
            ),
            SettingsValueRow(title: 'Copy project link', value: '', onTap: _copyLink),
          ],
        ),
        if (_note != null) ...[AkEmptyNote(_note!), const SizedBox(height: AkSpace.s4)],
        Text(
          'Akatabo is free software under the GNU General Public License, version 3. You can '
          'read the code, change it and share it. The code is at '
          '${projectUrl.replaceFirst('https://', '')}.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s3),
        Text(
          '"Akatabo" is Luganda for "little book".',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
      ],
    );
  }
}
