import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../services/security/lock_controller.dart';
import '../../services/security/pin_store.dart';
import '../../services/security/privacy_settings.dart';
import 'lock_screen.dart';
import 'pin_panel.dart';

/// What the PIN screens are for.
enum PinFlow {
  /// Choose a PIN, enter it again, and the lock is on.
  turnOn,

  /// Enter the current PIN, then choose and repeat a new one.
  change,

  /// Enter the current PIN, and the lock is off.
  turnOff,
}

enum _Step { current, choose, repeat }

/// Opens the PIN screens over the current page. True when the change was made.
Future<bool> showPinFlow(BuildContext context, PinFlow flow) async {
  final done = await Navigator.of(context, rootNavigator: true).push<bool>(
    MaterialPageRoute(fullscreenDialog: true, builder: (_) => PinFlowScreen(flow: flow)),
  );
  return done ?? false;
}

/// Set, change or turn off the PIN. Not drawn: built from Lock.html's look (design check).
class PinFlowScreen extends ConsumerStatefulWidget {
  const PinFlowScreen({super.key, required this.flow});

  final PinFlow flow;

  @override
  ConsumerState<PinFlowScreen> createState() => _PinFlowScreenState();
}

class _PinFlowScreenState extends ConsumerState<PinFlowScreen> with PinWaitCountdown {
  late _Step _step = widget.flow == PinFlow.turnOn ? _Step.choose : _Step.current;
  String? _chosen;
  String? _problem;

  @override
  void initState() {
    super.initState();
    if (_step == _Step.current) _loadWait();
  }

  Future<void> _loadWait() async {
    try {
      final wait = await ref.read(pinStoreProvider).currentWait();
      if (mounted && wait > Duration.zero) startWait(wait);
    } on Object {
      // Checked again when the PIN is typed.
    }
  }

  @override
  void onWaitOver() => _problem = null;

  String get _title => switch (_step) {
    _Step.current => 'Enter your current PIN',
    _Step.choose =>
      widget.flow == PinFlow.change ? 'Choose a new PIN' : 'Choose a $pinLength-digit PIN',
    _Step.repeat => 'Enter the same PIN again',
  };

  String get _help => switch (_step) {
    _Step.current =>
      widget.flow == PinFlow.turnOff
          ? 'The lock goes off once your PIN is checked.'
          : 'Your PIN is checked before you choose a new one.',
    _Step.choose => 'You will enter it each time Akatabo opens. Pick one others would not guess.',
    _Step.repeat => 'This checks it was typed as you meant.',
  };

  Future<void> _submit(String pin) async {
    switch (_step) {
      case _Step.current:
        await _checkCurrent(pin);
      case _Step.choose:
        setState(() {
          _chosen = pin;
          _problem = null;
          _step = _Step.repeat;
        });
      case _Step.repeat:
        if (pin != _chosen) {
          setState(() {
            _chosen = null;
            _problem = 'The two PINs did not match. Choose a PIN again.';
            _step = _Step.choose;
          });
          return;
        }
        await _save(pin);
    }
  }

  Future<void> _checkCurrent(String pin) async {
    PinCheck result;
    try {
      result = await ref.read(pinStoreProvider).check(pin);
    } on Object {
      if (mounted) setState(() => _problem = 'Your PIN could not be checked. Try again.');
      return;
    }
    if (!mounted) return;
    switch (result) {
      case PinAccepted():
        if (widget.flow == PinFlow.turnOff) {
          await _save(null);
        } else {
          setState(() {
            _problem = null;
            _step = _Step.choose;
          });
        }
      case final PinRejected rejected:
        setState(() => _problem = wrongPinMessage(rejected));
        if (rejected.wait > Duration.zero) startWait(rejected.wait);
      case PinMustWait(:final wait):
        setState(() => _problem = waitMessage(wait));
        startWait(wait);
    }
  }

  /// Makes the change. [pin] is null when turning the lock off.
  Future<void> _save(String? pin) async {
    final lock = ref.read(lockControllerProvider.notifier);
    try {
      switch (widget.flow) {
        case PinFlow.turnOn:
          await lock.turnOn(pin!);
        case PinFlow.change:
          await lock.changePin(pin!);
        case PinFlow.turnOff:
          await lock.turnOff();
      }
    } on Object {
      if (mounted) {
        setState(() {
          _problem = 'That could not be saved. Nothing has changed. Try again.';
          if (widget.flow != PinFlow.turnOff) _step = _Step.choose;
        });
      }
      return;
    }
    if (mounted) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final left = waitLeft;
    return PinPanel(
      key: ValueKey(_step),
      title: _title,
      message: left != null ? waitMessage(left) : (_problem ?? _help),
      messageIsProblem: left != null || _problem != null,
      enabled: left == null,
      onSubmit: _submit,
      header: PinTextButton(
        label: 'Cancel',
        underline: false,
        onTap: () => Navigator.of(context).pop(false),
      ),
    );
  }
}
