import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'data/providers.dart';
import 'data/seed/demo_seed.dart';
import 'data/settings/setting_keys.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final container = await createAppContainer();

  // Demo entries only when built with --dart-define=AKATABO_DEMO=true, and only into an
  // empty database. A release build without the flag never reaches this.
  if (const bool.fromEnvironment('AKATABO_DEMO')) {
    final repo = container.read(transactionRepositoryProvider);
    final existing = await repo.watchLatest(1).first;
    await insertDemoData(repo, now: DateTime.now(), isEmpty: existing.isEmpty);
  }

  // The first screen depends on this flag, so it is read directly with no time limit: the
  // settings load above gives up after 3 seconds, and a returning person on a slow phone
  // must not be shown Onboarding again.
  var onboardingDone = false;
  try {
    onboardingDone = await container
        .read(settingsRepositoryProvider)
        .read(SettingKeys.onboardingDone);
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo startup'),
    );
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: AkataboApp(onboardingDone: onboardingDone),
    ),
  );
}
