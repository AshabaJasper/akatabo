import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import 'app/app.dart';
import 'app/bootstrap.dart';
import 'data/providers.dart';
import 'data/seed/demo_seed.dart';

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

  runApp(UncontrolledProviderScope(container: container, child: const AkataboApp()));
}
