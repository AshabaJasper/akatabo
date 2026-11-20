import 'package:material_ui/material_ui.dart';

import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../widgets/ak_controls.dart';

/// The shortest backup password accepted. Short enough to type on a phone, long enough that
/// it is not a PIN.
const minBackupPasswordLength = 6;

/// A password input in the app's field style, with a 44px "Show" / "Hide" button so the
/// person can check what they typed. Not drawn; built from the field rules.
class BackupPasswordField extends StatefulWidget {
  const BackupPasswordField({
    super.key,
    required this.label,
    required this.controller,
    this.errorText,
    this.onSubmitted,
    this.textInputAction,
    this.autofocus = false,
  });

  final String label;
  final TextEditingController controller;
  final String? errorText;
  final ValueChanged<String>? onSubmitted;
  final TextInputAction? textInputAction;
  final bool autofocus;

  @override
  State<BackupPasswordField> createState() => _BackupPasswordFieldState();
}

class _BackupPasswordFieldState extends State<BackupPasswordField> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    final radius = BorderRadius.circular(context.metrics.lg);
    OutlineInputBorder border(Color colour, [double width = 1]) => OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: colour, width: width),
    );
    final style = t.bodyMd;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(child: AkEyebrowLabel(widget.label)),
        const SizedBox(height: AkSpace.s1h),
        Semantics(
          label: widget.label,
          child: TextField(
            controller: widget.controller,
            autofocus: widget.autofocus,
            obscureText: !_shown,
            autocorrect: false,
            enableSuggestions: false,
            keyboardType: TextInputType.visiblePassword,
            textInputAction: widget.textInputAction,
            onSubmitted: widget.onSubmitted,
            style: style,
            cursorColor: c.brand,
            decoration: InputDecoration(
              errorText: widget.errorText,
              errorStyle: t.caption.copyWith(color: c.moneyOut),
              errorMaxLines: 3,
              filled: true,
              fillColor: c.surface,
              isDense: true,
              constraints: const BoxConstraints(minHeight: AkSize.input),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: AkSpace.s3h,
                vertical: AkSpace.s3h,
              ),
              suffixIcon: Semantics(
                button: true,
                label: _shown ? 'Hide the password' : 'Show the password',
                excludeSemantics: true,
                child: InkWell(
                  borderRadius: radius,
                  onTap: () => setState(() => _shown = !_shown),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: AkSize.target,
                      minHeight: AkSize.target,
                    ),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: AkSpace.s3),
                        child: Text(
                          _shown ? 'Hide' : 'Show',
                          style: t.bodyStrong.copyWith(color: c.brandText),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              enabledBorder: border(c.lineStrong),
              focusedBorder: border(c.brandBright, 2),
              errorBorder: border(c.moneyOut),
              focusedErrorBorder: border(c.moneyOut, 2),
              border: border(c.lineStrong),
            ),
          ),
        ),
      ],
    );
  }
}

/// Asks for a new backup password twice, in a sheet. Returns it, or null when the person
/// closes the sheet. Not drawn: built from the field and button rules (design check).
Future<String?> askNewBackupPassword(BuildContext context, {String? purpose}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _NewPasswordSheet(purpose: purpose),
    );

class _NewPasswordSheet extends StatefulWidget {
  const _NewPasswordSheet({this.purpose});
  final String? purpose;

  @override
  State<_NewPasswordSheet> createState() => _NewPasswordSheetState();
}

class _NewPasswordSheetState extends State<_NewPasswordSheet> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _firstError;
  String? _secondError;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    final a = _first.text;
    final b = _second.text;
    setState(() {
      _firstError = a.length < minBackupPasswordLength
          ? 'Use at least $minBackupPasswordLength letters, numbers or signs.'
          : null;
      _secondError = _firstError == null && a != b
          ? 'This is not the same as the password above. Type it again.'
          : null;
    });
    if (_firstError == null && _secondError == null) Navigator.of(context).pop(a);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(AkSpace.s6, 0, AkSpace.s6, AkSpace.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Semantics(
              header: true,
              child: Text('Protect this backup', style: t.title.copyWith(color: c.ink)),
            ),
            const SizedBox(height: AkSpace.s2),
            if (widget.purpose != null) ...[
              Text(widget.purpose!, style: t.bodySm.copyWith(color: c.ink)),
              const SizedBox(height: AkSpace.s2),
            ],
            Text(
              'You will need this password to restore the file. If you forget it, nobody can '
              'open the backup, not even Akatabo.',
              style: t.bodySm.copyWith(color: c.inkMuted),
            ),
            const SizedBox(height: AkSpace.s4),
            BackupPasswordField(
              label: 'Password',
              controller: _first,
              errorText: _firstError,
              autofocus: true,
              textInputAction: TextInputAction.next,
            ),
            const SizedBox(height: AkSpace.s3),
            BackupPasswordField(
              label: 'Type it again',
              controller: _second,
              errorText: _secondError,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
            ),
            const SizedBox(height: AkSpace.s5),
            AkPrimaryButton(label: 'Use this password', onPressed: _submit),
            const SizedBox(height: AkSpace.s2),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AkIcon(AkIcons.lock, color: c.inkMuted, size: AkSize.iconXs),
                const SizedBox(width: AkSpace.s1h),
                Flexible(
                  child: Text(
                    'The password is not kept on this phone.',
                    style: t.caption.copyWith(color: c.inkMuted),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
