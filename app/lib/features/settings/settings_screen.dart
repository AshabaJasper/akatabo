import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/routes.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_surfaces.dart';
import '../placeholder/placeholder_screen.dart';

/// The Settings tab: a list of the pages, each with a line saying what it holds.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const rows = <_Entry>[
      _Entry('General', 'Currency, language, dates, number style', Routes.settingsGeneral),
      _Entry('Accounts', 'Cash, MTN MoMo, Airtel Money, bank', Routes.settingsAccounts),
      _Entry('Categories', 'Names, icons, colours, order, budgets', Routes.settingsCategories),
      _Entry('Appearance', 'Theme, colours, text size, charts', Routes.settingsAppearance),
      _Entry('Home screen', 'Choose the cards and their order', Routes.settingsHome),
      _Entry('Smart help', 'Suggestions, forecast, unusual payments', null),
      _Entry('Reminders', 'Daily nudge, budget warnings, weekly summary', null),
      _Entry('Privacy and security', 'App lock, hidden amounts', null),
      _Entry('Data and backup', 'Export, back up, restore, delete', null),
    ];
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s4, AkSpace.s6, AkSpace.s6),
          children: [
            Semantics(header: true, child: Text('Settings', style: context.type.displayLg)),
            const SizedBox(height: AkSpace.s4),
            AkCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  for (var i = 0; i < rows.length; i++)
                    AkListRow(
                      title: rows[i].title,
                      subtitle: rows[i].subtitle,
                      divider: i < rows.length - 1,
                      onTap: () => _open(context, rows[i]),
                    ),
                ],
              ),
            ),
            const SizedBox(height: AkSpace.s4),
            Text(
              'Free, with no account and no adverts.',
              style: context.type.caption.copyWith(color: context.colors.ink),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Pages built so far are routes; the rest open their placeholder until their phase builds them.
  void _open(BuildContext context, _Entry e) {
    if (e.route != null) {
      context.push(e.route!);
    } else {
      Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => PlaceholderScreen(title: e.title, closable: true)),
      );
    }
  }
}

class _Entry {
  const _Entry(this.title, this.subtitle, this.route);
  final String title;
  final String subtitle;
  final String? route;
}
