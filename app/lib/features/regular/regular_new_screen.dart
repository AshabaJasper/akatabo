import 'package:clock/clock.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../../app/close_screen.dart';
import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../core/time/period.dart';
import '../../data/seed/default_data.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_surfaces.dart';
import '../add/amount_text.dart';
import 'regular_providers.dart';

/// How often a payment repeats, in days, as the choices on the form.
const _repeats = [(7, 'Weekly'), (30, 'Monthly'), (365, 'Yearly')];

/// Adds a regular payment the person knows about. Akatabo does not guess it from entries here;
/// that detection comes later. The form asks for what the forecast needs: a name, an amount,
/// how often, and the next date.
class RegularNewScreen extends ConsumerStatefulWidget {
  const RegularNewScreen({super.key});

  @override
  ConsumerState<RegularNewScreen> createState() => _RegularNewScreenState();
}

class _RegularNewScreenState extends ConsumerState<RegularNewScreen> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  int _interval = 30;
  DateTime? _next;
  String? _problem;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = dateOnly(clock.now());
    final picked = await showDatePicker(
      context: context,
      initialDate: _next ?? today,
      firstDate: today,
      lastDate: addDays(today, 365 * 3),
    );
    if (picked != null) setState(() => _next = picked);
  }

  Future<void> _save() async {
    if (_saving) return;
    final amount = parseAmount(_amount.text);
    final name = _name.text.trim();
    final problem = name.isEmpty
        ? 'Give it a name, such as Water bill.'
        : amount <= 0
        ? 'Enter an amount above zero.'
        : null;
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    setState(() => _saving = true);
    final next = _next ?? dateOnly(clock.now());
    try {
      await ref
          .read(regularPaymentRepositoryProvider)
          .add(
            label: name,
            amount: amount,
            intervalDays: _interval,
            nextDueOn: toLocalDay(next),
            categoryId: DefaultIds.bills,
          );
      if (mounted) await closeScreen(context);
    } on Object {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _problem = 'This could not be saved. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final next = _next ?? dateOnly(clock.now());
    return Scaffold(
      backgroundColor: c.ground,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(AkSpace.s6, AkSpace.s2, AkSpace.s6, AkSpace.s6),
          children: [
            AkBackLink('Coming up', onTap: () => closeScreen(context)),
            const SizedBox(height: AkSpace.s3),
            Semantics(
              header: true,
              child: Text('New regular payment', style: t.titleLg.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s5),
            AkTextField(label: 'What it is', controller: _name, hint: 'Water bill'),
            const SizedBox(height: AkSpace.s4),
            AkTextField(
              label: 'Usually how much, UGX',
              controller: _amount,
              keyboardType: TextInputType.number,
              figures: true,
              inputFormatters: const [ThousandsFormatter()],
              hint: '46,000',
            ),
            const SizedBox(height: AkSpace.s4),
            const AkEyebrowLabel('Repeats'),
            const SizedBox(height: AkSpace.s2),
            AkSegmented<int>(
              semanticLabel: 'Repeats',
              selected: _interval,
              onChanged: (v) => setState(() => _interval = v),
              segments: [for (final r in _repeats) AkSegment(r.$1, r.$2)],
            ),
            const SizedBox(height: AkSpace.s4),
            AkOutlineButton(
              label: 'Next due ${DateFormat('d MMMM y').format(next)}',
              icon: AkIcons.calendar,
              onPressed: _pickDate,
            ),
            if (_problem != null) ...[
              const SizedBox(height: AkSpace.s3),
              Text(_problem!, style: t.bodySm.copyWith(color: c.moneyOut)),
            ],
            const SizedBox(height: AkSpace.s5),
            AkPrimaryButton(label: 'Save', onPressed: _saving ? null : _save),
          ],
        ),
      ),
    );
  }
}
