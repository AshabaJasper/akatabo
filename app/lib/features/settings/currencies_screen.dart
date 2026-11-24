import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../core/theme/ak_theme.dart';
import '../../data/providers.dart';
import '../../data/settings/remembered_rates.dart';
import '../../domain/currency.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_empty_note.dart';
import '../add/currency_picker.dart';
import 'settings_page.dart';
import 'smart_rows.dart';

/// Currencies and rates: the rates the person has typed (edit or remove), a way to add one,
/// and a converter. Nothing is fetched; UGX stays the home currency, and past entries keep the
/// rate they were saved with.
class CurrenciesScreen extends ConsumerStatefulWidget {
  const CurrenciesScreen({super.key});

  @override
  ConsumerState<CurrenciesScreen> createState() => _CurrenciesScreenState();
}

class _CurrenciesScreenState extends ConsumerState<CurrenciesScreen> {
  final _amount = TextEditingController();
  String _code = 'USD';
  String? _problem;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  /// The remembered rates as they stand now, for actions (not for building the page).
  Map<String, int> get _ratesNow =>
      rememberedRates(ref.read(storedSettingsProvider).value ?? const {});

  /// Saves a rate for [code], or removes it when [micros] is null.
  Future<void> _store(String code, int? micros) async {
    setState(() => _problem = null);
    try {
      await ref
          .read(settingsRepositoryProvider)
          .write(rateSetting(code), micros == null ? '' : '$micros');
    } on Object {
      if (mounted) setState(() => _problem = 'That could not be saved. Try again.');
    }
  }

  /// Asks for the rate of [code] in a box: shillings for one unit. Remove clears it.
  Future<void> _editRate(String code, int? current) async {
    final result = await showDialog<_RateResult>(
      context: context,
      builder: (_) => _RateDialog(code: code, current: current),
    );
    if (!mounted || result == null) return;
    await _store(code, result.micros);
  }

  Future<void> _addCurrency() async {
    final code = await pickCurrency(context, current: _code);
    if (code == null || code == 'UGX' || !mounted) return;
    await _editRate(code, _ratesNow[code]);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final async = ref.watch(storedSettingsProvider);
    const title = 'Currencies and rates';
    if (async.hasError) {
      return const SettingsPage(
        title: title,
        children: [AkEmptyNote('Settings could not load. Close Akatabo and open it again.')],
      );
    }
    if (!async.hasValue) return const SettingsPage(title: title, children: []);

    final rates = rememberedRates(async.requireValue);
    final rate = rates[_code];
    final typed = parseForeignMinor(_amount.text);
    final result = rate == null || typed == null
        ? null
        : ugxFor(foreignMinor: typed, rateMicros: rate);

    return SettingsPage(
      title: title,
      children: [
        Text(
          'UGX is the home currency. Rates are the ones you typed, kept on this phone only. '
          'An entry keeps the rate it was saved with when a rate changes later.',
          style: t.bodySm.copyWith(color: c.inkMuted),
        ),
        const SizedBox(height: AkSpace.s5),
        SettingsSection(
          label: 'Remembered rates',
          children: [
            if (rates.isEmpty)
              // Inset like the rows, and left-aligned: the section centres its children.
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: settingsRowSide, vertical: AkSpace.s3),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: AkEmptyNote(
                    'No rates yet. Type one when you add a payment in another currency.',
                  ),
                ),
              ),
            for (final (i, e) in rates.entries.indexed)
              SettingsValueRow(
                title: e.key,
                value: '${formatRate(e.value)} UGX',
                onTap: () => _editRate(e.key, e.value),
                chevron: true,
                divider: i < rates.length - 1,
              ),
            ActionRow(label: 'Add a currency', onTap: _addCurrency, destructive: false),
          ],
        ),
        SettingsSection(
          label: 'Converter',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(settingsRowSide, AkSpace.s3, settingsRowSide, 0),
              child: Row(
                children: [
                  Expanded(
                    child: AkTextField(
                      label: 'Amount in $_code',
                      controller: _amount,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      inputFormatters: const [ForeignAmountFormatter()],
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: AkSpace.s3),
                  AkChip(
                    label: _code,
                    selected: true,
                    onTap: () async {
                      final picked = await pickCurrency(context, current: _code);
                      if (picked == null || picked == 'UGX' || !mounted) return;
                      setState(() => _code = picked);
                    },
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                settingsRowSide,
                AkSpace.s2,
                settingsRowSide,
                AkSpace.s3,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: Text(
                  result != null
                      ? '= ${formatUgx(result)}'
                      : rate == null
                      ? 'Set a rate for $_code above first.'
                      : 'Type an amount to convert.',
                  style: t.bodyMd.copyWith(color: result != null ? c.ink : c.inkMuted),
                ),
              ),
            ),
          ],
        ),
        if (_problem != null) AkEmptyNote(_problem!),
      ],
    );
  }
}

/// What the rate box gives back: a rate to save, or null [micros] to remove the rate.
class _RateResult {
  const _RateResult.save(int this.micros);
  const _RateResult.remove() : micros = null;

  final int? micros;
}

/// The box for one currency's rate. Save checks the rate first and, when it is not one,
/// keeps the box open with the reason under the field, so nothing typed is lost.
class _RateDialog extends StatefulWidget {
  const _RateDialog({required this.code, required this.current});

  final String code;
  final int? current;

  @override
  State<_RateDialog> createState() => _RateDialogState();
}

class _RateDialogState extends State<_RateDialog> {
  // Owned by the box, so it is disposed only once the box has gone, closing animation and all.
  late final _controller = TextEditingController(
    text: widget.current == null ? '' : formatRate(widget.current!),
  );
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final micros = parseRateMicros(_controller.text);
    if (micros == null) {
      setState(() => _error = 'Type a rate above zero, such as 3,720.');
      return;
    }
    Navigator.of(context).pop(_RateResult.save(micros));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Rate for ${widget.code}'),
      content: AkTextField(
        label: 'UGX for one ${widget.code}',
        controller: _controller,
        hint: '3,720',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: const [ForeignAmountFormatter(decimals: rateDecimals)],
        textInputAction: TextInputAction.done,
        errorText: _error,
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        if (widget.current != null)
          TextButton(
            onPressed: () => Navigator.of(context).pop(const _RateResult.remove()),
            child: const Text('Remove'),
          ),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
        TextButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}
