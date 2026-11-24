import 'dart:async';

import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../../widgets/ak_surfaces.dart';
import '../privacy/about_section.dart';
import 'settings_entries.dart';
import 'settings_page.dart';
import 'settings_search.dart';

/// The Settings tab (Settings.html): a search field, then the pages in three groups, each row
/// with a tile, a name, a line saying what it holds and a chevron.
///
/// The search field is undrawn (flagged in PLAN.md). Typing keeps only the matching rows, in
/// their own cards; a card with no match is left out.
/// Short enough to fit on one line at 1.3 times text size on a 390px phone.
const settingsSearchHint = 'Reminders, backup, PIN';

const _announceDelay = Duration(milliseconds: 500);

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  /// Holds the search words in this State, next to the filter, so the field and the list
  /// cannot disagree when the field scrolls out of the list and is rebuilt.
  final _search = TextEditingController();
  Timer? _announceTimer;

  @override
  void dispose() {
    _announceTimer?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String _) {
    setState(() {});
    // Says how many pages are left once typing pauses, so a screen reader user hears the
    // result without each key interrupting the last.
    _announceTimer?.cancel();
    _announceTimer = Timer(_announceDelay, () {
      if (!mounted) return;
      final count = filterSettings(settingsEntries, _search.text).length;
      final message = switch (count) {
        0 => 'No settings match',
        1 => '1 setting',
        _ => '$count settings',
      };
      SemanticsService.sendAnnouncement(View.of(context), message, TextDirection.ltr);
    });
  }

  /// Leaves the search field before opening a page, so the keyboard does not come back up
  /// over the results when the person returns.
  void _open(String route) {
    FocusManager.instance.primaryFocus?.unfocus();
    context.push(route);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // The version appears once it is known; until then, and if it cannot be read, the line
    // is the same without it.
    final version = ref.watch(appVersionProvider).value;
    final footer = version == null || version.isEmpty
        ? 'Free, with no account and no adverts.'
        : 'Akatabo $version. Free, with no account and no adverts.';
    final shown = filterSettings(settingsEntries, _search.text);
    final groups = <List<SettingsEntry>>[
      for (final g in {for (final e in shown) e.group}) [...shown.where((e) => e.group == g)],
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s4, AkSpace.s6, AkSpace.s6),
          children: [
            Semantics(header: true, child: Text('Settings', style: context.type.displayLg)),
            const SizedBox(height: AkSpace.s4),
            // Merged, so TalkBack reads the name on the edit box itself, not only its hint.
            MergeSemantics(
              child: AkTextField(
                label: 'Search settings',
                hint: settingsSearchHint,
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(height: AkSpace.s4),
            // The result count, including none, is announced from _onSearch.
            if (groups.isEmpty)
              const AkEmptyNote('No settings match. Try another word.')
            else
              for (final group in groups) ...[
                AkCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < group.length; i++)
                        _SettingsRow(
                          entry: group[i],
                          divider: i < group.length - 1,
                          onTap: () => _open(group[i].route),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: AkSpace.s3),
              ],
            const SizedBox(height: AkSpace.s1),
            Text(
              footer,
              style: context.type.caption.copyWith(color: c.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsRow extends StatelessWidget {
  const _SettingsRow({required this.entry, required this.divider, required this.onTap});

  final SettingsEntry entry;
  final bool divider;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      container: true,
      excludeSemantics: true,
      label: '${entry.label}, ${entry.description}',
      onTap: onTap,
      child: AkListRow(
        leading: AkIconTile(
          icon: entry.icon,
          background: c.surfaceSunk,
          foreground: c.brandText,
          iconSize: AkSize.icon,
        ),
        title: entry.label,
        subtitle: entry.description,
        titleWeight: FontWeight.w600,
        trailing: AkIcon(AkIcons.chevron, size: AkSize.iconSm, color: c.inkMuted),
        divider: divider,
        padding: const EdgeInsets.symmetric(horizontal: settingsRowSide),
        onTap: onTap,
      ),
    );
  }
}
