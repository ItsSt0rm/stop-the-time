import 'package:timezone/timezone.dart' as tz;

/// Un recordatorio tipo alarma: una hora y los días de la semana en que suena.
class Reminder {
  Reminder({
    required this.id,
    required this.hour,
    required this.minute,
    required Set<int> weekdays,
    this.enabled = true,
  }) : weekdays = Set.unmodifiable(weekdays),
       assert(id > 0),
       assert(hour >= 0 && hour < 24),
       assert(minute >= 0 && minute < 60),
       assert(weekdays.isNotEmpty),
       assert(
         weekdays.every((d) => d >= DateTime.monday && d <= DateTime.sunday),
       );

  final int id;
  final int hour;
  final int minute;

  /// Días con la convención de [DateTime]: 1 = lunes … 7 = domingo. Nunca vacío.
  final Set<int> weekdays;
  final bool enabled;

  static const allDays = {1, 2, 3, 4, 5, 6, 7};

  Reminder copyWith({
    int? hour,
    int? minute,
    Set<int>? weekdays,
    bool? enabled,
  }) => Reminder(
    id: id,
    hour: hour ?? this.hour,
    minute: minute ?? this.minute,
    weekdays: weekdays ?? this.weekdays,
    enabled: enabled ?? this.enabled,
  );

  /// Id de la notificación programada para un día concreto (una por día de la semana).
  int notificationId(int weekday) => id * 10 + weekday;

  Map<String, Object> toJson() => {
    'id': id,
    'hour': hour,
    'minute': minute,
    'weekdays': (weekdays.toList()..sort()),
    'enabled': enabled,
  };

  /// Valida rangos explícitamente: los `assert` del constructor no se ejecutan en release, y un dato
  /// fuera de rango haría fallar la programación. Lanza [FormatException] (el almacén la convierte en
  /// una lista vacía).
  static Reminder fromJson(Map<String, Object?> json) {
    final id = json['id']! as int;
    final hour = json['hour']! as int;
    final minute = json['minute']! as int;
    final weekdays = {for (final d in json['weekdays']! as List) d as int};
    if (id <= 0 ||
        hour < 0 ||
        hour > 23 ||
        minute < 0 ||
        minute > 59 ||
        weekdays.isEmpty ||
        weekdays.any((d) => d < DateTime.monday || d > DateTime.sunday)) {
      throw FormatException('Recordatorio fuera de rango: $json');
    }
    return Reminder(
      id: id,
      hour: hour,
      minute: minute,
      weekdays: weekdays,
      enabled: json['enabled']! as bool,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.hour == hour &&
      other.minute == minute &&
      other.enabled == enabled &&
      other.weekdays.length == weekdays.length &&
      other.weekdays.containsAll(weekdays);

  @override
  int get hashCode =>
      Object.hash(id, hour, minute, enabled, Object.hashAllUnordered(weekdays));
}

/// Próximo instante (estrictamente posterior a [now]) que cae en [weekday] a [hour]:[minute] en la
/// zona de [now]. Se construye por fecha de calendario, no sumando 24 h, para respetar cambios de
/// horario.
tz.TZDateTime nextOccurrence(
  tz.TZDateTime now,
  int weekday,
  int hour,
  int minute,
) {
  for (var offset = 0; offset <= 7; offset++) {
    final candidate = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + offset,
      hour,
      minute,
    );
    if (candidate.weekday == weekday && candidate.isAfter(now)) {
      return candidate;
    }
  }
  throw StateError('Sin próxima ocurrencia para el día $weekday');
}
