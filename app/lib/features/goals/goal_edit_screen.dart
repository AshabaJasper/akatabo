import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/format/money.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/theme/token_colour.dart';
import '../../core/time/clock_provider.dart';
import '../../core/time/period.dart';
import '../../data/db/app_database.dart';
import '../../data/providers.dart';
import '../../domain/goals.dart';
import '../../services/security/hidden_amounts.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_pickers.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/amount_text.dart';
import 'goal_widgets.dart';
import 'goals_providers.dart';

/// The colours a goal can take, in the order they are offered.
const _goalColours = ['cat-teal', 'cat-amber', 'cat-indigo', 'cat-purple', 'cat-pink', 'cat-green'];

const _colourNames = {
  'cat-teal': 'Teal',
  'cat-amber': 'Amber',
  'cat-indigo': 'Indigo',
  'cat-purple': 'Purple',
  'cat-pink': 'Pink',
  'cat-green': 'Green',
};

/// Makes a new savings goal ([goalId] null) or changes one. Changing it can also archive it;
/// a goal with moves cannot be deleted, so archiving is the way to put it away.
class GoalEditScreen extends ConsumerStatefulWidget {
  const GoalEditScreen({super.key, this.goalId});

  final String? goalId;

  @override
  ConsumerState<GoalEditScreen> createState() => _GoalEditScreenState();
}

class _GoalEditScreenState extends ConsumerState<GoalEditScreen> {
  final _name = TextEditingController();
  final _target = TextEditingController();
  int? _targetDay;

  /// The date the saved goal had when it loaded. A date already in the past is kept as it is:
  /// only a newly picked date has to be today or later, so an old goal can still be renamed.
  int? _loadedTargetDay;
  String _colour = _goalColours.first;
  String _iconKey = 'wallet';
  GoalRemind _remind = GoalRemind.off;
  bool _filled = false;
  bool _saving = false;
  String? _nameError;
  String? _targetError;
  String? _problem;

  bool get _isNew => widget.goalId == null;

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Copies a saved goal into the fields, once, when it first loads.
  void _fill(Goal goal) {
    _filled = true;
    _name.text = goal.name;
    _target.text = formatAmount(goal.target);
    _targetDay = goal.targetDay;
    _loadedTargetDay = goal.targetDay;
    _colour = goal.colourToken;
    _iconKey = goal.iconKey;
    _remind = goal.remindEvery;
  }

  bool _validate(int today) {
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    setState(() {
      _nameError = name.isEmpty ? 'Give the goal a name.' : null;
      _targetError = target <= 0 ? 'Type a target above zero.' : null;
      _problem = null;
    });
    if (_targetDay != null && _targetDay != _loadedTargetDay && _targetDay! < today) {
      setState(() => _problem = 'The date is in the past. Pick today or a later day.');
      return false;
    }
    return _nameError == null && _targetError == null;
  }

