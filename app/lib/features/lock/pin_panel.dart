import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/icons/ak_icon.dart';
import '../../core/theme/ak_theme.dart';
import '../../services/security/privacy_settings.dart';
import '../../widgets/ak_logo.dart';

/// The PIN screen as Lock.html draws it: the wordmark, a title, four dots, one line of help,
/// the keypad, and a footer link, on `screen-deep` in both themes.
///
/// The panel keeps the digits typed so far. When the last one is typed it calls [onSubmit]
/// and clears the dots once that finishes; the parent sets [message] from the result.
class PinPanel extends StatefulWidget {
  const PinPanel({
    super.key,
    required this.title,
    required this.message,
    required this.onSubmit,
    this.messageIsProblem = false,
    this.enabled = true,
    this.onBiometric,
    this.footer,
    this.header,
  });

  final String title;

  /// The line under the dots: help, or what went wrong. Read out when it changes.
  final String message;
  final bool messageIsProblem;
  final Future<void> Function(String pin) onSubmit;

  /// False while a wait after wrong tries runs: the keys do nothing.
  final bool enabled;

  /// Shows the fingerprint key bottom left when set.
  final VoidCallback? onBiometric;

  /// "Forgot your PIN?" on the lock screen.
  final Widget? footer;

  /// A Cancel link above the wordmark on the set and change screens.
  final Widget? header;

  @override
  State<PinPanel> createState() => _PinPanelState();
}

class _PinPanelState extends State<PinPanel> {
  String _digits = '';
  bool _busy = false;

  bool get _keysOn => widget.enabled && !_busy;

  /// The content below the safe area, measured after each layout.
  final _contentKey = GlobalKey();

  /// The largest key that lets everything fit on a short screen, or null for full size.
  double? _keyCap;

  /// The screen height [_keyCap] was worked out for.
  double? _capHeight;

  /// The key cap for a screen [height] tall. A new height starts again at full size; each
  /// layout is then checked once it is done (see [_fitKeypad]).
  double _keyCapFor(double height, double width) {
    if (_capHeight != height) {
      _capHeight = height;
      _keyCap = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _fitKeypad(height, width));
    return _keyCap ?? double.infinity;
  }

  /// If the content ran past the screen, shrink the keys by a quarter of the overflow (the
  /// keypad has four rows), never below the 44px target. Where everything fits, as on most
  /// phones, nothing changes; where even 44px keys do not fit, the screen scrolls.
  void _fitKeypad(double height, double width) {
    if (!mounted || _capHeight != height) return;
    final content = _contentKey.currentContext?.findRenderObject();
    if (content is! RenderBox || !content.hasSize) return;
    final over = content.size.height - height;
    if (over < 1) return;
    final current = _Keypad.keyFor(width, _keyCap ?? double.infinity);
    final next = math.max(AkSize.target, (current - over / 4).floorToDouble());
    if (next < current) setState(() => _keyCap = next);
  }

  Future<void> _type(String digit) async {
    if (!_keysOn || _digits.length >= pinLength) return;
    unawaited(HapticFeedback.selectionClick());
    setState(() => _digits += digit);
    if (_digits.length < pinLength) return;
    setState(() => _busy = true);
    try {
      await widget.onSubmit(_digits);
    } finally {
      if (mounted) {
        setState(() {
          _busy = false;
          _digits = '';
        });
      }
    }
  }

