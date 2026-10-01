import 'package:flutter/material.dart';

import '../reminders/reminder.dart';
import '../reminders/reminder_scheduler.dart';
import '../reminders/reminder_store.dart';
import '../theme.dart';

/// Recordatorios tipo alarma: hora, días de la semana y un interruptor por recordatorio.
class RemindersScreen extends StatefulWidget {
  const RemindersScreen({super.key, this.store, this.scheduler});

  final ReminderStore? store;
  final ReminderScheduler? scheduler;

  static const addButtonKey = Key('add-reminder');

  @override
  State<RemindersScreen> createState() => _RemindersScreenState();
}

/// Iniciales de los días, de lunes (1) a domingo (7).
const weekdayInitials = {
  1: 'L',
  2: 'M',
  3: 'X',
  4: 'J',
  5: 'V',
  6: 'S',
  7: 'D',
};
const _weekdayNames = {
  1: 'lunes',
  2: 'martes',
  3: 'miércoles',
  4: 'jueves',
  5: 'viernes',
  6: 'sábado',
  7: 'domingo',
};

class _RemindersScreenState extends State<RemindersScreen>
    with WidgetsBindingObserver {
  late final ReminderStore _store = widget.store ?? ReminderStore.instance;
  late final ReminderScheduler _scheduler =
      widget.scheduler ?? ReminderScheduler.instance;

  List<Reminder>? _reminders;
  ReminderPermissions? _permissions;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver de Ajustes (permiso de alarmas exactas), refrescar el estado y reprogramar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshPermissions(resync: true);
  }

  Future<void> _load() async {
    final reminders = await _store.load();
    if (!mounted) return;
    setState(() => _reminders = reminders);
    await _refreshPermissions();
  }

  Future<void> _refreshPermissions({bool resync = false}) async {
    final permissions = await _scheduler.permissions();
    if (!mounted) return;
    setState(() => _permissions = permissions);
    // El modo (exacto/inexacto) se decide al programar: si cambió el permiso, reprogramar.
    if (resync && _reminders != null) await _scheduler.sync(_reminders!);
  }

  Future<void> _update(List<Reminder> reminders) async {
    setState(() => _reminders = reminders);
    await _store.save(reminders);
    await _scheduler.sync(reminders);
  }

  /// Selector de hora siempre en 24 h: el locale es lo muestra así, y si el teléfono está en 12 h
  /// el modo de escribir la hora validaría con 12 h (rechaza 13–23 o guarda 7 en vez de 19).
  Future<TimeOfDay?> _pickTime(TimeOfDay initial) => showTimePicker(
    context: context,
    initialTime: initial,
    helpText: 'Hora',
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );

  Future<void> _add() async {
    final time = await _pickTime(TimeOfDay.now());
    if (time == null || !mounted) return;
    // Los permisos se piden al crear el primer recordatorio, cuando su motivo es evidente.
    if (!(_permissions?.notifications ?? false)) {
      await _scheduler.requestNotifications();
    }
    final current = _reminders ?? [];
    final nextId = current.fold(0, (m, r) => r.id > m ? r.id : m) + 1;
    await _update([
      ...current,
      Reminder(
        id: nextId,
        hour: time.hour,
        minute: time.minute,
        weekdays: Reminder.allDays,
      ),
    ]);
    await _refreshPermissions();
  }

  Future<void> _editTime(Reminder reminder) async {
    final time = await _pickTime(
      TimeOfDay(hour: reminder.hour, minute: reminder.minute),
    );
    if (time == null) return;
    _replace(reminder.copyWith(hour: time.hour, minute: time.minute));
  }

  void _toggleDay(Reminder reminder, int day) {
    final days = {...reminder.weekdays};
    if (!days.remove(day)) days.add(day);
    if (days.isEmpty) return; // siempre al menos un día
    _replace(reminder.copyWith(weekdays: days));
  }

  void _replace(Reminder updated) =>
      _update([for (final r in _reminders!) r.id == updated.id ? updated : r]);

  void _delete(Reminder reminder) => _update([
    for (final r in _reminders!)
      if (r.id != reminder.id) r,
  ]);

  @override
  Widget build(BuildContext context) {
    final reminders = _reminders;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        title: const Text(
          'Recordatorios',
          style: TextStyle(fontWeight: FontWeight.w300),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        key: RemindersScreen.addButtonKey,
        tooltip: 'Añadir recordatorio',
        backgroundColor: AppColors.circle,
        foregroundColor: AppColors.text,
        onPressed: _add,
        child: const Icon(Icons.add),
      ),
      body: reminders == null
          ? const SizedBox.shrink()
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                ..._permissionNotices(),
                if (reminders.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Text(
                      'Elige horas para que la app te avise\ncon un momento para parar.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textDim, height: 1.5),
                    ),
                  ),
                for (final r in reminders)
                  _ReminderTile(
                    key: ValueKey(r.id),
                    reminder: r,
                    onTapTime: () => _editTime(r),
                    onToggleDay: (d) => _toggleDay(r, d),
                    onEnabled: (v) => _replace(r.copyWith(enabled: v)),
                    onDelete: () => _delete(r),
                  ),
              ],
            ),
    );
  }

  List<Widget> _permissionNotices() {
    final p = _permissions;
    final hasActive = _reminders?.any((r) => r.enabled) ?? false;
    if (p == null || !hasActive) return const [];
    return [
      if (!p.notifications)
        _Notice(
          text:
              'Las notificaciones están desactivadas para la app: '
              'los recordatorios no se mostrarán.',
          action: 'Permitir',
          onAction: () async {
            await _scheduler.requestNotifications();
            await _refreshPermissions(resync: true);
          },
        ),
      if (p.notifications && !p.exactAlarms)
        _Notice(
          text:
              'Sin el permiso de alarmas exactas, Android puede retrasar '
              'los avisos unos minutos.',
          action: 'Conceder',
          onAction: _scheduler.requestExactAlarms,
        ),
    ];
  }
}

class _Notice extends StatelessWidget {
  const _Notice({
    required this.text,
    required this.action,
    required this.onAction,
  });

  final String text;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.circleEdge),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textDim, height: 1.4),
            ),
          ),
          TextButton(onPressed: onAction, child: Text(action)),
        ],
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  const _ReminderTile({
    super.key,
    required this.reminder,
    required this.onTapTime,
    required this.onToggleDay,
    required this.onEnabled,
    required this.onDelete,
  });

  final Reminder reminder;
  final VoidCallback onTapTime;
  final ValueChanged<int> onToggleDay;
  final ValueChanged<bool> onEnabled;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final r = reminder;
    final time = TimeOfDay(hour: r.hour, minute: r.minute).format(context);
    final dim = r.enabled ? AppColors.text : AppColors.textDim;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 12),
      decoration: BoxDecoration(
        color: AppColors.circle.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onTapTime,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Text(
                      time,
                      semanticsLabel: 'Recordatorio a las $time. Cambiar hora',
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w200,
                        color: dim,
                      ),
                    ),
                  ),
                ),
              ),
              Switch(value: r.enabled, onChanged: onEnabled),
              IconButton(
                tooltip: 'Eliminar recordatorio',
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.textDim,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 6,
            children: [
              for (final entry in weekdayInitials.entries)
                _DayChip(
                  label: entry.value,
                  semantics: _weekdayNames[entry.key]!,
                  selected: r.weekdays.contains(entry.key),
                  onTap: () => onToggleDay(entry.key),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.semantics,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String semantics;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      selected: selected,
      button: true,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? AppColors.text : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.text : AppColors.circleEdge,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: selected ? AppColors.background : AppColors.textDim,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
