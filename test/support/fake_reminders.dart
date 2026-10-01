import 'package:para_el_tiempo/reminders/reminder.dart';
import 'package:para_el_tiempo/reminders/reminder_scheduler.dart';
import 'package:para_el_tiempo/reminders/reminder_store.dart';

/// Almacén en memoria.
class MemoryReminderStore implements ReminderStore {
  List<Reminder> saved = [];

  @override
  Future<List<Reminder>> load() async => [...saved];

  @override
  Future<void> save(List<Reminder> reminders) async => saved = [...reminders];
}

/// Programador falso: registra llamadas y permite fijar el estado de los permisos.
class FakeReminderScheduler implements ReminderScheduler {
  bool notificationsGranted = true;
  bool exactGranted = true;

  /// Qué devolverá el diálogo de notificaciones si se pide.
  bool grantOnRequest = true;

  final List<String> calls = [];
  List<Reminder> lastSynced = [];

  @override
  Future<void> init() async => calls.add('init');

  @override
  Future<ReminderPermissions> permissions() async =>
      (notifications: notificationsGranted, exactAlarms: exactGranted);

  @override
  Future<bool> requestNotifications() async {
    calls.add('requestNotifications');
    notificationsGranted = grantOnRequest;
    return grantOnRequest;
  }

  @override
  Future<void> requestExactAlarms() async => calls.add('requestExactAlarms');

  @override
  Future<void> sync(List<Reminder> reminders) async {
    calls.add('sync');
    lastSynced = [...reminders];
  }
}
