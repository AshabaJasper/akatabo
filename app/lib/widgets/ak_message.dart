import 'package:material_ui/material_ui.dart';

/// What a screen says when its data could not be read. Closing and opening the app again
/// reopens the database, which is the one thing the person can do.
const loadFailedText = 'This could not load. Close Akatabo and open it again.';

/// What a screen says when a change could not be saved.
const saveFailedText = 'That could not be saved. Nothing changed. Try again.';

/// Shows [message] at the foot of the screen, replacing any message already there.
void showAkMessage(BuildContext context, String? message) {
  if (message == null || !context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

/// Runs [save]; when it throws, reports the error and tells the person. True when it worked.
Future<bool> saveOrSay(BuildContext context, Future<void> Function() save, {String? failed}) async {
  try {
    await save();
    return true;
  } catch (error, stack) {
    FlutterError.reportError(
      FlutterErrorDetails(exception: error, stack: stack, library: 'akatabo save'),
    );
    if (context.mounted) showAkMessage(context, failed ?? saveFailedText);
    return false;
  }
}
