import 'package:akatabo/features/goals/goal_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

// No initializeDateFormatting call here, on purpose: the app does not run it at startup, so
// the goal dates must format without any setup. The widget tests hide this by initialising.
void main() {
  test('goal dates format with no date-locale setup', () {
    expect(dayText(20260301), '1 March 2026');
  });
}
