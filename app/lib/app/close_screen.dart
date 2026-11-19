import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Closes the screen [context] belongs to and returns to the one underneath.
///
/// Under the app's router the pop goes through go_router, which keeps its own page list in
/// step; popping the Navigator directly can leave the page behind. Plain Navigator screens
/// (tests, previews) fall back to the Navigator.
Future<void> closeScreen(BuildContext context) async {
  final router = GoRouter.maybeOf(context);
  if (router != null) {
    if (router.canPop()) router.pop();
    return;
  }
  await Navigator.of(context).maybePop();
}
