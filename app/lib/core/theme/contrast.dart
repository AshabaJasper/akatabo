import 'package:material_ui/material_ui.dart' show Color;

/// The WCAG 2.2 contrast ratio between two opaque colours, from 1 to 21.
///
/// Text needs at least 4.5 (AA for body text); controls and chart marks need at least 3.
double contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}
