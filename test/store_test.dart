import 'package:flutter_test/flutter_test.dart';
import 'package:para_el_tiempo/reminders/reminder.dart';
import 'package:para_el_tiempo/reminders/reminder_store.dart';
// Implementación en memoria de shared_preferences (dev_dependency) para no tocar el almacén real.
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';
import 'package:shared_preferences_platform_interface/types.dart';

void main() {
  late InMemorySharedPreferencesAsync platform;

  void useData(Map<String, Object> data) {
    platform = InMemorySharedPreferencesAsync.withData(data);
    SharedPreferencesAsyncPlatform.instance = platform;
  }

  setUp(() => useData({}));

  test('sin datos guardados → lista vacía', () async {
    expect(await PrefsReminderStore().load(), isEmpty);
  });

  test('ida y vuelta (con una instancia nueva del almacén)', () async {
    final reminders = [
      Reminder(id: 1, hour: 7, minute: 30, weekdays: {1, 2, 3, 4, 5}),
      Reminder(id: 2, hour: 22, minute: 0, weekdays: {6, 7}, enabled: false),
    ];
    await PrefsReminderStore().save(reminders);
    expect(await PrefsReminderStore().load(), reminders);

    await PrefsReminderStore().save([]);
    expect(await PrefsReminderStore().load(), isEmpty);
  });

  test("usa la clave 'reminders.v1' con JSON", () async {
    await PrefsReminderStore().save([
      Reminder(id: 1, hour: 7, minute: 0, weekdays: {3, 1}),
    ]);
    final prefs = await platform.getPreferences(
      const GetPreferencesParameters(filter: PreferencesFilters()),
      const SharedPreferencesOptions(),
    );
    expect(prefs.keys, ['reminders.v1']);
    expect(
      prefs['reminders.v1'],
      '[{"id":1,"hour":7,"minute":0,"weekdays":[1,3],"enabled":true}]',
    );
  });

  for (final (name, raw) in [
    ('texto no JSON', 'esto no es json'),
    ('JSON que no es lista', '{"id":1}'),
    ('elemento sin campos', '[{"id":1}]'),
    (
      'tipos incorrectos',
      '[{"id":"1","hour":7,"minute":0,"weekdays":[1],"enabled":true}]',
    ),
    (
      'días vacíos',
      '[{"id":1,"hour":7,"minute":0,"weekdays":[],"enabled":true}]',
    ),
    (
      'hora fuera de rango',
      '[{"id":1,"hour":25,"minute":0,"weekdays":[1],"enabled":true}]',
    ),
    ('elemento null', '[null]'),
  ]) {
    test('JSON corrupto ($name) → lista vacía', () async {
      useData({'reminders.v1': raw});
      expect(await PrefsReminderStore().load(), isEmpty);
    });
  }
}
