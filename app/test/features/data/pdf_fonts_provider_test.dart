import 'package:akatabo/features/data/export_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The PDF report's fonts and logo come from the app's asset bundle, as in the app, so a
/// file missing from `pubspec.yaml` fails here rather than on the phone.
void main() {
  testWidgets('the PDF fonts carry the logo from the asset bundle', (tester) async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final fonts = await tester.runAsync(() => container.read(pdfFontsProvider.future));
    final logo = fonts!.logo;
    expect(logo, isNotNull);
    // A PNG starts with 0x89 then "PNG".
    expect(logo!.sublist(0, 4), [0x89, 0x50, 0x4E, 0x47]);
  });
}