  void _delete() {
    if (!_keysOn || _digits.isEmpty) return;
    setState(() => _digits = _digits.substring(0, _digits.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final t = context.type;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: c.screenDeep.withValues(alpha: 0),
        systemNavigationBarColor: c.screenDeep,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Material(
        color: c.screenDeep,
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, box) => SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: box.maxHeight),
                child: IntrinsicHeight(
                  key: _contentKey,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AkSpace.s6,
                      AkSpace.s6,
                      AkSpace.s6,
                      AkSpace.s4,
                    ),
                    child: Column(
                      children: [
                        if (widget.header != null)
                          Align(alignment: AlignmentDirectional.centerStart, child: widget.header)
                        else
                          const SizedBox(height: AkSize.target),
                        // The spare height is shared: some above the title, more between the
                        // message and the keypad, so on a tall phone the title sits in the
                        // upper half and the keypad rises off the bottom edge.
                        const Spacer(flex: 2),
                        ExcludeSemantics(
                          child: AkLogo(style: t.titleLg.copyWith(color: c.onBrand)),
                        ),
                        const SizedBox(height: AkSpace.s6),
                        Semantics(
                          header: true,
                          child: Text(
                            widget.title,
                            textAlign: TextAlign.center,
                            style: t.headline.copyWith(color: c.onBrand),
                          ),
                        ),
                        const SizedBox(height: AkSpace.s4),
                        _Dots(entered: _digits.length),
                        const SizedBox(height: AkSpace.s4),
                        Semantics(
                          liveRegion: true,
                          child: Text(
                            widget.message,
                            textAlign: TextAlign.center,
                            style: (widget.messageIsProblem ? t.bodyStrong : t.bodySm).copyWith(
                              color: widget.messageIsProblem ? c.onBrand : c.onBrandMuted,
                            ),
                          ),
                        ),
                        const Spacer(flex: 3),
                        const SizedBox(height: AkSpace.s6),
                        _Keypad(
                          enabled: _keysOn,
                          onDigit: _type,
                          onDelete: _delete,
                          onBiometric: widget.onBiometric,
                          canDelete: _digits.isNotEmpty,
                          width: box.maxWidth - 2 * AkSpace.s6,
                          maxKey: _keyCapFor(box.maxHeight, box.maxWidth - 2 * AkSpace.s6),
                        ),
                        const SizedBox(height: AkSpace.s3),
                        widget.footer ?? const SizedBox(height: AkSize.target),
                        const Spacer(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Four 18px rings in `on-brand-muted`, filled with `accent` as digits are typed.
class _Dots extends StatelessWidget {
  const _Dots({required this.entered});

  final int entered;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      label: '$entered of $pinLength digits entered',
      container: true,
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < pinLength; i++) ...[
            if (i > 0) const SizedBox(width: AkSpace.s4),
            Container(
              width: AkSize.iconSm,
              height: AkSize.iconSm,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < entered ? c.accent : c.screenDeep.withValues(alpha: 0),
                border: Border.all(color: c.onBrandMuted, width: AkSize.stroke),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Three columns of round keys: 1 to 9, then fingerprint, 0 and delete.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.enabled,
    required this.onDigit,
    required this.onDelete,
    required this.onBiometric,
    required this.canDelete,
    required this.width,
    this.maxKey = double.infinity,
  });

  /// The key size for a keypad [width] wide, at most [maxKey]: keys grow with the phone up
  /// to `size-pin-key`, shrink so three fit a narrow phone, and never go below the 44px
  /// target.
  static double keyFor(double width, double maxKey) =>
      math.min((width - 2 * AkSpace.s6) / 3, maxKey).clamp(AkSize.target, AkSize.pinKey);

  /// The width the keypad may use; keys shrink to fit narrow phones.
  final double width;

  /// The largest key the screen's height allows (see `_PinPanelState._fitKeypad`).
  final double maxKey;
  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final VoidCallback? onBiometric;
  final bool canDelete;

  @override
  Widget build(BuildContext context) {
    {
      {
        // Rows open up a little once keys are large.
        const gap = AkSpace.s6;
        final key = keyFor(width, maxKey);
        final rowGap = key >= AkSize.catCell ? AkSpace.s5 : AkSpace.s4;
        Widget row(List<Widget> keys) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (i, k) in keys.indexed) ...[
              if (i > 0) const SizedBox(width: gap),
              SizedBox.square(dimension: key, child: k),
            ],
          ],
        );
        Widget digit(String d) => _Key(label: d, enabled: enabled, onTap: () => onDigit(d));
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final r in const [
              ['1', '2', '3'],
              ['4', '5', '6'],
              ['7', '8', '9'],
            ]) ...[
              row([for (final d in r) digit(d)]),
              SizedBox(height: rowGap),
            ],
            row([
              if (onBiometric != null)
                _IconKey(
                  icon: AkIcons.fingerprint,
                  label: 'Unlock with fingerprint or face',
                  accent: true,
                  onTap: onBiometric,
                )
              else
                const SizedBox.shrink(),
              digit('0'),
              _IconKey(
                icon: AkIcons.backspace,
                label: 'Delete the last digit',
                onTap: enabled && canDelete ? onDelete : null,
              ),
            ]),
          ],
        );
      }
    }
  }
}

class _Key extends StatelessWidget {
  const _Key({required this.label, required this.enabled, required this.onTap});

  final String label;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onTap : null,
      child: Material(
        color: c.brandRaised,
        shape: CircleBorder(side: BorderSide(color: c.deepLine)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: enabled ? onTap : null,
          child: Center(
            child: Text(
              label,
              style: context.type.keypad.copyWith(color: enabled ? c.onBrand : c.onBrandMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _IconKey extends StatelessWidget {
  const _IconKey({
    required this.icon,
    required this.label,
    required this.onTap,
    this.accent = false,
  });

  final AkIcons icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        type: MaterialType.transparency,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: AkIcon(
              icon,
              size: AkSize.tile - AkSpace.s2,
              color: accent ? c.accent : c.onBrand,
            ),
          ),
        ),
      ),
    );
  }
}

/// A plain underlined text button on `screen-deep`: "Forgot your PIN?" and "Cancel".
class PinTextButton extends StatelessWidget {
  const PinTextButton({super.key, required this.label, required this.onTap, this.underline = true});

  final String label;
  final VoidCallback? onTap;
  final bool underline;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(context.metrics.sm),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: AkSize.target, minWidth: AkSize.target),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: AkSpace.s2),
            child: Center(
              widthFactor: 1,
              child: Text(
                label,
                style: context.type.body.copyWith(
                  color: c.onBrandMuted,
                  fontWeight: FontWeight.w500,
                  decoration: underline ? TextDecoration.underline : null,
                  decorationColor: c.onBrandMuted,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
