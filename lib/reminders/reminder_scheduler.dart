import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/services.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../theme.dart';
import 'reminder.dart';

/// Estado de los permisos que necesitan los recordatorios.
typedef ReminderPermissions = ({bool notifications, bool exactAlarms});

/// Programa los recordatorios como notificaciones locales. Interfaz para sustituirla en los tests.
abstract class ReminderScheduler {
  static ReminderScheduler instance = LocalNotificationsScheduler();

  Future<void> init();

  /// Estado actual, sin preguntar nada a la persona.
  Future<ReminderPermissions> permissions();

  /// Pide el permiso de notificaciones (diálogo del sistema en Android 13+).
  Future<bool> requestNotifications();

  /// Abre la pantalla del sistema "Alarmas y recordatorios" para conceder la hora exacta.
  Future<void> requestExactAlarms();

  /// Deja programadas exactamente las ocurrencias de los recordatorios activos.
  Future<void> sync(List<Reminder> reminders);
}

class LocalNotificationsScheduler implements ReminderScheduler {
  static const title = 'Para el tiempo';
  static const body = 'Un momento para parar.';

  /// Canal propio (MainActivity.kt) que devuelve la zona horaria IANA del teléfono.
  static const _timezoneChannel = MethodChannel('para_el_tiempo/timezone');

  final _plugin = FlutterLocalNotificationsPlugin();
  Future<void>? _ready;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<void> init() => _ready ??= _init();

  Future<void> _init() async {
    tz_data.initializeTimeZones();
    try {
      final id = await _timezoneChannel.invokeMethod<String>('localTimezone');
      tz.setLocalLocation(tz.getLocation(id!));
    } catch (e) {
      // Sin zona conocida se usa UTC: las horas se desplazarían, así que lo dejamos registrado.
      debugPrint('ReminderScheduler: zona horaria no disponible ($e)');
    }
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('ic_stat_para'),
      ),
    );
  }

  @override
  Future<ReminderPermissions> permissions() async {
    await init();
    final android = _android;
    return (
      notifications: await android?.areNotificationsEnabled() ?? false,
      exactAlarms: await android?.canScheduleExactNotifications() ?? false,
    );
  }

  @override
  Future<bool> requestNotifications() async {
    await init();
    return await _android?.requestNotificationsPermission() ?? false;
  }

  @override
  Future<void> requestExactAlarms() async {
    await init();
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> sync(List<Reminder> reminders) async {
    await init();
    // Se reprograma todo desde cero: simple, y corrige cambios de zona horaria o de hora del sistema.
    await _plugin.cancelAllPendingNotifications();
    final exact = await _android?.canScheduleExactNotifications() ?? false;
    final now = tz.TZDateTime.now(tz.local);
    for (final reminder in reminders.where((r) => r.enabled)) {
      for (final day in reminder.weekdays) {
        await _plugin.zonedSchedule(
          id: reminder.notificationId(day),
          scheduledDate: nextOccurrence(
            now,
            day,
            reminder.hour,
            reminder.minute,
          ),
          notificationDetails: _details,
          androidScheduleMode: exact
              ? AndroidScheduleMode.exactAllowWhileIdle
              : AndroidScheduleMode.inexactAllowWhileIdle,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          title: title,
          body: body,
        );
      }
    }
  }

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'recordatorios',
      'Recordatorios',
      channelDescription: 'Avisos a las horas que elijas en la app.',
      importance: Importance.high,
      priority: Priority.high,
      icon: 'ic_stat_para',
      color: AppColors.text,
      category: AndroidNotificationCategory.reminder,
    ),
  );
}
