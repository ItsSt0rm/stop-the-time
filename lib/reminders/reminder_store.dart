import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'reminder.dart';

/// Guarda la lista de recordatorios **solo en el teléfono** (es lo único que la app persiste).
abstract class ReminderStore {
  static ReminderStore instance = PrefsReminderStore();

  Future<List<Reminder>> load();
  Future<void> save(List<Reminder> reminders);
}

class PrefsReminderStore implements ReminderStore {
  static const _key = 'reminders.v1';

  final _prefs = SharedPreferencesAsync();

  @override
  Future<List<Reminder>> load() async {
    final raw = await _prefs.getString(_key);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List;
      return [
        for (final item in list)
          Reminder.fromJson((item as Map).cast<String, Object?>()),
      ];
    } on Object {
      // Dato corrupto o de un formato antiguo: mejor empezar vacío que bloquear la app.
      return [];
    }
  }

  @override
  Future<void> save(List<Reminder> reminders) => _prefs.setString(
    _key,
    jsonEncode([for (final r in reminders) r.toJson()]),
  );
}
