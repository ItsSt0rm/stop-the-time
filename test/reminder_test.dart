import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/reminders/reminder.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

void main() {
  group('Reminder (modelo)', () {
    Reminder base() =>
        Reminder(id: 3, hour: 7, minute: 30, weekdays: {1, 3, 5});

    test('valores por defecto: activo', () {
      expect(base().enabled, isTrue);
    });

    test('asserts: id, hora, minuto y días válidos', () {
      Matcher fails = throwsA(isA<AssertionError>());
      expect(() => Reminder(id: 0, hour: 7, minute: 0, weekdays: {1}), fails);
      expect(() => Reminder(id: 1, hour: 24, minute: 0, weekdays: {1}), fails);
      expect(() => Reminder(id: 1, hour: -1, minute: 0, weekdays: {1}), fails);
      expect(() => Reminder(id: 1, hour: 7, minute: 60, weekdays: {1}), fails);
      expect(() => Reminder(id: 1, hour: 7, minute: 0, weekdays: {}), fails);
      expect(() => Reminder(id: 1, hour: 7, minute: 0, weekdays: {0}), fails);
      expect(() => Reminder(id: 1, hour: 7, minute: 0, weekdays: {8}), fails);
      // Límites válidos.
      Reminder(id: 1, hour: 0, minute: 0, weekdays: {1});
      Reminder(id: 1, hour: 23, minute: 59, weekdays: Reminder.allDays);
    });

    test('los días no se pueden modificar desde fuera', () {
      final days = {1, 2};
      final r = Reminder(id: 1, hour: 7, minute: 0, weekdays: days);
      days.add(3);
      expect(r.weekdays, {1, 2});
      expect(() => r.weekdays.add(4), throwsUnsupportedError);
    });

    test('copyWith conserva el id y cambia solo lo pedido', () {
      final r = base();
      expect(r.copyWith(), r);
      final c = r.copyWith(hour: 22, enabled: false);
      expect(c.id, 3);
      expect(c.hour, 22);
      expect(c.minute, 30);
      expect(c.weekdays, {1, 3, 5});
      expect(c.enabled, isFalse);
      expect(r.copyWith(minute: 5).minute, 5);
      expect(r.copyWith(weekdays: {7}).weekdays, {7});
    });

    test('igualdad y hashCode no dependen del orden de los días', () {
      final a = Reminder(id: 1, hour: 7, minute: 0, weekdays: {1, 2, 3});
      final b = Reminder(id: 1, hour: 7, minute: 0, weekdays: {3, 2, 1});
      expect(a, b);
      expect(a.hashCode, b.hashCode);
      expect(a == a.copyWith(weekdays: {1, 2}), isFalse);
      expect(a == a.copyWith(weekdays: {1, 2, 4}), isFalse);
      expect(a == a.copyWith(enabled: false), isFalse);
    });

    test('JSON ida y vuelta (también a través de texto)', () {
      for (final r in [
        base(),
        base().copyWith(enabled: false),
        Reminder(id: 99, hour: 0, minute: 0, weekdays: Reminder.allDays),
      ]) {
        expect(Reminder.fromJson(r.toJson()), r);
        final decoded = (jsonDecode(jsonEncode(r.toJson())) as Map)
            .cast<String, Object?>();
        expect(Reminder.fromJson(decoded), r);
      }
      expect(base().toJson()['weekdays'], [1, 3, 5]);
    });

    test('fromJson rechaza valores fuera de rango con FormatException', () {
      final ok = base().toJson();
      for (final bad in <Map<String, Object>>[
        {...ok, 'id': 0},
        {...ok, 'hour': 24},
        {...ok, 'hour': -1},
        {...ok, 'minute': 60},
        {...ok, 'weekdays': <int>[]},
        {
          ...ok,
          'weekdays': [0],
        },
        {
          ...ok,
          'weekdays': [8],
        },
      ]) {
        expect(
          () => Reminder.fromJson(bad),
          throwsFormatException,
          reason: '$bad',
        );
      }
    });

    test('notificationId es único por recordatorio y día', () {
      final ids = <int>{};
      for (var id = 1; id <= 200; id++) {
        final r = Reminder(
          id: id,
          hour: 7,
          minute: 0,
          weekdays: Reminder.allDays,
        );
        for (final d in r.weekdays) {
          expect(ids.add(r.notificationId(d)), isTrue, reason: '$id/$d');
        }
      }
      expect(base().notificationId(5), 35);
    });
  });

  group('nextOccurrence', () {
    late tz.Location madrid;
    late tz.Location bogota;

    setUpAll(() {
      tz_data.initializeTimeZones();
      madrid = tz.getLocation('Europe/Madrid');
      bogota = tz.getLocation('America/Bogota');
    });

    tz.TZDateTime at(
      tz.Location l,
      int y,
      int mo,
      int d, [
      int h = 0,
      int mi = 0,
      int s = 0,
      int ms = 0,
    ]) => tz.TZDateTime(l, y, mo, d, h, mi, s, ms);

    void expectLocal(
      tz.TZDateTime r,
      tz.Location l,
      int y,
      int mo,
      int d,
      int h,
      int mi,
    ) {
      expect(r.location, l);
      expect(
        [r.year, r.month, r.day, r.hour, r.minute, r.second, r.millisecond],
        [y, mo, d, h, mi, 0, 0],
        reason: '$r',
      );
    }

    test('fechas de referencia (día de la semana)', () {
      expect(at(madrid, 2026, 9, 30).weekday, DateTime.wednesday);
      expect(at(madrid, 2026, 12, 31).weekday, DateTime.thursday);
      expect(at(madrid, 2026, 3, 29).weekday, DateTime.sunday);
      expect(at(madrid, 2026, 10, 25).weekday, DateTime.sunday);
    });

    test('mismo día, antes de la hora → hoy', () {
      final now = at(madrid, 2026, 9, 30, 8);
      expectLocal(nextOccurrence(now, 3, 9, 0), madrid, 2026, 9, 30, 9, 0);
      final justBefore = at(madrid, 2026, 9, 30, 8, 59, 59, 999);
      expectLocal(
        nextOccurrence(justBefore, 3, 9, 0),
        madrid,
        2026,
        9,
        30,
        9,
        0,
      );
    });

    test('mismo día, después de la hora → semana siguiente', () {
      final now = at(madrid, 2026, 9, 30, 10);
      expectLocal(nextOccurrence(now, 3, 9, 0), madrid, 2026, 10, 7, 9, 0);
    });

    test(
      'exactamente a la hora → semana siguiente (estrictamente posterior)',
      () {
        final now = at(madrid, 2026, 9, 30, 9);
        expectLocal(nextOccurrence(now, 3, 9, 0), madrid, 2026, 10, 7, 9, 0);
        final plusMs = at(madrid, 2026, 9, 30, 9, 0, 0, 1);
        expectLocal(nextOccurrence(plusMs, 3, 9, 0), madrid, 2026, 10, 7, 9, 0);
      },
    );

    test('cruce de fin de mes', () {
      final now = at(madrid, 2026, 9, 30, 10);
      expectLocal(nextOccurrence(now, 4, 9, 0), madrid, 2026, 10, 1, 9, 0);
      expectLocal(nextOccurrence(now, 2, 9, 0), madrid, 2026, 10, 6, 9, 0);
    });

    test('cruce de fin de año', () {
      final now = at(madrid, 2026, 12, 31, 20);
      expectLocal(nextOccurrence(now, 5, 7, 30), madrid, 2027, 1, 1, 7, 30);
      expectLocal(nextOccurrence(now, 4, 20, 0), madrid, 2027, 1, 7, 20, 0);
      expectLocal(nextOccurrence(now, 4, 21, 0), madrid, 2026, 12, 31, 21, 0);
    });

    test(
      'Madrid, cambio a horario de verano (29-03-2026): misma hora local',
      () {
        final now = at(madrid, 2026, 3, 28, 10); // sábado, CET (+1)
        expect(now.timeZoneOffset, const Duration(hours: 1));
        final r = nextOccurrence(now, 7, 9, 0);
        expectLocal(r, madrid, 2026, 3, 29, 9, 0);
        expect(r.timeZoneOffset, const Duration(hours: 2));
        // La noche tiene una hora menos: 22 h reales, no 23.
        expect(r.difference(now), const Duration(hours: 22));

        expectLocal(nextOccurrence(now, 1, 9, 0), madrid, 2026, 3, 30, 9, 0);
        // Una semana completa que contiene el cambio.
        final monday = at(madrid, 2026, 3, 23, 9);
        final w = nextOccurrence(monday, 1, 9, 0);
        expectLocal(w, madrid, 2026, 3, 30, 9, 0);
        expect(
          w.difference(monday),
          const Duration(days: 7) - const Duration(hours: 1),
        );
      },
    );

    test(
      'Madrid, vuelta al horario de invierno (25-10-2026): misma hora local',
      () {
        final now = at(madrid, 2026, 10, 24, 10); // sábado, CEST (+2)
        expect(now.timeZoneOffset, const Duration(hours: 2));
        final r = nextOccurrence(now, 7, 9, 0);
        expectLocal(r, madrid, 2026, 10, 25, 9, 0);
        expect(r.timeZoneOffset, const Duration(hours: 1));
        expect(r.difference(now), const Duration(hours: 24));

        final monday = at(madrid, 2026, 10, 19, 9);
        final w = nextOccurrence(monday, 1, 9, 0);
        expectLocal(w, madrid, 2026, 10, 26, 9, 0);
        expect(w.difference(monday), const Duration(days: 7, hours: 1));
      },
    );

    test('Madrid, horas que no existen o se repiten el día del cambio', () {
      // 29-03: de 2:00 se salta a 3:00. Las 2:30 pedidas caen a las 3:30 del mismo domingo.
      final spring = nextOccurrence(at(madrid, 2026, 3, 28, 10), 7, 2, 30);
      expectLocal(spring, madrid, 2026, 3, 29, 3, 30);
      // 25-10: las 2:30 ocurren dos veces; se elige la segunda (ya en horario de invierno).
      final autumn = nextOccurrence(at(madrid, 2026, 10, 24, 10), 7, 2, 30);
      expectLocal(autumn, madrid, 2026, 10, 25, 2, 30);
      expect(autumn.timeZoneOffset, const Duration(hours: 1));
    });

    test('Bogotá (sin horario de verano), cruce de medianoche', () {
      final now = at(bogota, 2026, 9, 30, 23, 30);
      final r = nextOccurrence(now, 4, 0, 15);
      expectLocal(r, bogota, 2026, 10, 1, 0, 15);
      expect(r.timeZoneOffset, const Duration(hours: -5));
      expect(r.difference(now), const Duration(minutes: 45));
    });

    test('barrido de 2026: día, hora local, posterior y a menos de 7 días', () {
      for (final loc in [madrid, bogota]) {
        var day = at(loc, 2026, 1, 1, 12);
        while (day.year == 2026) {
          for (final nowHour in [0, 8, 12, 23]) {
            final now = at(loc, day.year, day.month, day.day, nowHour, 15);
            for (var weekday = 1; weekday <= 7; weekday++) {
              // 2:xx no existe el día del cambio de marzo en Madrid; se evita aquí.
              for (final (h, m) in [(0, 0), (6, 45), (12, 15), (23, 59)]) {
                final r = nextOccurrence(now, weekday, h, m);
                final why = '${loc.name} $now → $weekday $h:$m = $r';
                expect(r.weekday, weekday, reason: why);
                expect(r.hour, h, reason: why);
                expect(r.minute, m, reason: why);
                expect(r.isAfter(now), isTrue, reason: why);
                expect(
                  r.difference(now),
                  lessThanOrEqualTo(const Duration(days: 7, hours: 1)),
                  reason: why,
                );
              }
            }
          }
          day = at(loc, day.year, day.month, day.day + 1, 12);
        }
      }
    });
  });
}
