import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/appearance.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/tokens.g.dart';
import '../../data/providers.dart';
import '../../data/settings/setting_keys.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import 'settings_page.dart';

String _capitalised(String name) => '${name[0].toUpperCase()}${name.substring(1)}';

/// Theme, main colour, text size, corners and the category chart. Each change is saved at
/// once and rebuilds the app's theme, because the app reads these from storage (see
/// storedAppearanceProvider and categoryChartProvider).
class AppearanceSettingsScreen extends ConsumerStatefulWidget {
  const AppearanceSettingsScreen({super.key});

  @override
  ConsumerState<AppearanceSettingsScreen> createState() => _AppearanceSettingsScreenState();
}

class _AppearanceSettingsScreenState extends ConsumerState<AppearanceSettingsScreen> {
  String? _problem;

  Future<void> _save<T>(SettingKey<T> key, T value) async {
    setState(() => _problem = null);
    try {
      await ref.read(settingsRepositoryProvider).write(key, value);
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(storedSettingsProvider);
    if (settings.hasError) {
      return const SettingsPage(
        title: 'Appearance',
        children: [AkEmptyNote('Appearance could not load. Close Akatabo and open it again.')],
      );
    }
    if (!settings.hasValue) return const SettingsPage(title: 'Appearance', children: []);
    final look = ref.watch(storedAppearanceProvider);
    final chart = ref.watch(categoryChartProvider);

    return SettingsPage(
      title: 'Appearance',
      children: [
        SettingsSection(
          label: 'Look',
          children: [
            _ChoiceRow(
              label: 'Theme',
              child: AkSegmented<ThemeMode>(
                semanticLabel: 'Theme',
                segments: const [
                  AkSegment(ThemeMode.light, 'Light'),
                  AkSegment(ThemeMode.dark, 'Dark'),
                  AkSegment(ThemeMode.system, 'Follow phone'),
                ],
                selected: look.themeMode,
                onChanged: (v) => _save(SettingKeys.theme, v),
              ),
            ),
            _ChoiceRow(
              label: 'Main colour',
              child: _MainColours(
                selected: paletteById(look.paletteId).id,
                onChanged: (id) => _save(SettingKeys.mainColour, id),
              ),
            ),
            _ChoiceRow(
              label: 'Text size',
              child: AkSegmented<AkTextSize>(
                semanticLabel: 'Text size',
                segments: [for (final v in AkTextSize.values) AkSegment(v, _capitalised(v.name))],
                selected: look.textSize,
                onChanged: (v) => _save(SettingKeys.textSize, v),
              ),
            ),
            _ChoiceRow(
              label: 'Corners',
              child: AkSegmented<AkCorners>(
                semanticLabel: 'Corners',
                segments: [for (final v in AkCorners.values) AkSegment(v, _capitalised(v.name))],
                selected: look.corners,
                onChanged: (v) => _save(SettingKeys.corners, v),
              ),
            ),
            _ChoiceRow(
              label: 'Category chart',
              divider: false,
              child: AkSegmented<CategoryChart>(
                semanticLabel: 'Category chart',
                segments: const [
                  AkSegment(CategoryChart.pie, 'Pie'),
                  AkSegment(CategoryChart.bars, 'Bars'),
                  AkSegment(CategoryChart.listOnly, 'List only'),
                ],
                selected: chart,
                onChanged: (v) => _save(SettingKeys.categoryChart, v),
              ),
            ),
          ],
        ),
        if (_problem != null) AkEmptyNote(_problem!),
      ],
    );
  }
}

/// One choice inside the Look card: its label above the control, 12 above and below, and a
/// `line` rule under it except on the last row, as SetAppearance.html draws it.
class _ChoiceRow extends StatelessWidget {
  const _ChoiceRow({required this.label, required this.child, this.divider = true});

  final String label;
  final Widget child;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: AkSpace.s3h),
      padding: const EdgeInsets.symmetric(vertical: AkSpace.s3),
      decoration: divider
          ? BoxDecoration(
              border: Border(bottom: BorderSide(color: c.line)),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, style: context.type.bodyMd.copyWith(color: c.ink)),
          const SizedBox(height: AkSpace.s2),
          child,
        ],
      ),
    );
  }
}

/// The main colour swatches: one 44px disc per palette in that palette's brand for the
/// current theme, ringed in `surface`; the chosen one has a 2px `ink` outline. Each is a
/// button named after its colour, so a screen reader says "Plum, selected".
class _MainColours extends StatelessWidget {
  const _MainColours({required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  /// The disc plus room for the 2px outline on each side.
  static const _slot = AkSize.target + AkSize.stroke * 2;

  @override
  Widget build(BuildContext context) {
    final count = akPalettes.length;
    List<Widget> swatches(double slot) => [
      for (final p in akPalettes)
        _Swatch(palette: p, slot: slot, selected: p.id == selected, onTap: () => onChanged(p.id)),
    ];
    return Semantics(
      container: true,
      label: 'Main colour',
      child: LayoutBuilder(
        builder: (context, box) {
          // Drawn as one spaced-out row. On a 360 phone the row is a few pixels short of six
          // full slots, so each slot gives up part of its outline margin (never below the
          // 44px target). Narrower still, it becomes two even rows of three.
          final fit = box.maxWidth / count;
          if (fit >= AkSize.target) {
            final slot = fit < _slot ? fit : _slot;
            return Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: swatches(slot));
          }
          final perRow = (count / 2).ceil();
          final gap = ((box.maxWidth - _slot * perRow) / (perRow - 1)).clamp(0.0, _slot);
          return Wrap(spacing: gap, runSpacing: AkSpace.s2, children: swatches(_slot));
        },
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  const _Swatch({
    required this.palette,
    required this.slot,
    required this.selected,
    required this.onTap,
  });

  final AkPalette palette;

  /// The tap target: the disc plus its outline, 44 to 48.
  final double slot;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final fill = (dark ? palette.dark : palette.light)['brand']!;
    // The drawn disc is 44 with a 22 corner (a circle under Rounded). The outline box and the
    // fill inside the 3px ring keep that same shape, so each corner scales with its size.
    const ring = AkSize.stroke * 1.5;
    final disc = slot - AkSize.stroke * 2;
    final inner = disc - ring * 2;
    final pill = context.metrics.pill;
    BorderRadius corner(double size) => BorderRadius.circular(pill * size / AkSize.target);
    return Semantics(
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      label: palette.label,
      container: true,
      excludeSemantics: true,
      onTap: selected ? null : onTap,
      child: Container(
        key: ValueKey('swatch-${palette.id}'),
        width: slot,
        height: slot,
        // The outline is always there, clear when not chosen, so the disc never moves.
        decoration: BoxDecoration(
          borderRadius: corner(slot),
          border: Border.all(
            color: selected ? c.ink : c.ink.withValues(alpha: 0),
            width: AkSize.stroke,
          ),
        ),
        child: Container(
          // The drawn 3px ring in the card's own colour separates the disc from the outline.
          padding: const EdgeInsets.all(ring),
          decoration: BoxDecoration(color: c.surface, borderRadius: corner(disc)),
          child: Material(
            color: fill,
            // A 1px edge: in dark, some fills are under 3:1 against the card (Charcoal 1.76),
            // and a choice must be seen to be chosen.
            shape: RoundedRectangleBorder(
              borderRadius: corner(inner),
              side: BorderSide(color: c.inkMuted),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(onTap: selected ? null : onTap),
          ),
        ),
      ),
    );
  }
}
