import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/notifications/reminder_plan.dart';

/// Records what the app asks of the notifications, and answers the permission request.
class FakeNotifications implements NotificationsService {
  FakeNotifications({this.allow = true, this.allowedNow = true});
  bool allow;
  bool allowedNow;

  int asks = 0;
  List<PlannedReminder>? scheduled;
  int replaces = 0;

  /// Every notification shown now, oldest first.
  final shown = <({int id, String title, String body})>[];

  @override
  Future<bool> areAllowed() async => allowedNow;

  @override
  Future<bool> requestPermission() async {
    asks++;
    return allow;
  }

  @override
  Future<void> replaceAll(List<PlannedReminder> reminders) async {
    replaces++;
    scheduled = reminders;
  }

  @override
  Future<void> showNow(int id, String title, String body) async {
    shown.add((id: id, title: title, body: body));
  }
}
