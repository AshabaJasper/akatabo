import 'package:material_ui/material_ui.dart' show Color;

import 'tokens.g.dart';

/// The colour for a token name stored on a category or account, such as `cat-green`.
///
/// Screens never type a colour: they ask for the token by the name stored in the database.
/// An unknown name falls back to the neutral slate, so a bad value shows a colour instead of
/// breaking the list.
Color colourForToken(AkColorTokens c, String token) => switch (token) {
  'cat-green' => c.catGreen,
  'cat-blue' => c.catBlue,
  'cat-amber' => c.catAmber,
  'cat-purple' => c.catPurple,
  'cat-pink' => c.catPink,
  'cat-slate' => c.catSlate,
  'cat-orange' => c.catOrange,
  'cat-teal' => c.catTeal,
  'cat-indigo' => c.catIndigo,
  'cat-brown' => c.catBrown,
  'cat-olive' => c.catOlive,
  'cat-red' => c.catRed,
  'acct-mtn' => c.acctMtn,
  'acct-airtel' => c.acctAirtel,
  'acct-cash' => c.acctCash,
  'acct-bank' => c.acctBank,
  _ => c.catSlate,
};
