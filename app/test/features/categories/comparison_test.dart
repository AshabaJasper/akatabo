import 'package:akatabo/features/categories/categories_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('with nothing on the same days before, it says "by this day", not the whole month', () {
    // Seen on the Pixel: October had fees after the 23rd, so "Nothing in October" was false.
    expect(comparison(3900, 0, 'October'), 'Nothing by this day in October to compare with.');
  });

  test('a change reads as up, down or level on the month before', () {
    expect(comparison(110, 100, 'October'), startsWith('Up 10'));
    expect(comparison(90, 100, 'October'), startsWith('Down 10'));
    expect(comparison(100, 100, 'October'), 'Level with October');
  });
}
