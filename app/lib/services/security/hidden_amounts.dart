import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import 'privacy_settings.dart';

/// Whether the person has tapped a dotted figure since the app was last out of sight.
/// One tap shows every main figure until Akatabo is hidden or locked again.
class AmountsRevealed extends Notifier<bool> {
  @override
  bool build() {
    // Switching "Hide amounts" off and on again dots every figure again.
    ref.listen(
      storedSettingsProvider.select(
        (s) => PrivacyKeys.hideAmounts.decode(s.value?[PrivacyKeys.hideAmounts.name]),
      ),
      (_, _) => state = false,
    );
    return false;
  }

  void reveal() => state = true;
  void hideAgain() => state = false;
}

final amountsRevealedProvider = NotifierProvider<AmountsRevealed, bool>(AmountsRevealed.new);

/// True while "Hide amounts" is on and no figure has been tapped: main figures show dots.
final amountsHiddenProvider = Provider<bool>((ref) {
  final s = ref.watch(storedSettingsProvider).value ?? const <String, String>{};
  final on = PrivacyKeys.hideAmounts.decode(s[PrivacyKeys.hideAmounts.name]);
  return on && !ref.watch(amountsRevealedProvider);
});
