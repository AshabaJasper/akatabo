import 'package:akatabo/services/notifications/notifications_service.dart';
import 'package:akatabo/services/notifications/reminder_plan.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the calls the service makes, in order. Only the calls `replaceAll` uses are real.
class _RecordingPlugin implements FlutterLocalNotificationsPlugin {
  _RecordingPlugin(this.pending);

  final List<PendingNotificationRequest> pending;
  final calls = <String>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    Object? onDidReceiveNotificationResponse,
    Object? onDidReceiveBackgroundNotificationResponse,
  }) async => true;

  @override
  Future<List<PendingNotificationRequest>> pendingNotificationRequests() async => pending;

  @override
  Future<NotificationAppLaunchDetails?> getNotificationAppLaunchDetails() async =>
      const NotificationAppLaunchDetails(false);

  @override
  Future<List<ActiveNotification>> getActiveNotifications() async => const [];

  @override
  Future<void> cancel({required int id, String? tag}) async => calls.add('cancel $id');

  @override
  Future<void> show({
    required int id,
    String? title,
    String? body,
    NotificationDetails? notificationDetails,
    String? payload,
  }) async => calls.add('show $id');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'on the first sync, a one-time reminder due minutes ago is shown after the cancels',
    () async {
      // Rent's reminder came five minutes ago. The new plan no longer has it (its time passed),
      // so the sync cancels its id; showing it before that cancel would clear it at once.
      final at = DateTime.now().subtract(const Duration(minutes: 5));
      final plugin = _RecordingPlugin([
        PendingNotificationRequest(
          ReminderIds.regularFirst,
          'Rent is due tomorrow',
          'Usually about UGX 300,000.',
          reminderSignature(
            OnceReminder(id: ReminderIds.regularFirst, title: '', body: '', at: at),
          ),
        ),
      ]);
      await LocalNotificationsService(plugin: plugin).replaceAll(const []);
      expect(plugin.calls, [
        'cancel ${ReminderIds.regularFirst}',
        'show ${ReminderIds.regularFirst}',
      ]);
    },
  );
}