  Future<void> _save(int today) async {
    if (_saving || !_validate(today)) return;
    setState(() => _saving = true);
    final repo = ref.read(goalRepositoryProvider);
    final name = _name.text.trim();
    final target = parseAmount(_target.text);
    try {
      if (_isNew) {
        await repo.add(
          name: name,
          target: target,
          colourToken: _colour,
          targetDay: _targetDay,
          iconKey: _iconKey,
          remindEvery: _remind,
        );
      } else {
        await repo.update(
          widget.goalId!,
          name: name,
          target: target,
          colourToken: _colour,
          targetDay: _targetDay,
          iconKey: _iconKey,
          remindEvery: _remind,
        );
      }
      if (mounted) await closeScreen(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _problem = 'The goal could not be saved. Try again.';
        });
      }
    }
  }

  Future<void> _archive() async {
    final id = widget.goalId;
    if (id == null || _saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(goalRepositoryProvider).archive(id);
      // Back to the goal, which now says it is archived. Replacing the stack with the list
      // left its back link nowhere to go.
      if (mounted) await closeScreen(context);
    } on Object {
      if (mounted) {
        setState(() {
          _saving = false;
          _problem = 'The goal could not be archived. Try again.';
        });
      }
    }
  }

  Future<void> _pickDate(DateTime today) async {
    final picked = await showAkDatePicker(
      context,
      initial: _targetDay == null ? addDays(today, 90) : fromLocalDay(_targetDay!),
      first: today,
      last: DateTime(today.year + 10),
      helpText: 'Reach it by',
    );
    if (picked != null) setState(() => _targetDay = toLocalDay(picked));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final today = dateOnly(ref.watch(appNowProvider));
    final hidden = ref.watch(amountsHiddenProvider);
    final goalId = widget.goalId;
    final goalAsync = goalId == null ? null : ref.watch(goalProvider(goalId));
    final movesAsync = goalId == null ? null : ref.watch(goalMovesProvider(goalId));
    if (goalAsync?.value != null && !_filled) _fill(goalAsync!.value!);

    final saved = movesAsync?.value == null
        ? 0
        : savedOf([
            for (final m in movesAsync!.value!)
              GoalMoveEntry(amount: m.amount, localDay: m.localDay),
          ]);
    final target = parseAmount(_target.text);
    final weekly = target > 0 && _targetDay != null
        ? requiredPer(
            target: target,
            saved: saved < 0 ? 0 : saved,
            targetDay: _targetDay,
            today: today,
            periodDays: 7,
          )
        : null;

    final tile = colourForToken(c, _colour);

    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink(
              _isNew
                  ? 'Savings goals'
                  : (_name.text.trim().isEmpty ? 'Savings goal' : _name.text.trim()),
              onTap: () => closeScreen(context),
            ),
            const SizedBox(height: AkSpace.s3),
            Row(
              children: [
                AkIconTile(
                  icon: goalIcon(_iconKey),
                  background: tile,
                  foreground: goalIconInk(context, tile),
                  size: 48,
                  iconSize: 26,
                ),
                const SizedBox(width: AkSpace.s3),
                Expanded(
                  child: Text(
                    _isNew ? 'New goal' : 'Edit goal',
                    style: t.displayLg.copyWith(color: c.ink),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AkSpace.s5),
            AkTextField(
              label: 'Name',
              controller: _name,
              textInputAction: TextInputAction.next,
              errorText: _nameError,
              maxLength: 40,
            ),
            const SizedBox(height: AkSpace.s4),
            AkTextField(
              label: 'Target, UGX',
              controller: _target,
              keyboardType: TextInputType.number,
              inputFormatters: const [ThousandsFormatter()],
              figures: true,
              errorText: _targetError,
            ),
            if (weekly != null) ...[
              const SizedBox(height: AkSpace.s1),
              Text(
                weekly == 0
                    ? 'Already reached.'
                    : _targetDay! < toLocalDay(today)
                    ? 'This date has passed. Pick a new one to see the weekly amount.'
                    : '${shownUgx(weekly, hidden: hidden)} a week to make it by ${dayText(_targetDay!)}.',
                style: t.caption.copyWith(color: c.inkMuted),
              ),
            ],
            const SizedBox(height: AkSpace.s4),
            const AkEyebrowLabel('Target date, optional'),
            const SizedBox(height: AkSpace.s2),
            Row(
              children: [
                Expanded(
                  child: Semantics(
                    button: true,
                    label: _targetDay == null
                        ? 'Pick a target date'
                        : 'Target date ${dayText(_targetDay!)}. Change it',
                    child: OutlinedButton.icon(
                      onPressed: () => _pickDate(today),
                      icon: AkIcon(AkIcons.calendar, size: 20, color: c.ink),
                      label: Text(
                        _targetDay == null ? 'No date' : dayText(_targetDay!),
                        style: t.body.copyWith(color: c.ink),
                      ),
                    ),
                  ),
                ),
                if (_targetDay != null)
                  TextButton(
                    onPressed: () => setState(() => _targetDay = null),
                    child: Text('Clear', style: t.bodyStrong.copyWith(color: c.brandText)),
                  ),
              ],
            ),
            if (_problem != null) ...[
              const SizedBox(height: AkSpace.s2),
              Text(_problem!, style: t.caption.copyWith(color: c.moneyOut)),
            ],
            const SizedBox(height: AkSpace.s4),
            const AkEyebrowLabel('Colour'),
            const SizedBox(height: AkSpace.s2),
            Wrap(
              spacing: AkSpace.s2,
              runSpacing: AkSpace.s2,
              children: [
                for (final token in _goalColours)
                  _ColourDisc(
                    name: _colourNames[token]!,
                    colour: colourForToken(c, token),
                    selected: token == _colour,
                    onTap: () => setState(() => _colour = token),
                  ),
              ],
            ),
            // No "Remind me" choice yet: nothing schedules goal reminders, and a setting that
            // never fires is a broken promise. [_remind] still carries a stored value through an
            // edit, so the choice can come back once the reminder scheduler plans goals.
            const SizedBox(height: AkSpace.s5),
            if (!_isNew)
              AkCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AkOutlineButton(label: 'Archive goal', onPressed: _saving ? null : _archive),
                    const SizedBox(height: AkSpace.s2),
                    Text(
                      'Its money stays set aside. A goal with moves cannot be deleted.',
                      style: t.caption.copyWith(color: c.inkMuted),
                    ),
                  ],
                ),
              ),
            if (!_isNew) const SizedBox(height: AkSpace.s4),
            AkPrimaryButton(
              label: 'Save goal',
              onPressed: _saving ? null : () => _save(toLocalDay(today)),
            ),
          ],
        ),
      ),
    );
  }
}

/// One colour choice: a disc that is outlined when chosen. Read as a named button.
class _ColourDisc extends StatelessWidget {
  const _ColourDisc({
    required this.name,
    required this.colour,
    required this.selected,
    required this.onTap,
  });

  final String name;
  final Color colour;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      selected: selected,
      label: name,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colour,
            border: selected ? Border.all(color: c.ink, width: 2) : null,
          ),
        ),
      ),
    );
  }
}
