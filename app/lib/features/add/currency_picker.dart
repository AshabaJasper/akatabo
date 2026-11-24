import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/format/money.dart';
import '../../domain/currency.dart';
import '../../widgets/ak_controls.dart';
import '../../widgets/ak_pickers.dart';

/// The code for "Another currency…", which opens a box for any three-letter code.
const _other = 'OTHER';

/// Asks which currency a payment was in. UGX is the home currency; the common codes come
/// first, and "Another currency…" takes any three-letter ISO code. Null when dismissed.
Future<String?> pickCurrency(BuildContext context, {required String current}) async {
  final picked = await showAkChoiceSheet<String>(
    context,
    title: 'Currency',
    selected: current,
    options: [
      ('UGX', 'UGX, Ugandan shilling'),
      for (final code in commonCurrencies) (code, code),
      (_other, 'Another currency…'),
    ],
  );
  if (picked != _other || !context.mounted) return picked;
  return _typeCode(context);
}

Future<String?> _typeCode(BuildContext context) {
  final controller = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Another currency'),
      content: AkTextField(
        label: 'Three-letter code, such as JPY',
        controller: controller,
        maxLength: 3,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => Navigator.of(ctx).pop(_codeFrom(controller.text)),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(_codeFrom(controller.text)),
          child: const Text('Use this'),
        ),
      ],
    ),
  ).whenComplete(controller.dispose);
}

/// The typed code in capitals, or null when it is not a three-letter code.
String? _codeFrom(String typed) {
  final code = typed.trim().toUpperCase();
  return isForeignCode(code) ? code : null;
}

/// A foreign amount or a rate as it is typed: grouped in thousands, with up to [decimals]
/// decimals after a full stop. Unlike the shilling field, the decimals are kept.
///
/// A comma typed while there is no full stop yet is the decimal point, as phones set to a
/// decimal comma send it. The grouping commas are written by this formatter, never typed,
/// so this cannot mistake one for the other.
class ForeignAmountFormatter extends TextInputFormatter {
  const ForeignAmountFormatter({this.decimals = 2});

  /// Decimals kept: 2 for an amount, [rateDecimals] for a rate.
  final int decimals;

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    var text = newValue.text;
    final at = newValue.selection.baseOffset - 1;
    final typedOne = text.length == oldValue.text.length + 1;
    if (typedOne && at >= 0 && at < text.length && text[at] == ',' && !text.contains('.')) {
      text = '${text.substring(0, at)}.${text.substring(at + 1)}';
    }
    final raw = text.replaceAll(RegExp('[^0-9.]'), '');
    final dot = raw.indexOf('.');
    final wholeDigits = (dot < 0 ? raw : raw.substring(0, dot)).replaceFirst(
      RegExp(r'^0+(?=\d)'),
      '',
    );
    if (wholeDigits.isEmpty && dot < 0) return const TextEditingValue();
    final capped = wholeDigits.length > 12 ? wholeDigits.substring(0, 12) : wholeDigits;
    final whole = capped.isEmpty ? '0' : formatAmount(int.parse(capped));
    final digits = dot < 0 ? null : raw.substring(dot + 1).replaceAll('.', '');
    final shown = digits == null
        ? whole
        : '$whole.${digits.length > decimals ? digits.substring(0, decimals) : digits}';
    return TextEditingValue(
      text: shown,
      selection: TextSelection.collapsed(offset: shown.length),
    );
  }
}
