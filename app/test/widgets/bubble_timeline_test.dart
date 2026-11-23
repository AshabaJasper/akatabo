import 'package:akatabo/widgets/charts/bubble_timeline.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

void main() {
  test('a label that would land on one already written is left out', () {
    final taken = <Rect>[];
    // Two payments a day apart on a narrow phone: their "150k" figures are 10px apart.
    expect(claimSpace(taken, const Rect.fromLTWH(100, 0, 30, 14)), isTrue);
    expect(claimSpace(taken, const Rect.fromLTWH(110, 0, 30, 14)), isFalse);
    expect(taken, hasLength(1), reason: 'the refused label takes no space');
    // Far enough along, the next one is written.
    expect(claimSpace(taken, const Rect.fromLTWH(140, 0, 30, 14)), isTrue);
  });

  test('labels touching within the small gap still count as overlapping', () {
    final taken = <Rect>[const Rect.fromLTWH(0, 0, 40, 14)];
    expect(claimSpace(taken, const Rect.fromLTWH(41, 0, 20, 14)), isFalse);
  });
}
